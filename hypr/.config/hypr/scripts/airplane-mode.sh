#!/usr/bin/env bash
# Airplane mode software toggle (right-click on the waybar wifi module):
# soft-blocks every radio via rfkill, or unblocks them all again —
# NetworkManager and bluez both follow rfkill, so wifi reconnects and
# bluetooth comes back by themselves on the way out. The F9 airplane key
# itself is handled by the laptop firmware (wifi only, see hyprland.lua).
set -euo pipefail

if rfkill list | grep -q 'blocked: yes'; then
    rfkill unblock all
else
    rfkill block all
fi
# instant refresh of the custom/network module (same signal in config.jsonc)
pkill -RTMIN+7 -x waybar 2>/dev/null || true
