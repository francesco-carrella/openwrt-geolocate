#!/bin/sh
# Build .ipk packages without the OpenWrt SDK
#
# An .ipk is an ar archive containing:
#   debian-binary  - version string "2.0"
#   control.tar.gz - package metadata (control, conffiles)
#   data.tar.gz    - files to install on the device

set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/build"
WORK_DIR="$BUILD_DIR/.work"

info() { printf '=> %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Detect tar capabilities — ustar format required (busybox tar can't handle pax extensions)
TAR_EXTRA=""
if tar --version 2>&1 | grep -q 'GNU tar'; then
    TAR_EXTRA="--owner=0 --group=0 --numeric-owner"
fi

# --- Makefile parsing helpers ---

# Extract a top-level Makefile variable (e.g. PKG_NAME:=value)
parse_var() {
    grep "^${2}:=" "$1" 2>/dev/null | head -1 | sed "s/^${2}:=//" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Extract a field from inside a "define Package/NAME" block
parse_pkg_field() {
    awk -v pkg="$2" -v field="$3" '
        $0 ~ "^define Package/" pkg "$" { inside=1; next }
        inside && /^endef/ { exit }
        inside {
            regex = "^[[:space:]]*" field ":="
            if ($0 ~ regex) { sub(regex, ""); print }
        }
    ' "$1"
}

# Extract the "define Package/NAME/description" block
parse_description() {
    awk -v pkg="$2" '
        $0 ~ "^define Package/" pkg "/description$" { inside=1; next }
        inside && /^endef/ { exit }
        inside { sub(/^  /, " "); print }
    ' "$1"
}

# Extract the "define Package/NAME/conffiles" block
parse_conffiles() {
    awk -v pkg="$2" '
        $0 ~ "^define Package/" pkg "/conffiles$" { inside=1; next }
        inside && /^endef/ { exit }
        inside && /[^ ]/ { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }
    ' "$1"
}

# Convert OpenWrt DEPENDS "+dep1 +dep2" to opkg format "dep1, dep2"
format_depends() {
    printf '%s' "$1" | sed 's/+//g' | tr -s ' ' | sed 's/^ //; s/ $//; s/ /, /g'
}

# Calculate total installed file size in bytes (portable across macOS/Linux)
calc_installed_size() {
    if stat -f%z /dev/null >/dev/null 2>&1; then
        find "$1" -type f -exec stat -f%z {} + 2>/dev/null | awk '{s+=$1}END{print s+0}'
    else
        find "$1" -type f -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1}END{print s+0}'
    fi
}

# Create tar.gz in ustar format (compatible with busybox tar on OpenWrt)
make_tar() {
    # COPYFILE_DISABLE prevents macOS from including ._* resource fork files
    # shellcheck disable=SC2086
    COPYFILE_DISABLE=1 tar czf "$1" --format ustar $TAR_EXTRA -C "$2" .
}


# --- File staging ---

stage_files() {
    local pkg_dir="$1" data_dir="$2"

    # Stage from files/ directory (geolocate pattern)
    if [ -d "$pkg_dir/files" ]; then
        cp -R "$pkg_dir/files/"* "$data_dir/"

        # Executables: 755
        find "$data_dir/usr/bin" -type f -exec chmod 755 {} + 2>/dev/null || true
        find "$data_dir/usr/lib" -type f -name "*.sh" -exec chmod 755 {} + 2>/dev/null || true
        find "$data_dir/usr/libexec" -type f -exec chmod 755 {} + 2>/dev/null || true
        find "$data_dir/etc/init.d" -type f -exec chmod 755 {} + 2>/dev/null || true
        find "$data_dir/etc/uci-defaults" -type f -exec chmod 755 {} + 2>/dev/null || true

        # Config files: 644
        find "$data_dir/etc/config" -type f -exec chmod 644 {} + 2>/dev/null || true
    fi

    # Stage from root/ directory (luci pattern)
    if [ -d "$pkg_dir/root" ]; then
        cp -R "$pkg_dir/root/"* "$data_dir/"
    fi

    # Stage from htdocs/ → www/ (luci pattern)
    if [ -d "$pkg_dir/htdocs" ]; then
        mkdir -p "$data_dir/www"
        cp -R "$pkg_dir/htdocs/"* "$data_dir/www/"
    fi

    # Ensure all directories are 755
    find "$data_dir" -type d -exec chmod 755 {} +
}

