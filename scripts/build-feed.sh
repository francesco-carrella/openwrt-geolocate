#!/bin/sh
# Build an opkg feed from .ipk packages
#
# Input:  .ipk files in build/ (produced by build-ipk.sh)
# Output: build/feed/ containing Packages, Packages.gz, and copies of the .ipk files

set -e

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/build"
FEED_DIR="$BUILD_DIR/feed"

info() { printf '=> %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- Validate inputs ---

ipk_count=0
for f in "$BUILD_DIR"/*.ipk; do
    [ -f "$f" ] || continue
    ipk_count=$((ipk_count + 1))
done
[ "$ipk_count" -gt 0 ] || die "No .ipk files found in build/"

# --- Prepare feed directory ---

rm -rf "$FEED_DIR"
mkdir -p "$FEED_DIR"

# Copy .ipk files into feed
cp "$BUILD_DIR"/*.ipk "$FEED_DIR/"

# --- Generate Packages index ---

info "Generating Packages index"

PACKAGES="$FEED_DIR/Packages"
: > "$PACKAGES"

first=1
for ipk in "$FEED_DIR"/*.ipk; do
    [ -f "$ipk" ] || continue

    # Separator between entries
    if [ "$first" -eq 1 ]; then
        first=0
    else
        echo "" >> "$PACKAGES"
    fi

    tmp=$(mktemp -d)

    # Extract control metadata from ipk
    tar xzf "$ipk" -C "$tmp" ./control.tar.gz
    tar xzf "$tmp/control.tar.gz" -C "$tmp" ./control

    # Append control file contents
    cat "$tmp/control" >> "$PACKAGES"

    # Append feed-specific fields
    basename=$(basename "$ipk")
    size=$(wc -c < "$ipk" | tr -d ' ')
    sha256=$(sha256sum "$ipk" | cut -d' ' -f1)

    {
        echo "Filename: $basename"
        echo "Size: $size"
        echo "SHA256sum: $sha256"
    } >> "$PACKAGES"

    rm -rf "$tmp"

    info "  indexed $basename"
done

# --- Compress index ---

gzip -k "$PACKAGES"
info "Created Packages.gz"

# --- Summary ---

info "Done — feed ready in build/feed/"
ls -lh "$FEED_DIR/"
