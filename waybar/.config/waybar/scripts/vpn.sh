#!/usr/bin/env bash
# Waybar VPN island — always prints something, so the island is permanently
# visible and doubles as a launcher for the Proton VPN app.
# Proton VPN (GTK app) creates an NM wireguard connection named
# "ProtonVPN <server>" (e.g. "ProtonVPN SE#65") on device proton0 — the
# server's country code becomes "[Sweden]". Other NM vpn/wireguard
# connections show their name; raw wg*/tun*/tailscale* interfaces are a
# last-resort fallback for apps that bypass NetworkManager. With no tunnel
# up the island shows a dimmed "[VPN]".
#   vpn.sh -> {"text":"[Sweden]", ...} or {"text":"[VPN]", ...}
#   vpn.sh click -> focus the Proton VPN window, or launch the app if it
#                   has no window (closed, or minimized to tray)
set -uo pipefail

if [ "${1:-}" = "click" ]; then
    if hyprctl clients -j 2>/dev/null | grep -q '"class": "proton.vpn.app.gtk"'; then
        hyprctl dispatch 'hl.dsp.focus({ window = "class:^(proton.vpn.app.gtk)$" })'
    else
        setsid protonvpn-app >/dev/null 2>&1 &
    fi
    exit 0
fi

country_name() { # ISO 3166 alpha-2 code -> country name (falls back to the code)
    local code=${1^^} name=""
    [ -r /usr/share/zoneinfo/iso3166.tab ] &&
        name="$(awk -F'\t' -v c="$code" '$1 == c { print $2 }' /usr/share/zoneinfo/iso3166.tab)"
    printf '%s' "${name:-$code}"
}

emit() { # $1 = island text, $2 = tooltip detail
    local text=$1 detail=$2
    # escape backslashes and quotes for JSON
    text=${text//\\/\\\\};     text=${text//\"/\\\"}
    detail=${detail//\\/\\\\}; detail=${detail//\"/\\\"}
    printf '{"text":"%s","tooltip":"VPN connected: %s","class":"connected"}\n' "$text" "$detail"
    exit 0
}

if command -v nmcli >/dev/null 2>&1; then
    while IFS=: read -r name type device; do
        case "$name" in pvpn-*) continue ;; esac  # proton killswitch helpers
        case "$type" in
            vpn|wireguard)
                if [[ "$name" == "ProtonVPN "* ]]; then
                    server=${name#ProtonVPN }   # SE#65 / US-TX#123 / NL-FREE#1
                    code=${server%%#*}          # country is the first token
                    code=${code%%-*}            # (secure core shows its entry country)
                    emit "[$(country_name "$code")]" "$name ($type on ${device:-no device})"
                else
                    emit "[$name]" "$name ($type on ${device:-no device})"
                fi
                ;;
        esac
    done < <(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null)
fi

for ifpath in /sys/class/net/wg* /sys/class/net/tun* /sys/class/net/tailscale*; do
    [ -e "$ifpath" ] || continue
    iface=${ifpath##*/}
    emit "[$iface]" "$iface (interface up, managed outside NetworkManager)"
done

# No tunnel up — keep the island (dimmed); the tooltip says whether the
# Proton app is running, since clicking launches it when it isn't
if pgrep -f protonvpn-app >/dev/null 2>&1; then
    printf '{"text":"[VPN]","tooltip":"Proton VPN: disconnected","class":"disconnected"}\n'
else
    printf '{"text":"[VPN]","tooltip":"Proton VPN: not running — click to open","class":"disconnected"}\n'
fi

exit 0