# --- Package builder ---

build_package() {
    local pkg_dir="$1"
    local makefile="$pkg_dir/Makefile"

    [ -f "$makefile" ] || die "No Makefile in $pkg_dir"

    # Parse metadata from Makefile
    local pkg_name pkg_version pkg_release
    pkg_name=$(parse_var "$makefile" "PKG_NAME")
    pkg_version=$(parse_var "$makefile" "PKG_VERSION")
    pkg_release=$(parse_var "$makefile" "PKG_RELEASE")

    [ -n "$pkg_name" ]    || die "PKG_NAME not found in $makefile"
    [ -n "$pkg_version" ] || die "PKG_VERSION not found in $makefile"

    local section depends title arch maintainer license description conffiles
    section=$(parse_pkg_field "$makefile" "$pkg_name" "SECTION")
    depends=$(parse_pkg_field "$makefile" "$pkg_name" "DEPENDS")
    title=$(parse_pkg_field "$makefile" "$pkg_name" "TITLE")
    arch=$(parse_pkg_field "$makefile" "$pkg_name" "PKGARCH")
    maintainer=$(parse_var "$makefile" "PKG_MAINTAINER")
    license=$(parse_var "$makefile" "PKG_LICENSE")
    description=$(parse_description "$makefile" "$pkg_name")
    conffiles=$(parse_conffiles "$makefile" "$pkg_name")

    arch="${arch:-all}"
    local full_version="${pkg_version}${pkg_release:+-$pkg_release}"
    local ipk_name="${pkg_name}_${full_version}_${arch}.ipk"

    info "Building $ipk_name"

    # Prepare working directories
    local work="$WORK_DIR/$pkg_name"
    rm -rf "$work"
    mkdir -p "$work/control" "$work/data"

    # Stage data files
    stage_files "$pkg_dir" "$work/data"

    # Calculate installed size
    local installed_size
    installed_size=$(calc_installed_size "$work/data")

    # Generate control file
    {
        echo "Package: $pkg_name"
        echo "Version: $full_version"
        [ -n "$depends" ] && echo "Depends: $(format_depends "$depends")"
        [ -n "$section" ] && echo "Section: $section"
        echo "Architecture: $arch"
        [ -n "$maintainer" ] && echo "Maintainer: $maintainer"
        [ -n "$license" ] && echo "License: $license"
        echo "Installed-Size: $installed_size"
        echo "Description: $title"
        [ -n "$description" ] && printf '%s\n' "$description"
    } > "$work/control/control"

    # Generate conffiles if present
    if [ -n "$conffiles" ]; then
        printf '%s\n' "$conffiles" > "$work/control/conffiles"
    fi

    # Create debian-binary
    echo "2.0" > "$work/debian-binary"

    # Create tar archives
    make_tar "$work/control.tar.gz" "$work/control"
    make_tar "$work/data.tar.gz" "$work/data"

    # Assemble IPK — gzipped ustar containing ./debian-binary, ./control.tar.gz, ./data.tar.gz
    # shellcheck disable=SC2086
    (cd "$work" && COPYFILE_DISABLE=1 tar czf "$BUILD_DIR/$ipk_name" --format ustar $TAR_EXTRA ./debian-binary ./control.tar.gz ./data.tar.gz)

    info "Created $ipk_name ($(du -h "$BUILD_DIR/$ipk_name" | cut -f1))"
}

# --- Main ---

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

built=0
for pkg_dir in "$ROOT_DIR"/*/; do
    [ -f "$pkg_dir/Makefile" ] || continue
    grep -q "BuildPackage" "$pkg_dir/Makefile" || continue
    build_package "${pkg_dir%/}"
    built=$((built + 1))
done

rm -rf "$WORK_DIR"

[ "$built" -gt 0 ] || die "No packages found to build"

info "Done — built $built package(s) in build/"
ls -lh "$BUILD_DIR/"*.ipk
