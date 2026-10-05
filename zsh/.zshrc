# Powerlevel10k instant prompt — keep this at the top. Anything that prints to
# or reads from the console must go above it.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# oh-my-zsh + powerlevel10k — both are git clones, not packages; install.sh
# fetches them when the zsh package is linked (see README)
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
# autosuggestions = ghost-text from history (→ accepts), syntax-highlighting
# colours the command line as you type — it must stay last in the list
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Prompt appearance. `p10k configure` rewrites ~/.p10k.zsh, which is this
# repo's zsh/.p10k.zsh — so reconfiguring the prompt shows up in `git diff`.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Prompt accent follows the desktop theme: ~/.local/bin/theme generates this
# overlay (not in the repo — run `theme apply` if it's missing) and the hook
# re-sources it when the saved theme changes, so open shells recolour on
# their next prompt.
[[ ! -f ~/.config/zsh/p10k-theme.zsh ]] || source ~/.config/zsh/p10k-theme.zsh
_theme_prompt_precmd() {
  local cur state=~/.local/state/theme/current
  [[ -r $state ]] || return 0
  IFS= read -r cur < $state
  [[ $cur == ${_THEME_PROMPT_CURRENT-} || ! -f ~/.config/zsh/p10k-theme.zsh ]] && return 0
  source ~/.config/zsh/p10k-theme.zsh
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _theme_prompt_precmd

# pipx shims + the scripts in the `bin` package (snapshot, screenshot)
export PATH="$HOME/.local/bin:$PATH"

# bun (the JS runtime; no node on these machines)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# ccstatusline config TUI (runs via bun, no node installed)
alias ccstatusline="bun $HOME/.cache/.bun/bin/ccstatusline"

# Hyprland's log is ~99% libinput touchpad debug from aquamarine (gesture/tap
# state machines). `debug:disable_logs` doesn't gate those - they come from
# aquamarine's own logger - so filter them out when reading instead.
alias hyprlog="grep -vE 'DEBUG from aquamarine' \"\$(ls -t /run/user/\$UID/hypr/*/hyprland.log | head -1)\""
