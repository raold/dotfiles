# Global Claude Code Configuration

**Last Updated:** 2026-06-20 | **Machine:** Mac M4 (Apple Silicon)

## How I want you to work
- Prefer git/GitHub for change tracking; branch before non-trivial work, keep commits/PRs reviewable.
- Use subagents / parallel agents for complex multi-step or independent tasks.
- Check today's date before choosing date ranges.
- Keep CLAUDE.md files current; flag drift when you spot it.

## Secrets & safety
- Never hardcode or echo API keys/tokens. Shell secrets are age-encrypted at
  `~/.config/zsh/secrets.zsh.age` (Secure Enclave + portable `~/.age/key.txt`),
  loaded into the env on login; edit them with `editsecrets`.
- DB credentials live in `~/.claude/settings.local.json` (machine-only).
- `raold/dotfiles` is a PUBLIC repo — never commit secrets, `~/.age/*key*`, or `secrets.zsh*`.

## Environment (Mac M4)
- Modern CLI installed — prefer: `rg` (grep), `fd` (find), `bat` (cat), `eza` (ls), `jq`, `fzf`.
- GNU coreutils are g-prefixed (`gsed`, `ggrep`, `gawk`); bare `sed`/`grep` are BSD — use g-versions when you need GNU behavior.
- Python: pyenv + uv + pipx; per-project `.venv` auto-activates on `cd` (chpwd hook in `.zshrc`).
- One-shot setup: `~/setup_mac_dev_tools.sh`.

## Config files
| File | Purpose |
|------|---------|
| `~/.claude/settings.json` | Global settings, command allowlist, plugins |
| `~/.claude/settings.local.json` | Machine-only overrides (DB creds) |
| `~/.claude/CLAUDE.md` | This file |

## Active projects
- **sibyl** (`~/rice/sibyl`) — primary. Parallel work uses git worktrees (`sibyl <tag>` helper);
  git mutations are DENIED on the main checkout (inspection/planning only there).
- **NFL Analytics** (`~/rice/nfl-analytics`) — has its own project-level CLAUDE.md.
- **gamble-bot** (`~/rice/gamble-bot`).
