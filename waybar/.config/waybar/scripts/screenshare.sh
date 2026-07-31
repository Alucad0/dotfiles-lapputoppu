#!/usr/bin/env bash
# Waybar screen-share module: icon appears while an external display cable
# (HDMI or DisplayPort) is plugged in; clicking opens a wofi menu that
# applies the chosen layout with hyprctl.
#   screenshare.sh        -> status JSON (prints nothing when unplugged,
#                            which hides the module)
#   screenshare.sh menu   -> wofi picker: mirror / extend / external off
set -uo pipefail

INTERNAL="eDP-1"
EXT_WORKSPACE=10     # workspace pinned to the external screen in extend mode

# The panel is 16:10 but externals are usually 16:9; mirroring across that
# mismatch pillarboxes the external and hyprland flickers in the bar areas.
# So while mirroring, drop the panel to its native 16:9 mode instead.
MIRROR_MODE="1920x1080@90"
MIRROR_INT_SCALE="1.2"   # 1600x900 logical, close to the usual 1440x900
MIRROR_MARKER="${XDG_RUNTIME_DIR:-/tmp}/waybar-screenshare-mirror"

restore_internal() {
    hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = 'preferred', position = '0x0', scale = 2 })"
    rm -f "$MIRROR_MARKER"
}

# First connected DRM connector that isn't the laptop panel, mapped to
# hyprland's monitor name (/sys/class/drm/card1-HDMI-A-1 -> HDMI-A-1)
external() {
    local path name
    for path in /sys/class/drm/card*-*/status; do
        name="${path%/status}"
        name="${name##*/}"
        name="${name#card*-}"
        [ "$name" = "$INTERNAL" ] && continue
        case "$name" in Writeback*) continue ;; esac
        if [ "$(<"$path")" = "connected" ]; then
            printf '%s' "$name"
            return 0
        fi
    done
    return 1
}

if [ "${1:-status}" = "menu" ]; then
    ext="$(external)" || exit 0
    choice="$(printf '%s\n' \
        "󰍺  Mirror laptop screen" \
        "󰞔  Extend right" \
        "󰞓  Extend left" \
        "󰞕  Extend above" \
        "󰞒  Extend below" \
        "󰶐  External off" \
        | wofi --dmenu --prompt "Screen sharing: $ext" --lines 7)" || exit 0

    case "$choice" in
        *Mirror*)
            # Same aspect on both screens -> no pillarbox, no side flicker
            hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = '$MIRROR_MODE', position = '0x0', scale = $MIRROR_INT_SCALE })"
            hyprctl eval "hl.monitor({ output = '$ext', mode = 'preferred', position = 'auto', scale = 1, mirror = '$INTERNAL' })"
            touch "$MIRROR_MARKER"
            ;;
        *right*)   dir="auto-right" ;;
        *left*)    dir="auto-left" ;;
        *above*)   dir="auto-up" ;;
        *below*)   dir="auto-down" ;;
        *off*)
            hyprctl eval "hl.monitor({ output = '$ext', disabled = true })"
            restore_internal
            ;;
        *) exit 0 ;;
    esac

    # Extend: place the external screen and park a dedicated workspace on it,
    # so sharing that display always shows the same workspace
    if [ -n "${dir:-}" ]; then
        restore_internal
        hyprctl eval "hl.monitor({ output = '$ext', mode = 'preferred', position = '$dir', scale = 1 })"
        hyprctl eval "hl.workspace_rule({ workspace = '$EXT_WORKSPACE', monitor = '$ext', default = true })"
        hyprctl dispatch "hl.dsp.workspace.move({ workspace = $EXT_WORKSPACE, monitor = '$ext' })"
    fi

    pkill -RTMIN+9 waybar
    exit 0
fi

# status mode
if ! ext="$(external)"; then
    # Cable pulled while mirroring: put the panel back to 2880x1800@2
    [ -e "$MIRROR_MARKER" ] && restore_internal >/dev/null
    exit 0
fi
echo "{\"text\":\"<span size='12000' rise='-2000'>󰍺</span>\",\"tooltip\":\"$ext connected — click to set up mirror/extend\"}"
