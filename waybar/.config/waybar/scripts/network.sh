#!/usr/bin/env bash
# Wifi status for waybar's custom/network module. Replaces the builtin
# network module so airplane mode (rfkill, toggled by hypr's
# airplane-mode.sh) gets its own state instead of looking like a plain
# disconnect. The alt field picks the icon in config.jsonc.
set -uo pipefail

json() { # text alt tooltip   (alt doubles as the css class)
    local t=${1//\\/\\\\}; t=${t//\"/\\\"}
    local tip=${3//\\/\\\\}; tip=${tip//\"/\\\"}
    printf '{"text":"%s","alt":"%s","class":"%s","tooltip":"%s"}\n' \
        "$t" "$2" "$2" "$tip"
}

# any wifi block counts: the airplane key soft-blocks via firmware, and a
# hard block (some firmwares use one) can't be cleared from software anyway
if rfkill list wifi 2>/dev/null | grep -q 'blocked: yes'; then
    json "airplane mode" airplane "Radios off — the airplane key or right-click turns them back on"
    exit 0
fi

line="$(nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi 2>/dev/null | grep '^yes:' | head -n1)"
if [ -z "$line" ]; then
    json "Disconnected" disconnected "No wifi connection"
    exit 0
fi
IFS=: read -r _ signal ssid <<< "$line"
level=$(( ${signal:-0} / 20 )); (( level > 4 )) && level=4
json "$ssid" "wifi-$level" "Signal strength: ${signal}%"
