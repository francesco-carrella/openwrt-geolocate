# shellcheck shell=dash
send_dawarich() {
    local section="$1"
    local lat="$2"
    local lon="$3"
    local acc="$4"
    local ts="$5"
    # shellcheck disable=SC2034
    local src="$6"

    local url api_key
    config_get url "$section" url
    config_get api_key "$section" api_key

    if [ -z "$url" ] || [ -z "$api_key" ]; then
        logger -t geolocate "dawarich: missing URL or API key"
        return 1
    fi

    url="${url%/}"

    # Dawarich uses OwnTracks-compatible format at /api/v1/owntracks/points
    # MUST include topic field — without it, Dawarich interprets vel as m/s instead of km/h
    local json
    json=$(printf '{"_type":"location","lat":%s,"lon":%s,"acc":%s,"tst":%s,"tid":"GL","conn":"w","t":"t","topic":"owntracks/geolocate/router"}' \
        "$lat" "$lon" "$acc" "$ts")

    logger -t geolocate "dawarich: sending to ${url}"
    curl -sf --max-time 10 -o /dev/null -X POST \
        "${url}/api/v1/owntracks/points?api_key=${api_key}" \
        -H "Content-Type: application/json" \
        -d "$json" || {
        logger -t geolocate "dawarich: send failed"
        return 1
    }
}
