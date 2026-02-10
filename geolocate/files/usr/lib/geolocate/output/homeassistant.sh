# shellcheck shell=dash
# Home Assistant mobile_app webhook output
# Two-phase: one-time registration (needs access_token), then ongoing webhook POSTs (no auth)

HA_WEBHOOK_CACHE="/tmp/geolocate/ha_webhook_id"

register_ha() {
    local section="$1"
    local ha_url access_token
    config_get ha_url "$section" ha_url
    config_get access_token "$section" access_token

    if [ -z "$ha_url" ] || [ -z "$access_token" ]; then
        logger -t geolocate "homeassistant: cannot register — missing ha_url or access_token"
        return 1
    fi

    ha_url="${ha_url%/}"

    # Registration payload
    local reg_json
    local os_ver
    # shellcheck disable=SC1091
    os_ver=$(. /etc/openwrt_release 2>/dev/null; echo "$DISTRIB_RELEASE")
    [ -z "$os_ver" ] && os_ver="unknown"

    reg_json=$(printf '{"device_id":"openwrt-geolocate","app_id":"openwrt_geolocate","app_name":"OpenWrt Geolocate","app_version":"0.1.0","device_name":"OpenWrt Router","manufacturer":"OpenWrt","model":"Router","os_name":"OpenWrt","os_version":"%s","supports_encryption":false}' "$os_ver")

    logger -t geolocate "homeassistant: registering device at ${ha_url}"

    local response
    response=$(curl -sf --max-time 15 -X POST \
        "${ha_url}/api/mobile_app/registrations" \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d "$reg_json" 2>/dev/null)

    if [ -z "$response" ]; then
        logger -t geolocate "homeassistant: registration failed — no response"
        return 1
    fi

    # Extract webhook_id from response
    local webhook_id
    webhook_id=$(echo "$response" | jsonfilter -e '@.webhook_id' 2>/dev/null)

    if [ -z "$webhook_id" ]; then
        logger -t geolocate "homeassistant: registration failed — no webhook_id in response"
        return 1
    fi

    # Validate webhook_id format
    case "$webhook_id" in *[!a-zA-Z0-9_-]*)
        logger -t geolocate "homeassistant: invalid webhook_id format"
        return 1
    ;; esac

    # Store webhook_id in UCI and cache file
    uci set "geolocate.${section}.webhook_id=${webhook_id}"
    uci commit geolocate
    echo "$webhook_id" > "$HA_WEBHOOK_CACHE"

    logger -t geolocate "homeassistant: registered successfully, webhook_id stored"
    return 0
}

send_homeassistant() {
    local section="$1"
    local lat="$2"
    local lon="$3"
    local acc="$4"
    # shellcheck disable=SC2034
    local ts="$5"
    # shellcheck disable=SC2034
    local src="$6"

    local ha_url webhook_id
    config_get ha_url "$section" ha_url

    # Read webhook_id from cache first (avoids UCI in background subshell)
    if [ -f "$HA_WEBHOOK_CACHE" ]; then
        webhook_id=$(cat "$HA_WEBHOOK_CACHE")
    fi
    [ -z "$webhook_id" ] && config_get webhook_id "$section" webhook_id

    # If no webhook_id, try to register
    if [ -z "$webhook_id" ]; then
        register_ha "$section" || return 1
        [ -f "$HA_WEBHOOK_CACHE" ] && webhook_id=$(cat "$HA_WEBHOOK_CACHE")
        [ -z "$webhook_id" ] && return 1
    fi

    if [ -z "$ha_url" ]; then
        logger -t geolocate "homeassistant: missing ha_url"
        return 1
    fi

    ha_url="${ha_url%/}"

    # mobile_app webhook: gps_accuracy is required when gps is present, and must be > 0
    local acc_val="$acc"
    [ -z "$acc_val" ] || [ "$acc_val" = "0" ] && acc_val=1

    local json
    json=$(printf '{"type":"update_location","data":{"gps":[%s,%s],"gps_accuracy":%s}}' \
        "$lat" "$lon" "$acc_val")

    logger -t geolocate "homeassistant: sending to webhook"
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST \
        "${ha_url}/api/webhook/${webhook_id}" \
        -H "Content-Type: application/json" \
        -d "$json")

    case "$http_code" in
        2*) return 0 ;;
        410)
            logger -t geolocate "homeassistant: webhook gone (410), clearing for re-registration"
            rm -f "$HA_WEBHOOK_CACHE"
            # Clear UCI webhook_id — next main loop iteration will re-register
            uci delete "geolocate.${section}.webhook_id" 2>/dev/null
            uci commit geolocate 2>/dev/null
            return 1
            ;;
        *)
            logger -t geolocate "homeassistant: send failed (HTTP $http_code)"
            return 1
            ;;
    esac
}
