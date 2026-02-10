#!/bin/sh

# shellcheck source=/dev/null
. /lib/functions.sh

OUTPUT_DIR="/usr/lib/geolocate/output"

# Dispatcher function called by daemon
forward_outputs() {
    local pos_file="$1"

    if [ ! -f "$pos_file" ]; then
        return 1
    fi

    # Read position data once
    local json
    json=$(cat "$pos_file")

    # Extract values safely — no eval
    local lat lon acc ts src
    lat=$(echo "$json" | jsonfilter -e '@.latitude' 2>/dev/null)
    lon=$(echo "$json" | jsonfilter -e '@.longitude' 2>/dev/null)
    acc=$(echo "$json" | jsonfilter -e '@.accuracy' 2>/dev/null)
    ts=$(echo "$json" | jsonfilter -e '@.timestamp' 2>/dev/null)
    src=$(echo "$json" | jsonfilter -e '@.source' 2>/dev/null)

    if [ -z "$lat" ] || [ -z "$lon" ]; then
        logger -t geolocate "outputs: no position data to forward"
        return 1
    fi

    # Iterate over all sections of type 'output'
    config_load geolocate
    config_foreach _handle_output output "$lat" "$lon" "$acc" "$ts" "$src"
}

_handle_output() {
    local section="$1"
    local lat="$2"
    local lon="$3"
    local acc="$4"
    local ts="$5"
    local src="$6"

    local enabled type
    local status_dir="/tmp/geolocate/output_status"
    config_get_bool enabled "$section" enabled 0
    [ "$enabled" -eq 1 ] || return 0

    config_get type "$section" type
    [ -n "$type" ] || return 0

    # Validate type: alphanumeric and underscore only (no path traversal)
    case "$type" in *[!a-z0-9_]*) logger -t geolocate "output: invalid type '$type'"; return 0 ;; esac

    if [ -f "$OUTPUT_DIR/${type}.sh" ]; then
        (
            # shellcheck disable=SC1090
            . "$OUTPUT_DIR/${type}.sh"
            if "send_${type}" "$section" "$lat" "$lon" "$acc" "$ts" "$src"; then
                echo "ok $(date +%s)" > "$status_dir/$section"
            else
                echo "error $(date +%s)" > "$status_dir/$section"
            fi
        ) &
    else
        logger -t geolocate "Output type '$type' not found at $OUTPUT_DIR/${type}.sh"
    fi
}
