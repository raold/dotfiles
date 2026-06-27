# Server dotfiles profile — headless Linux (gmk)

The repo root is desktop/laptop-oriented (Hyprland/sway/i3/refind). This
`server/` profile is the subset that makes sense on a **headless production
host** — the Sibyl NucBox (`gmk`, Debian 13). It brings the SSH/ops shell up
to the Mac's modern-CLI baseline **without** any of the WM/desktop configs.

> **Do NOT run the root `sync-*.sh` / WM scripts on a server.** They install
> Hyprland/sway/i3/refind config irrelevant to a headless box. Use only
> `server/install.sh`.

## What it installs

| Source | Goes to | Notes |
|---|---|---|
| apt batch | system | `btop lazygit ncdu duf procs sd gum neovim tealdeer tokei direnv shellcheck shfmt hyperfine glances vivid pipx fd-find ripgrep bat` |
| prebuilt binaries | `~/.local/bin` | `dust difft zellij lazydocker yq(mikefarah) mise` — no apt candidate, no rust toolchain needed |
| `sibyl-server-shell.zsh` | `~/.config/` | additive aliases (`lg`, `lzd`), Debian `bat`/`fd` aliases, `direnv` hook, cached Catppuccin `LS_COLORS` |
| one `source` line | `~/.zshrc` | the only edit to your hand-maintained rc (backed up first) |
| `PATH` export | `~/.zshenv` | puts `~/.local/bin` on non-login SSH shells so bare `claude`/`just`/`mise`/`yq` resolve |

**Deliberately excluded:** `just` and `uv` (apt's are older than the
self-managed `~/.local/bin` copies); Debian's `yq` (it's the python jq-wrapper,
syntax-incompatible with the Mac's mikefarah Go `yq`, which is fetched as a
binary instead).

## Safety

Everything is **additive and reversible**, designed to run on a live box:

- It **never overwrites** `~/.zshrc` — it drops a snippet and adds one
  idempotent `source` line (and backs the rc up first).
- It touches **no systemd unit, service, or prod state**.
- It keeps the existing prompt (**starship**) and history (**atuin**) — it does
  **not** pull the root `.p10k.zsh`.
- Re-runnable; skips anything already installed.

## Usage (on gmk)

```sh
cd ~/dotfiles            # the raold/dotfiles clone on the box
git pull
./server/install.sh          # dry-run (default): shows what WOULD change
./server/install.sh --apply  # install
exec zsh                     # pick up the new aliases/hooks
```

## Revert

```sh
# remove the source line from ~/.zshrc, then:
rm ~/.config/sibyl-server-shell.zsh
# drop any binaries you don't want: rm ~/.local/bin/{dust,difft,zellij,lazydocker,yq,mise}
# apt remove <pkg> for any apt tool you don't want
```
