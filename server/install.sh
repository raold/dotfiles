#!/usr/bin/env bash
# Sibyl SERVER dotfiles profile — for headless Linux hosts (e.g. gmk, the
# Sibyl production NucBox running Debian 13).
#
# Brings a server's SSH/ops experience up to the Mac's modern-CLI baseline
# WITHOUT the desktop/WM configs at the repo root (Hyprland/sway/i3/refind).
# Everything here is ADDITIVE and REVERSIBLE:
#   - apt packages install cleanly and `apt remove` reverts them
#   - prebuilt binaries land in ~/.local/bin (rm reverts; no rust/cargo needed)
#   - it NEVER overwrites a hand-maintained ~/.zshrc — it drops a snippet at
#     ~/.config/sibyl-server-shell.zsh and adds ONE idempotent `source` line
#   - it NEVER touches a systemd unit, service, or anything prod-stateful
#
# Usage:
#   ./server/install.sh            # dry-run (default): prints what WOULD change
#   ./server/install.sh --apply    # actually install
#   ./server/install.sh --apply --force-binaries   # re-fetch binaries already on PATH
#
# Re-runnable (idempotent). Safe to run on a live box.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPLY=0
FORCE_BIN=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --force-binaries) FORCE_BIN=1 ;;
    --dry-run) APPLY=0 ;;
    *) echo "usage: $0 [--apply] [--force-binaries]" >&2; exit 2 ;;
  esac
done

say()  { printf '  %s\n' "$*"; }
step() { printf '\n=== %s ===\n' "$*"; }
run()  { if [ "$APPLY" -eq 1 ]; then "$@"; else printf '  [dry-run] %s\n' "$*"; fi; }

ARCH="$(uname -m)"   # gmk is x86_64; arch-detect so this is portable
BIN_DIR="$HOME/.local/bin"

# ── 1. apt-installable tools (Debian 13 packages nearly the whole Mac set) ───
# Deliberately EXCLUDED:
#   just, uv  — apt's are older than the self-managed ~/.local/bin copies
#   yq        — Debian's `yq` is the python jq-wrapper, NOT mikefarah's Go yq
#               (syntax-incompatible). The Go yq is fetched as a binary below.
APT_PKGS=(
  btop lazygit ncdu duf procs sd gum neovim tealdeer tokei
  direnv shellcheck shfmt hyperfine glances vivid pipx fd-find ripgrep bat
)

step "apt packages"
if command -v apt-get >/dev/null 2>&1; then
  missing=()
  for p in "${APT_PKGS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    say "all present: ${APT_PKGS[*]}"
  else
    say "to install: ${missing[*]}"
    run sudo apt-get update -qq
    run sudo apt-get install -y "${missing[@]}"
  fi
else
  say "no apt-get here — skipping (this profile targets Debian/Ubuntu)"
fi

# ── 2. prebuilt binaries → ~/.local/bin (no apt candidate + no rust on the box) ─
# Each entry: "cmd|repo|asset-grep|kind". kind ∈ {targz, zip, raw}.
# raw = the asset IS the binary. targz/zip = extract and find the named cmd.
BINS=(
  "dust|bootandy/dust|x86_64-unknown-linux-gnu.tar.gz|targz"
  "difft|Wilfred/difftastic|x86_64-unknown-linux-gnu.tar.gz|targz"
  "zellij|zellij-org/zellij|x86_64-unknown-linux-musl.tar.gz|targz"
  "lazydocker|jesseduffield/lazydocker|Linux_x86_64.tar.gz|targz"
  "yq|mikefarah/yq|yq_linux_amd64$|raw"
)

fetch_latest_url() {  # $1=repo $2=asset-grep
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | sed -E 's/.*"(https[^"]+)"/\1/' \
    | grep -E "$2" | head -1
}

