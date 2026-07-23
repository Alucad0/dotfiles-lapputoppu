# dotfiles — lapputoppu

The dotfiles for my riced Arch Linux setup. Catppuccin Mocha everywhere.

| | |
|---|---|
| WM | [Hyprland](https://hyprland.org/) + hyprpaper (wallpaper cycler in `hypr/scripts/`) |
| Bar | [Waybar](https://github.com/Alexays/Waybar) — frosted islands, per-core CPU dropdown (`waybar/scripts/`) |
| Terminal | kitty |
| Shell | zsh |
| Launcher | wofi — Mocha-styled drun menu (`wofi/`) |
| Login | [SDDM](https://github.com/sddm/sddm) + [sugar-candy](https://github.com/Kangie/sddm-sugar-candy) theme (`sddm/`, system config — see below) |
| Editor | VS Code — settings in `vscode/`, CodeNewRoman Nerd Font in editor + integrated terminal |
| Claude Code | ccstatusline status line + settings |
| Fonts | CodeNewRoman [Nerd Font](https://www.nerdfonts.com/cheat-sheet) for icons, Noto CJK + Color Emoji for Japanese/emoji — `fontconfig/` prefers the JP glyph variants and adds emoji fallback |

## Preview

![wyabar](preview_waybar.png)

## Layout

Every top-level directory is a "package" mirroring its layout relative to `$HOME`
(GNU stow style — `waybar/.config/waybar/config.jsonc` → `~/.config/waybar/config.jsonc`).

Exception: `sddm/` holds system config (files under `/etc` and `/usr/share`), so
`install.sh` refuses to symlink it — install it manually, see below.

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

- **SDDM**: the sddm package itself is in `packages.txt`, but the
  [sugar-candy theme](https://github.com/Kangie/sddm-sugar-candy) is not in the
  repos — install it from the AUR (`sddm-sugar-candy-git`) or clone it into
  `/usr/share/sddm/themes/sugar-candy`. Then copy the configs (root-owned, so
  no symlinks — re-copy after editing):

  ```sh
  sudo cp sddm/sddm.conf.d/zz-sugar-candy.conf /etc/sddm.conf.d/
  sudo cp sddm/themes/sugar-candy/theme.conf /usr/share/sddm/themes/sugar-candy/
  sudo cp sddm/themes/sugar-candy/Components/Input.qml /usr/share/sddm/themes/sugar-candy/Components/
  sudo chown "$USER" /usr/share/sddm/themes/sugar-candy/Backgrounds/current.jpg
  sudo systemctl enable sddm
  ```

  `theme.conf` restyles the theme (blur, cyan accent, `AllowBadUsernames` for
  the lowercase login). `Input.qml` patches two upstream bugs: the last user
  not being prefilled, and the ComboBox rendering a stray first-letter of the
  username behind the user icon (`displayText: ""`).

  The login background is `Backgrounds/current.jpg` — the wallpaper scripts
  (`wallpaper-cycle.sh`, `wallpaper-select.sh`) overwrite it on every wallpaper
  change so the greeter matches the session. That's what the `chown` above is
  for; without it the scripts silently skip the sync.
- **bun** (JS runtime, no node on these machines): `curl -fsSL https://bun.sh/install | bash`,
  then `bun install -g ccstatusline`. The Claude Code status line and the
  `ccstatusline` zsh alias expect it at `~/.bun` / `~/.cache/.bun/bin`.
- `claude/.claude/settings.json` hardcodes `/home/Alucado/...` paths — adjust if
  the username differs on the other machine.
- Wallpapers live in `~/Pictures/Wallpaper` (not in the repo); hyprpaper,
  waypaper and the cycler script point there.
