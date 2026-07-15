# dotfiles — lapputoppu

The dotfiles for my riced Arch Linux setup. Catppuccin Mocha everywhere.

| | |
|---|---|
| WM | [Hyprland](https://hyprland.org/) + hyprpaper (wallpaper cycler in `hypr/scripts/`) |
| Bar | [Waybar](https://github.com/Alexays/Waybar) — frosted islands, per-core CPU dropdown (`waybar/scripts/`) |
| Terminal | kitty |
| Shell | zsh |
| Launcher | wofi |
| Editor | VS Code — settings in `vscode/`, CodeNewRoman Nerd Font in editor + integrated terminal |
| Claude Code | ccstatusline status line + settings |
| Fonts | CodeNewRoman [Nerd Font](https://www.nerdfonts.com/cheat-sheet) for icons, Noto CJK + Color Emoji for Japanese/emoji — `fontconfig/` prefers the JP glyph variants and adds emoji fallback |

## Preview

![wyabar](preview_waybar.png)

## Layout

Every top-level directory is a "package" mirroring its layout relative to `$HOME`
(GNU stow style — `waybar/.config/waybar/config.jsonc` → `~/.config/waybar/config.jsonc`).

## Install (new machine)

```sh
sudo pacman -S --needed - < packages.txt
git clone git@github.com:Alucad0/dotfiles-lapputoppu.git
cd dotfiles-lapputoppu
./install.sh              # symlink everything
./install.sh waybar zsh   # ...or just some packages
```

`install.sh` symlinks every file into place and moves anything it would
overwrite to `~/.dotfiles-backup/<timestamp>/`. No dependencies — but the
layout is stow-compatible, so `stow */` works too if you prefer.

Editing a linked file edits the repo copy: `git diff` in the repo shows your
uncommitted tweaks, `git pull` updates both machines.

## Manual bits not covered

- **bun** (JS runtime, no node on these machines): `curl -fsSL https://bun.sh/install | bash`,
  then `bun install -g ccstatusline`. The Claude Code status line and the
  `ccstatusline` zsh alias expect it at `~/.bun` / `~/.cache/.bun/bin`.
- `claude/.claude/settings.json` hardcodes `/home/Alucado/...` paths — adjust if
  the username differs on the other machine.
- Wallpapers live in `~/Pictures/Wallpaper` (not in the repo); hyprpaper,
  waypaper and the cycler script point there.
