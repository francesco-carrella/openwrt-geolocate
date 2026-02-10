# shellcheck shell=dash
send_webhook() {
    local section="$1"
    local lat="$2"
    local lon="$3"
    local acc="$4"
    local ts="$5"
    local src="$6"

    local url method device_id header_name header_value
    config_get url "$section" url
    config_get method "$section" method "POST"
    config_get device_id "$section" device_id ""
    config_get header_name "$section" header_name ""
    config_get header_value "$section" header_value ""

    if [ -z "$url" ]; then
        logger -t geolocate "webhook: missing URL"
        return 1
    fi

    # Validate HTTP method
    case "$method" in
        POST|PUT|PATCH) ;;
        *) logger -t geolocate "webhook: invalid method '$method', defaulting to POST"; method="POST" ;;
    esac

    local json
    json=$(printf '{"latitude":%s,"longitude":%s,"accuracy":%s,"timestamp":%s,"source":"%s","device":"%s"}' \
        "$lat" "$lon" "$acc" "$ts" "$src" "$device_id")

    local auth_header=""
    if [ -n "$header_name" ] && [ -n "$header_value" ]; then
        auth_header="-H"
    fi

    logger -t geolocate "webhook: sending to ${url}"
    if [ -n "$auth_header" ]; then
        curl -sf --max-time 10 -o /dev/null -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -H "${header_name}: ${header_value}" \
            -d "$json"
    else
        curl -sf --max-time 10 -o /dev/null -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$json"
    fi || {
        logger -t geolocate "webhook: send failed"
        return 1
    }
}
