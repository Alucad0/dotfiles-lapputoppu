#!/usr/bin/env bash
# Clipboard history picker (SUPER+H): everything cliphist recorded, newest
# first, in a wofi dmenu — the pick lands back in the clipboard, ready to
# paste. Image entries show as "[[ binary data … ]]" and decode fine.
# The watchers that feed cliphist are started in hyprland.lua.
set -euo pipefail

sel="$(cliphist list | wofi --dmenu --prompt clipboard \
    --width 640 --height 480 --insensitive --cache-file /dev/null)"
[ -n "$sel" ] || exit 0
printf '%s\n' "$sel" | cliphist decode | wl-copy
