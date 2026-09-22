#!/usr/bin/env bash
# Removes the symlinks install.sh made: for the given packages (default: all),
# any path under $HOME that is a symlink into this repo is unlinked. Real files
# are never touched, so this is safe to run on a machine that has both.
#
# Backups stay where they are — restore an original by hand from
# ~/.dotfiles-backup/<timestamp>/ after running this.
#
#   ./uninstall.sh              # unlink everything
#   ./uninstall.sh waybar zsh   # ...or just some packages
#   ./uninstall.sh -n           # dry run
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_PACKAGES=(hypr waybar kitty ccstatusline waypaper zsh git claude pictures
              vscode fontconfig wofi gtk bin kde xdg themes)

DRY_RUN=0
ARGS=()
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        -h|--help)    sed -n '2,11p' "$0" | sed 's/^# \?//'; exit 0 ;;
        -*)           echo "!! unknown flag: $arg" >&2; exit 1 ;;
        *)            ARGS+=("$arg") ;;
    esac
done

PACKAGES=("${ARGS[@]:-${ALL_PACKAGES[@]}}")

run() {
    if (( DRY_RUN )); then
        printf 'would:'; printf ' %q' "$@"; printf '\n'
    else
        "$@"
    fi
}

removed=0
for pkg in "${PACKAGES[@]}"; do
    if [ ! -d "$REPO/$pkg" ]; then
        echo "!! unknown package: $pkg (available: ${ALL_PACKAGES[*]})" >&2
        exit 1
    fi
    while IFS= read -r -d '' src; do
        rel="${src#"$REPO/$pkg/"}"
        dest="$HOME/$rel"
        # Only ever remove a symlink, and only one pointing into this repo.
        [ -L "$dest" ] || continue
        [ "$(readlink -f "$dest")" = "$src" ] || continue
        run rm "$dest"
        # Drop the parent directory too if this was the last thing in it
        # (never $HOME itself, which rmdir would refuse anyway).
        parent="$(dirname "$dest")"
        if [ "$parent" != "$HOME" ]; then
            run rmdir "$parent" 2>/dev/null || true
        fi
        echo "unlinked: ~/$rel"
        removed=$((removed + 1))
    done < <(find "$REPO/$pkg" -type f -print0)
done

if (( DRY_RUN )); then
    echo "dry run — nothing was changed."
else
    echo "done. $removed symlink(s) removed; backups left in ~/.dotfiles-backup/"
fi
