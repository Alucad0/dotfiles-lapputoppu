#!/usr/bin/env bash
# Waybar screen-share module: icon appears while an external display cable
# (HDMI or DisplayPort) is plugged in; clicking opens a wofi menu that
# applies the chosen layout with hyprctl.
#   screenshare.sh        -> status JSON (prints nothing when unplugged,
#                            which hides the module)
#   screenshare.sh menu   -> wofi picker: mirror / extend / external off
#   screenshare.sh cycle  -> F7: Win+P-style — each press advances
#                            mirror -> extend right -> external off in a
#                            self-closing OSD; the mode is applied shortly
#                            after the last press. Without a cable it shows
#                            a "no display" notice, so F7 always responds.
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

apply_mirror() {
    # Same aspect on both screens -> no pillarbox, no side flicker
    hyprctl eval "hl.monitor({ output = '$INTERNAL', mode = '$MIRROR_MODE', position = '0x0', scale = $MIRROR_INT_SCALE })"
    hyprctl eval "hl.monitor({ output = '$1', mode = 'preferred', position = 'auto', scale = 1, mirror = '$INTERNAL' })"
    touch "$MIRROR_MARKER"
}

# Extend: place the external screen and park a dedicated workspace on it,
# so sharing that display always shows the same workspace
apply_extend() { # $1 = external output, $2 = auto-right/-left/-up/-down
    restore_internal
    hyprctl eval "hl.monitor({ output = '$1', mode = 'preferred', position = '$2', scale = 1 })"
    hyprctl eval "hl.workspace_rule({ workspace = '$EXT_WORKSPACE', monitor = '$1', default = true })"
    hyprctl dispatch "hl.dsp.workspace.move({ workspace = $EXT_WORKSPACE, monitor = '$1' })"
}

apply_off() {
    hyprctl eval "hl.monitor({ output = '$1', disabled = true })"
    restore_internal
}

# Transient OSD: a wofi that kills its predecessor and closes itself, so
# repeated F7 presses never stack instances (overlapping wofis fail to map)
OSD_PID="${XDG_RUNTIME_DIR:-/tmp}/waybar-screenshare-osd.pid"
PENDING="${XDG_RUNTIME_DIR:-/tmp}/waybar-screenshare-pending"

osd() { # $1 = prompt, rest = lines
    local prompt="$1" pid; shift
    [ -f "$OSD_PID" ] && kill "$(cat "$OSD_PID")" 2>/dev/null
    printf '%s\n' "$@" | wofi --dmenu --prompt "$prompt" --lines $(($# + 1)) \
        --width 420 --cache-file /dev/null >/dev/null &
    pid=$!
    echo "$pid" > "$OSD_PID"
    { sleep 1.8; kill "$pid" 2>/dev/null; } &
}

# What the cycle is currently showing (from the live state, no stale files)
current_mode() { # $1 = external output
    if [ -e "$MIRROR_MARKER" ]; then echo mirror
    elif hyprctl monitors 2>/dev/null | grep -qF "Monitor $1"; then echo extend
    else echo off; fi
}

if [ "${1:-status}" = "menu" ]; then
    # No cable: still give visible feedback instead of silence (the layout
    # options would have no display to act on)
    if ! ext="$(external)"; then
        osd "Screen sharing" "󰶐  No external display connected"
        exit 0
    fi
    choice="$(printf '%s\n' \
        "󰍺  Mirror laptop screen" \
        "󰞔  Extend right" \
        "󰞓  Extend left" \
        "󰞕  Extend above" \
        "󰞒  Extend below" \
        "󰶐  External off" \
        | wofi --dmenu --prompt "Screen sharing: $ext" --lines 7)" || exit 0

    case "$choice" in
        *Mirror*)  apply_mirror "$ext" ;;
        *right*)   apply_extend "$ext" auto-right ;;
        *left*)    apply_extend "$ext" auto-left ;;
        *above*)   apply_extend "$ext" auto-up ;;
        *below*)   apply_extend "$ext" auto-down ;;
        *off*)     apply_off "$ext" ;;
        *) exit 0 ;;
    esac

    pkill -RTMIN+9 waybar
    exit 0
fi

if [ "${1:-status}" = "cycle" ]; then
    if ! ext="$(external)"; then
        osd "Screen sharing" "󰶐  No external display connected"
        exit 0
    fi

    # Advance from the pending pick if one is still debouncing, else from
    # what is actually on screen
    cur="$(cat "$PENDING" 2>/dev/null || current_mode "$ext")"
    case "$cur" in
        mirror) next=extend ;;
        extend) next=off ;;
        *)      next=mirror ;;
    esac
    printf '%s' "$next" > "$PENDING"

    m=("    " "    " "    ")
    case "$next" in
        mirror) m[0]="●  " ;;
        extend) m[1]="●  " ;;
        off)    m[2]="●  " ;;
    esac
    osd "Screen sharing: $ext" \
        "${m[0]}󰍺  Mirror laptop screen" \
        "${m[1]}󰞔  Extend right" \
        "${m[2]}󰶐  External off"

    # Debounced apply: only the last press within 1.2s acts, so cycling past
    # mirror doesn't re-mode the panel on the way
    { sleep 1.2
      if [ "$(cat "$PENDING" 2>/dev/null)" = "$next" ]; then
          case "$next" in
              mirror) apply_mirror "$ext" ;;
              extend) apply_extend "$ext" auto-right ;;
              off)    apply_off "$ext" ;;
          esac
          rm -f "$PENDING"
          pkill -RTMIN+9 waybar
      fi
    } &
    exit 0
fi

# status mode
if ! ext="$(external)"; then
    # Cable pulled while mirroring: put the panel back to 2880x1800@2
    [ -e "$MIRROR_MARKER" ] && restore_internal >/dev/null
    exit 0
fi
echo "{\"text\":\"<span size='12000' rise='-2000'>󰍺</span>\",\"tooltip\":\"$ext connected — click to set up mirror/extend\"}"