install_binary() {  # $1=cmd $2=repo $3=asset-grep $4=kind
  local cmd="$1" repo="$2" pat="$3" kind="$4" url tmp
  if [ "$ARCH" != "x86_64" ]; then say "skip $cmd (arch $ARCH != x86_64)"; return 0; fi
  if command -v "$cmd" >/dev/null 2>&1 && [ "$FORCE_BIN" -eq 0 ]; then
    say "$cmd already on PATH ($(command -v "$cmd")) — skip (use --force-binaries to refetch)"; return 0
  fi
  url="$(fetch_latest_url "$repo" "$pat" || true)"
  if [ -z "${url:-}" ]; then say "$cmd: no matching release asset for /$pat/ — skip"; return 0; fi
  say "$cmd <- $url"
  [ "$APPLY" -eq 1 ] || { say "  [dry-run] would install to $BIN_DIR/$cmd"; return 0; }
  mkdir -p "$BIN_DIR"
  tmp="$(mktemp -d)"
  case "$kind" in
    raw)   curl -fsSL "$url" -o "$BIN_DIR/$cmd"; chmod +x "$BIN_DIR/$cmd" ;;
    targz) curl -fsSL "$url" | tar -xz -C "$tmp"
           install -m755 "$(find "$tmp" -type f -name "$cmd" | head -1)" "$BIN_DIR/$cmd" ;;
    zip)   curl -fsSL "$url" -o "$tmp/a.zip"; unzip -qo "$tmp/a.zip" -d "$tmp"
           install -m755 "$(find "$tmp" -type f -name "$cmd" | head -1)" "$BIN_DIR/$cmd" ;;
  esac
  rm -rf "$tmp"
  say "  installed $BIN_DIR/$cmd"
}

step "prebuilt binaries -> $BIN_DIR"
for spec in "${BINS[@]}"; do
  IFS='|' read -r c r p k <<<"$spec"
  install_binary "$c" "$r" "$p" "$k"
done
# mise has a first-party installer that targets ~/.local/bin
if command -v mise >/dev/null 2>&1 && [ "$FORCE_BIN" -eq 0 ]; then
  say "mise already on PATH — skip"
else
  say "mise <- https://mise.run"
  run sh -c 'curl -fsSL https://mise.run | sh'
fi

# ── 3. additive shell wiring (NEVER rewrite ~/.zshrc) ───────────────────────
step "shell wiring (additive)"
SNIPPET_SRC="$HERE/sibyl-server-shell.zsh"
SNIPPET_DST="$HOME/.config/sibyl-server-shell.zsh"
# shellcheck disable=SC2016  # $HOME must stay LITERAL — it is evaluated when ~/.zshrc loads, not now
SOURCE_LINE='[ -f "$HOME/.config/sibyl-server-shell.zsh" ] && source "$HOME/.config/sibyl-server-shell.zsh"'

say "snippet -> $SNIPPET_DST"
run mkdir -p "$HOME/.config"
run cp "$SNIPPET_SRC" "$SNIPPET_DST"

if grep -qF 'sibyl-server-shell.zsh' "$HOME/.zshrc" 2>/dev/null; then
  say ".zshrc already sources the snippet — no change"
else
  say "append source line to ~/.zshrc (backup first)"
  if [ "$APPLY" -eq 1 ]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
    printf '\n# Sibyl server profile (additive; see dotfiles/server/)\n%s\n' "$SOURCE_LINE" >> "$HOME/.zshrc"
  else
    say "  [dry-run] would append the source line"
  fi
fi

# Ensure ~/.local/bin is on PATH for NON-login ssh shells too (so bare `claude`,
# `just`, `mise`, `yq` resolve over `ssh host '<cmd>'`). .zshenv is sourced by
# non-interactive shells; daemons use absolute ExecStart paths so are unaffected.
if grep -qF 'sibyl-server-profile PATH' "$HOME/.zshenv" 2>/dev/null; then
  say ".zshenv PATH already wired — no change"
else
  say "prepend ~/.local/bin to PATH in ~/.zshenv"
  if [ "$APPLY" -eq 1 ]; then
    # shellcheck disable=SC2016  # $HOME/$PATH stay LITERAL — evaluated when ~/.zshenv loads
    printf '\n# sibyl-server-profile PATH (non-login ssh shells)\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshenv"
  else
    say "  [dry-run] would add the PATH export"
  fi
fi

step "done"
if [ "$APPLY" -eq 1 ]; then
  say "open a new shell (or 'source ~/.zshrc') to pick up aliases/hooks"
  say "reversible: remove the source line from ~/.zshrc, rm ~/.config/sibyl-server-shell.zsh,"
  say "            and 'apt remove' / 'rm ~/.local/bin/<tool>' as needed"
else
  printf '\nDry-run only — nothing changed. Re-run with --apply to install.\n'
fi
