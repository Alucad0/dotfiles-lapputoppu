#!/usr/bin/env bash
# Clipboard history picker (SUPER+H): everything cliphist recorded, newest
# first, in a wofi dmenu — the pick lands back in the clipboard, ready to
# paste. Image entries show as "[[ binary data … ]]" and decode fine.
# The watchers that feed cliphist are started in hyprland.lua.
set -euo pipefail

# long entries get an ellipsis — wofi can't truncate labels itself; cutting
# the preview text is safe since cliphist decode only needs the id prefix.
# 60 chars + id fits the 640px window at the 14px mono font, so nothing is
# ever wide enough to scroll sideways.
sel="$(cliphist list \
    | awk -v max=60 '{ if (length($0) > max) print substr($0, 1, max) "…"; else print }' \
    | wofi --dmenu --prompt clipboard \
        --width 640 --height 480 --insensitive --cache-file /dev/null)"
[ -n "$sel" ] || exit 0
printf '%s\n' "$sel" | cliphist decode | wl-copy
