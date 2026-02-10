#!/bin/sh

cd "$(dirname "$0")/.." || exit 1

# Load .env if present (ROUTER_HOST, ROUTER_USER, ROUTER_PASSWORD)
# shellcheck disable=SC1091
[ -f .env ] && . ./.env

ROUTER_HOST="${ROUTER_HOST:-192.168.8.1}"
ROUTER_USER="${ROUTER_USER:-root}"
TARGET="${ROUTER_USER}@${ROUTER_HOST}"
CLEAN=0
PKG=0

for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=1 ;;
        --pkg)   PKG=1 ;;
    esac
done

echo "Deploying to $TARGET..."

if [ "$PKG" -eq 1 ]; then
    # --- Package mode: build .ipk and install via opkg ---
    echo "Building IPK packages..."
    scripts/build-ipk.sh

    echo "Copying packages to router..."
    scp -O build/*.ipk "$TARGET:/tmp/"

    # shellcheck disable=SC2029
    ssh "$TARGET" "
        # Remove existing packages if installed
        opkg status geolocate 2>/dev/null | grep -q 'Status:.*installed' && \
            opkg remove luci-app-geolocate geolocate 2>&1

        opkg install /tmp/geolocate_*_all.ipk 2>&1
        opkg install /tmp/luci-app-geolocate_*_all.ipk 2>&1

        # Run uci-defaults if config doesn't exist yet
        [ ! -f /etc/config/geolocate ] && /etc/uci-defaults/99-geolocate

        /etc/init.d/geolocate enable
        /etc/init.d/geolocate restart
        /etc/init.d/rpcd reload

        rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
        rm -f /tmp/geolocate_*_all.ipk /tmp/luci-app-geolocate_*_all.ipk

        echo 'Package deployment complete!'
    "
else
    # --- File mode: direct copy (default, for fast iteration) ---

    # Deploy geolocate daemon (skip config unless --clean)
    echo "Copying daemon files..."
    scp -O -r geolocate/files/usr "$TARGET:/"
    scp -O -r geolocate/files/etc/init.d "$TARGET:/etc/"
    scp -O -r geolocate/files/etc/uci-defaults "$TARGET:/etc/"

    if [ "$CLEAN" -eq 1 ]; then
        echo "Copying default config (--clean)..."
        scp -O -r geolocate/files/etc/config "$TARGET:/etc/"
    fi

    # Deploy luci-app-geolocate (UI)
    echo "Copying UI files..."
    scp -O -r luci-app-geolocate/root/* "$TARGET:/"
    scp -O -r luci-app-geolocate/htdocs/* "$TARGET:/www/"

    # Fix permissions and enable
    echo "Setting permissions and restarting..."
    # shellcheck disable=SC2029
    ssh "$TARGET" "
        chmod +x /usr/bin/geolocate-daemon
        chmod +x /usr/lib/geolocate/outputs.sh
        chmod +x /usr/lib/geolocate/output/*.sh
        chmod +x /usr/libexec/rpcd/geolocate
        chmod +x /etc/init.d/geolocate
        chmod +x /etc/uci-defaults/99-geolocate

        # Only run uci-defaults on clean install (config doesn't exist yet)
        [ $CLEAN -eq 1 ] && /etc/uci-defaults/99-geolocate

        /etc/init.d/geolocate enable
        /etc/init.d/geolocate restart

        # Reload RPCD for ubus and ACLs
        /etc/init.d/rpcd reload

        # Clear LuCI caches
        rm -rf /tmp/luci-indexcache
        rm -rf /tmp/luci-modulecache/

        echo 'Deployment complete!'
    "
fi
