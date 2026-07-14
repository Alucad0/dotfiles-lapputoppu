#!/usr/bin/env bash
# Symlinks every file in the given packages (default: all) into $HOME,
# mirroring the repo's directory structure — GNU stow layout, no stow needed.
# Existing real files are moved to ~/.dotfiles-backup/<timestamp>/ first.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ALL_PACKAGES=(hypr waybar kitty ccstatusline waypaper zsh git claude wallpapers vscode fontconfig)

PACKAGES=("${@:-${ALL_PACKAGES[@]}}")

for pkg in "${PACKAGES[@]}"; do
    if [ ! -d "$REPO/$pkg" ]; then
        echo "!! unknown package: $pkg (available: ${ALL_PACKAGES[*]})" >&2
        exit 1
    fi
    while IFS= read -r -d '' src; do
        rel="${src#"$REPO/$pkg/"}"
        dest="$HOME/$rel"
        mkdir -p "$(dirname "$dest")"
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$src" ]; then
            continue  # already linked
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            mkdir -p "$BACKUP/$(dirname "$rel")"
            mv "$dest" "$BACKUP/$rel"
            echo "backed up: ~/$rel"
        fi
        ln -s "$src" "$dest"
        echo "linked: ~/$rel"
    done < <(find "$REPO/$pkg" -type f -print0)
done

echo "done. backups (if any) in $BACKUP"
