#!/usr/bin/env bash
# Install these macOS dotfiles into $HOME.
#
#   ./install.sh            # dry-run (default): shows what WOULD change
#   ./install.sh --apply    # actually copy files; existing ones are backed up
#
# Each file is copied to the SAME relative path under $HOME (e.g.
# macos/.config/starship.toml -> ~/.config/starship.toml). Before overwriting,
# the current file is saved to <file>.bak-<timestamp>. Secrets are NOT handled
# here — see README.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPLY=0
case "${1:-}" in
  --apply)        APPLY=1 ;;
  ""|--dry-run)   APPLY=0 ;;
  *) echo "usage: $0 [--apply|--dry-run]" >&2; exit 2 ;;
esac

FILES=(
  ".zshrc"
  ".zprofile"
  ".gitconfig"
  ".claude/CLAUDE.md"
  ".config/starship.toml"
  ".config/catppuccin_macchiato-zsh-syntax-highlighting.zsh"
  ".config/ghostty/config"
  ".config/ghostty/shaders/cursor_blaze.glsl"
  ".config/fastfetch/config.jsonc"
  ".config/fastfetch/apple-catppuccin.png"
  ".config/ripgrep/config"
)

ts="$(date +%Y%m%d-%H%M%S)"
for rel in "${FILES[@]}"; do
  src="$HERE/$rel"
  dst="$HOME/$rel"
  [ -f "$src" ] || { echo "skip (missing in repo): $rel"; continue; }
  if [ "$APPLY" -eq 1 ]; then
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ]; then
      cp -p "$dst" "$dst.bak-$ts"
      echo "backed up  ~/$rel -> ~/$rel.bak-$ts"
    fi
    cp "$src" "$dst"
    echo "installed  ~/$rel"
  else
    if [ -e "$dst" ]; then
      echo "[dry-run] would OVERWRITE (after backup):  ~/$rel"
    else
      echo "[dry-run] would create:                    ~/$rel"
    fi
  fi
done

echo
if [ "$APPLY" -eq 0 ]; then
  echo "Dry-run only — nothing changed. Re-run with --apply to install."
else
  echo "Done. Open a new shell (or 'exec zsh') to load the changes."
fi
echo "Reminder: run setup_mac_dev_tools.sh for brew packages, and see README.md for secrets."
