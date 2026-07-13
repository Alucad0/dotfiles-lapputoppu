#!/usr/bin/env bash
# Wallpaper picker behind the waybar image icon: wofi thumbnail grid over
# the top-level images in ~/Pictures/Wallpaper. Applies the pick through
# hyprpaper IPC (same command wallpaper-cycle.sh uses), then signals the
# cycler with USR1 so its auto-cycle timer restarts at a full interval
# without immediately replacing the manual pick.

WALLPAPER_DIR="$HOME/Pictures/Wallpaper"

mapfile -t images < <(find -L "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
       -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) | sort)
(( ${#images[@]} > 0 )) || exit 0

choice=$(for img in "${images[@]}"; do
        name="$(basename "$img")"
        printf 'img:%s:text:%s\n' "$img" "${name%.*}"
    done | wofi --dmenu --allow-images --define image_size=110 \
        --columns 4 --width 640 --height 480 --prompt 'wallpaper' \
        --insensitive --hide-scroll --cache-file /dev/null)
[ -n "$choice" ] || exit 0

# wofi may echo back the raw "img:PATH:text:NAME" line or just NAME
case "$choice" in
    img:*)
        img="${choice#img:}"
        img="${img%%:text:*}"
        ;;
    *)
        img=""
        for f in "${images[@]}"; do
            name="$(basename "$f")"
            [ "${name%.*}" = "$choice" ] && img="$f" && break
        done
        ;;
esac
[ -f "$img" ] || exit 1

while read -r mon; do
    [ -n "$mon" ] && hyprctl hyprpaper wallpaper "$mon,$img" >/dev/null 2>&1
done < <(hyprctl monitors | awk '/^Monitor/{print $2}')

# restart the auto-cycle timer (no-op if the cycler isn't running)
pkill -USR1 -f 'wallpaper-cycle\.sh' 2>/dev/null
exit 0
