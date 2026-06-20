# macOS dotfiles — Apple Silicon (M4)

Shell + tooling config for my Mac. Linux configs live at the repo root; everything
macOS-specific is here under `macos/`.

> ### 🔐 Secrets are NOT in this repo
> API keys/tokens are encrypted at rest with [`age`](https://age-encryption.org)
> + the Apple **Secure Enclave** (`age-plugin-se`) at `~/.config/zsh/secrets.zsh.age`,
> and loaded into the shell on login. `settings.json` / `settings.local.json` and
> the age private keys (`~/.age/*key*`) are git-ignored and never committed.

## What's here

| File (under `macos/`) | Installs to | What it is |
|---|---|---|
| `.zshrc` | `~/.zshrc` | zsh: oh-my-zsh + Starship, age/Secure-Enclave secret loading, pyenv/uv/pipx, auto-venv `chpwd` hook, `encrypt`/`decrypt`/`editsecrets` helpers |
| `.zprofile` | `~/.zprofile` | login-shell PATH: Homebrew, `pyenv --path`, OrbStack |
| `.gitconfig` | `~/.gitconfig` | git identity + Secretive SSH commit signing |
| `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | global Claude Code instructions |
| `.config/starship.toml` | `~/.config/starship.toml` | Starship prompt |
| `.config/catppuccin_macchiato-zsh-syntax-highlighting.zsh` | `~/.config/…` | Catppuccin theme for zsh-syntax-highlighting |
| `setup_mac_dev_tools.sh` | run once | brew install of GNU utils + modern CLI + dev tools |

## Restore on a fresh Mac

```sh
# 1. prerequisites
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git clone https://github.com/raold/dotfiles.git && cd dotfiles

# 2. dev tools + shell deps
sh macos/setup_mac_dev_tools.sh
brew install starship age age-plugin-se pyenv \
  zsh-autosuggestions zsh-syntax-highlighting zsh-autocomplete
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# 3. drop the dotfiles into place — DRY-RUN FIRST
./macos/install.sh            # preview (dry-run by default)
./macos/install.sh --apply    # write (backs up any existing file)

# 4. re-create secrets (NOT in this repo)
mkdir -p ~/.age ~/.config/zsh
#  - restore ~/.age/key.txt (portable age key) from your OFFLINE backup
#  - regenerate the Secure-Enclave key on this Mac:
#      age-plugin-se keygen --access-control=none -o ~/.age/se-key.txt
#  - then:  editsecrets   (paste your API keys; re-encrypts to both keys)
```

## Notes
- **Secret recovery needs `~/.age/key.txt`** (the portable key) — keep it backed up
  offline. The Secure-Enclave key (`se-key.txt`) is bound to the original Mac and
  cannot be moved; on a new Mac you generate a fresh one and re-encrypt.
- Commit signing uses Secretive (Secure Enclave); on a new machine you'll point
  `.gitconfig`'s `user.signingkey` at that machine's key.
