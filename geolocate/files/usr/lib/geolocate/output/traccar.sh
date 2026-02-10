# shellcheck shell=dash
send_traccar() {
    local section="$1"
    local lat="$2"
    local lon="$3"
    local acc="$4"
    local ts="$5"
    # shellcheck disable=SC2034
    local src="$6"

    local url device_id
    config_get url "$section" url
    config_get device_id "$section" device_id

    if [ -z "$url" ] || [ -z "$device_id" ]; then
        logger -t geolocate "traccar: missing URL or device_id"
        return 1
    fi

    # Strip trailing slash — user provides full URL including port
    # e.g. http://traccar.example.com:5055
    url="${url%/}"

    # OsmAnd protocol: simple GET with query parameters
    local full_url="${url}/?id=${device_id}&lat=${lat}&lon=${lon}&accuracy=${acc}&timestamp=${ts}"

    logger -t geolocate "traccar: sending to ${url}"
    curl -sf --max-time 10 -o /dev/null "$full_url" || {
        logger -t geolocate "traccar: send failed"
        return 1
    }
}
