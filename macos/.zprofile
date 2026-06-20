
eval "$(/opt/homebrew/bin/brew shellenv)"

# pyenv — put shims on PATH for login/non-interactive shells. The interactive
# shell function + completions are set up in ~/.zshrc via `pyenv init - zsh`.
eval "$(pyenv init --path)"

# Created by `pipx` on 2025-07-31 19:10:51
export PATH="$PATH:/Users/dro/.local/bin"
export PATH="/Library/TeX/texbin:$PATH"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
