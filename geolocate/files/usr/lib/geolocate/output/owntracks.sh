# shellcheck shell=dash
send_owntracks() {
    local section="$1"
    local lat="$2"
    local lon="$3"
    local acc="$4"
    local ts="$5"
    # shellcheck disable=SC2034
    local src="$6"

    local url username device_id password tid
    config_get url "$section" url
    config_get username "$section" username
    config_get device_id "$section" device
    config_get password "$section" password ""
    config_get tid "$section" tid ""

    if [ -z "$url" ] || [ -z "$username" ] || [ -z "$device_id" ]; then
        logger -t geolocate "owntracks: missing URL, username, or device"
        return 1
    fi

    url="${url%/}"

    # Tracker ID: use configured tid, or first 2 chars of device_id (POSIX-safe)
    if [ -z "$tid" ]; then
        tid=$(printf '%.2s' "$device_id")
    fi

    local topic="owntracks/${username}/${device_id}"

    # Construct JSON payload
    local json
    json=$(printf '{"_type":"location","lat":%s,"lon":%s,"acc":%s,"tst":%s,"tid":"%s","conn":"w","t":"t","topic":"%s"}' \
        "$lat" "$lon" "$acc" "$ts" "$tid" "$topic")

    logger -t geolocate "owntracks: sending to ${url}/pub"
    curl -sf --max-time 10 -o /dev/null -X POST "${url}/pub" \
        -u "${username}:${password}" \
        -H "Content-Type: application/json" \
        -H "X-Limit-U: ${username}" \
        -H "X-Limit-D: ${device_id}" \
        -d "$json" || {
        logger -t geolocate "owntracks: send failed"
        return 1
    }
}
