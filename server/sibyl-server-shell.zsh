# Sibyl server profile — additive zsh snippet, sourced from ~/.zshrc by
# server/install.sh. SAFE on a production box: it only defines aliases and
# opt-in hooks. It changes NOTHING about the existing prompt (starship),
# history (atuin), or any running daemon. Remove the `source` line from
# ~/.zshrc and delete this file to fully revert.

# Debian names two tools differently than the Mac. Alias the short name only
# if the Debian-named binary exists AND the short name isn't already taken.
command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && alias bat='batcat'
command -v fdfind >/dev/null 2>&1 && ! command -v fd  >/dev/null 2>&1 && alias fd='fdfind'

# lazy* TUIs (installed by server/install.sh) — fast live triage over SSH.
command -v lazygit    >/dev/null 2>&1 && alias lg='lazygit'
command -v lazydocker >/dev/null 2>&1 && alias lzd='lazydocker'

# direnv — per-directory env via .envrc (opt-in per dir; no global change).
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# vivid — rich Catppuccin-Mocha LS_COLORS (eza/ls/completion), matching the Mac.
# Cached to a file so we don't shell out on every prompt (the Mac eval-cache
# philosophy); regenerate by deleting the cache file.
if command -v vivid >/dev/null 2>&1; then
  _sibyl_lscache="$HOME/.cache/sibyl-ls-colors"
  [ -s "$_sibyl_lscache" ] || vivid generate catppuccin-mocha >"$_sibyl_lscache" 2>/dev/null
  [ -s "$_sibyl_lscache" ] && export LS_COLORS="$(cat "$_sibyl_lscache")"
  unset _sibyl_lscache
fi
