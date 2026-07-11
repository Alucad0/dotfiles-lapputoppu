#!/usr/bin/env bash
# Waybar Spotify controller modules (info/play/pause/next).
# Prints nothing when Spotify is closed — waybar hides empty custom
# modules, so the whole controller pops up only while Spotify runs.
#   spotify.sh info   -> {"text":"[Song - Artist]", ...}
#   spotify.sh prev|toggle|next -> button icon (toggle flips play/pause)
set -uo pipefail

mode="${1:-info}"

# No spotify player registered on MPRIS -> hide all modules
status="$(playerctl -p spotify status 2>/dev/null)" || exit 0

case "$mode" in
    prev)  printf '{"text":"󰒮"}\n' ;;
    next)  printf '{"text":"󰒭"}\n' ;;
    toggle)
        if [ "$status" = "Playing" ]; then
            printf '{"text":"󰏤"}\n'
        else
            printf '{"text":"󰐊"}\n'
        fi
        ;;
    info)
        title="$(playerctl -p spotify metadata title 2>/dev/null)"
        artist="$(playerctl -p spotify metadata artist 2>/dev/null)"
        # python handles both pango-escaping (& in titles) and JSON quoting
        python3 - "$title" "$artist" "$status" <<'PY'
import html, json, sys
title, artist, status = sys.argv[1:4]
text = f"[{title} - {artist}]" if title else "[Spotify]"
print(json.dumps({
    "text": html.escape(text),
    "tooltip": html.escape(f"{status}: {title} - {artist}"),
    "class": status.lower(),
}))
PY
        ;;
esac
