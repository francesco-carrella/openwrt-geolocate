# geolocate - WiFi/Cell Geolocation for OpenWrt

Know where your router is — geolocation for OpenWrt.

`geolocate` determines your OpenWrt router's geographic position by scanning nearby WiFi access points and cell towers, then resolving them through a geolocation API. It works out of the box with [BeaconDB](https://beacondb.net) (free, no API key) and can forward your position to self-hosted tracking platforms.

> **v0.1.0 — Early release.** Tested on GL.iNet GL-E750 (Mudi V2) with OpenWrt 22.03. Looking for testers on other hardware — see [Help Wanted](#help-wanted) below.

## Features

- **Zero-config** — BeaconDB requires no account or API key. Install and go.
- **WiFi + Cell** — Scans access points and cell towers, combines both automatically.
- **Multiple backends** — BeaconDB (default), Google Geolocation API, Unwired Labs, or any MLS-compatible endpoint.
- **Tracker forwarding** — Traccar, OwnTracks, Dawarich, Home Assistant, or generic webhook.
- **LuCI web interface** — Live map, settings, and tracker configuration with health status.
- **Privacy-first** — No telemetry. `_nomap` SSIDs and randomized BSSIDs are filtered.

## Installation

Download the `.ipk` packages from the [latest release](../../releases/latest) and install on your router:

```sh
scp -O geolocate_*_all.ipk luci-app-geolocate_*_all.ipk root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "
  opkg install /tmp/geolocate_*_all.ipk
  opkg install /tmp/luci-app-geolocate_*_all.ipk
  /etc/init.d/geolocate enable
  /etc/init.d/geolocate restart
  /etc/init.d/rpcd reload
  rm -f /tmp/*geolocate*_all.ipk
"
```

**Requirements:** OpenWrt 22.03+, `curl`, `jsonfilter`, `rpcd`, `iwinfo`, `luci-lib-jsonc`, `lua`

## Usage

Navigate to **Services > Geolocate** in LuCI:

| Tab          | Purpose                                          |
| ------------ | ------------------------------------------------ |
| **Overview** | Live map, position, accuracy, source             |
| **Settings** | Backend provider, scan interval, WiFi/cell config |
| **Trackers** | Enable/configure position forwarding             |

Or from the command line:

```sh
ubus call geolocate info           # Current position
ubus call geolocate scan           # Trigger immediate scan
ubus call geolocate output_status  # Tracker health
```

## Backends

| Provider               | API Key    | Notes                               |
| ---------------------- | ---------- | ----------------------------------- |
| **BeaconDB**           | Not needed | Default. Free, open-source          |
| **Google Geolocation** | Required   | Most accurate. Paid.                |
| **Unwired Labs**       | Required   | Freemium tier                       |
| **Custom endpoint**    | Optional   | Any MLS-compatible API              |

## Trackers

| Tracker            | Protocol              | Auth                      |
| ------------------ | --------------------- | ------------------------- |
| **Traccar**        | OsmAnd (HTTP GET)     | Device ID                 |
| **OwnTracks**      | HTTP POST to Recorder | Basic Auth                |
| **Dawarich**       | OwnTracks-compatible  | API Key                   |
| **Home Assistant** | mobile_app webhook    | Access Token → webhook ID |
| **Webhook**        | Generic POST/PUT      | Custom header             |

## Cell Modem Support

The daemon auto-detects whichever modem tool is installed:

| Tool             | Modems                    | Notes                    |
| ---------------- | ------------------------- | ------------------------ |
| `gl_modem`       | GL.iNet devices           | AT commands via serial   |
| `mmcli`          | QMI, MBIM, AT (any modem) | Requires ModemManager    |

No modem tools are required — WiFi-only geolocation works without any cell hardware.

## Help Wanted

This is an early release. The core works well on the tested device, but community testing is needed:

- **Different routers** — Does WiFi scanning work with your driver? (ath10k, mt76, etc.)
- **Cell modems** — mmcli path needs real-world validation on non-GL.iNet hardware
- **Tracker integrations** — OwnTracks, Dawarich, and Home Assistant are implemented per docs but untested against live servers
- **OpenWrt versions** — Tested on 22.03, should work on 23.05+

If you test on your device, please [open an issue](../../issues). Run this on your router and paste the output:

```sh
echo "=== device ==="
cat /etc/openwrt_release
echo "=== daemon ==="
pgrep -l geolocate || echo "not running"
echo "=== status ==="
ubus call geolocate info 2>&1
echo "=== wifi ==="
iwinfo wlan0 info 2>&1 | head -2
echo "=== cell tools ==="
for t in gl_modem mmcli; do command -v $t >/dev/null 2>&1 && echo "$t: yes" || echo "$t: no"; done
echo "=== logs ==="
logread -e geolocate | tail -20
```

Then describe what worked and what didn't.

### Tested Hardware

| Device                     | OpenWrt | WiFi  | Cell                       | Status  |
| -------------------------- | ------- | ----- | -------------------------- | ------- |
| GL.iNet GL-E750 (Mudi V2) | 22.03.4 | ath9k | Quectel EP06 (gl_modem AT) | Working |

## License

GPL-2.0
