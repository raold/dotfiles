# Keep PATH entries unique — collapses the duplicate appends that accumulate
# across this file, ~/.zprofile, and tool installers (pyenv, pipx, LM Studio…).
typeset -U path PATH

# ── tiny eval-cache: memoize a slow `<tool> init` to a file and re-source it,
#    regenerating only when the tool binary is newer than the cache. Saves one
#    subprocess per shell start (pyenv ~30ms, starship ~3ms). Added 2026-06-26.
_cache_eval() {
  local key="${(j:_:)@//[^A-Za-z0-9]/_}"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/${key}.zsh"
  local bin=${commands[$1]}
  if [[ ! -s $cache || ( -n $bin && $bin -nt $cache ) ]]; then
    mkdir -p ${cache:h}; "$@" >| $cache 2>/dev/null
  fi
  source $cache
}

# Python aliases
alias python='python3'      # Map python to python3
alias pip='python -m pip'   # Always use pip for the active Python

# Add Python user bin to PATH
# export PATH="$HOME/Library/Python/3.9/bin:$PATH"

### ─── Python setup (Homebrew + pyenv + pipx) ────────────────────────────
# 1. Use pyenv to allow multiple Python versions side-by-side.
# 2. pipx isolates global CLI tools from project deps.
# 3. Helper 'workon' quickly (de)activates per-project virtualenvs.
# ------------------------------------------------------------------------

# pyenv — interactive shell init (shell function, completions, shims, rehash).
# The login-shell PATH half (`pyenv init --path`) now lives in ~/.zprofile.
_cache_eval pyenv init - zsh

export PATH="$HOME/.local/bin:$PATH"    # pipx shim directory

# Enhanced workon function: Creates/activates .venv in target directory (default: current)
workon() {
    local target=${1:-.}
    if [[ ! -d "$target/.venv" ]]; then
        echo "Creating virtual environment in $target/.venv..."
        python -m venv "$target/.venv"
    fi
    
    # Handle both Unix-style (bin) and Windows-style (Scripts) structures
    if [[ -f "$target/.venv/bin/activate" ]]; then
        source "$target/.venv/bin/activate"
    elif [[ -f "$target/.venv/Scripts/activate" ]]; then
        source "$target/.venv/Scripts/activate"
    else
        echo "Error: Could not find activate script in $target/.venv/"
        return 1
    fi
    
    echo "Activated: $(python --version) in $VIRTUAL_ENV"
}

# Companion function to deactivate virtual environment
alias workoff='deactivate 2>/dev/null || echo "No virtual environment active"'

# Auto-activate the nearest .venv on directory change, and auto-deactivate when
# you leave its tree. Uses a `chpwd` hook instead of overriding the `cd` builtin,
# so it composes with the `z` plugin and anything else that hooks cd. It is
# idempotent (won't re-activate an already-active venv) and only deactivates a
# venv IT activated — a manual `workon`/`source .venv/bin/activate` is left alone.
autoload -Uz add-zsh-hook
_auto_venv() {
    # Walk up from $PWD to find the nearest .venv/bin/activate.
    local dir="$PWD" found=""
    while [[ -n "$dir" ]]; do
        if [[ -f "$dir/.venv/bin/activate" ]]; then found="$dir/.venv"; break; fi
        [[ "$dir" == "/" ]] && break
        dir="${dir:h}"
    done
    if [[ -n "$found" ]]; then
        if [[ "$VIRTUAL_ENV" != "$found" ]]; then
            source "$found/bin/activate"
            _AUTO_VENV="$found"
            print -r -- "🐍 $(python --version 2>&1) — ${found:h:t}"
        fi
    elif [[ -n "${_AUTO_VENV:-}" && "$VIRTUAL_ENV" == "$_AUTO_VENV" ]]; then
        deactivate 2>/dev/null
        unset _AUTO_VENV
    fi
}
add-zsh-hook chpwd _auto_venv
_auto_venv   # run once for the shell's starting directory

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# DISABLED 2026-06-26 — replaced by fzf-tab (Tab → fzf picker with previews),
# which conflicts with zsh-autocomplete (both hijack Tab). To switch back:
# uncomment this line AND remove the fzf-tab block further down (and ideally the
# transient-prompt block at the very end, which zsh-autocomplete clashes with).
# source $HOMEBREW_PREFIX/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
# NOTE: zsh-autosuggestions and zsh-syntax-highlighting are sourced at the END of
# this file — they must load after oh-my-zsh, Starship, and every alias/function/
# widget defined below, or they won't wrap them correctly (per their READMEs).

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git
  bundler
  dotenv
  iterm2
  npm
)

# Docker CLI completions — added to fpath BEFORE oh-my-zsh runs compinit, so the
# single compinit below picks them up (avoids a second, redundant compinit later).
fpath=($HOME/.docker/completions $fpath)

# Speed: skip the compaudit fpath security scan (safe on a single-user Mac) and
# keep the completion dump in ~/.cache (one file, not scattered across $HOME).
export ZSH_DISABLE_COMPFIX=true
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${HOST}-${ZSH_VERSION}"
source $ZSH/oh-my-zsh.sh

# Bigger, de-duped history (atuin owns Ctrl-R; this still feeds autosuggestions).
HISTSIZE=200000
SAVEHIST=200000
setopt hist_reduce_blanks hist_save_no_dups hist_find_no_dups inc_append_history

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

_cache_eval starship init zsh

# Catppuccin Mocha — fzf colors + layout (matches the dark Ghostty theme)
export FZF_DEFAULT_OPTS="
  --layout=reverse --border=rounded --height=60% --margin=1 --padding=1
  --info=inline-right --prompt='  ' --pointer='▶' --marker='✓'
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
  --color=selected-bg:#45475a,border:#6c7086,label:#cdd6f4
  --bind='ctrl-/:toggle-preview'"
# Previews only on the file/dir pickers (keeps Ctrl-R and other pickers clean):
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}' --preview-window='right:60%:border-left'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {}' --preview-window='right:60%:border-left'"
# Activate fzf's zsh keybindings: Ctrl-T (files), Alt-C (cd). It also binds
# Ctrl-R, but atuin below is sourced last and reclaims Ctrl-R.
_cache_eval fzf --zsh

# ── completion styling + fzf-tab (Tab → fzf picker with previews) ───────────
# Replaces zsh-autocomplete's live menu. Tab now opens an fzf chooser with
# eza/bat previews and inherits the Catppuccin Mocha FZF_DEFAULT_OPTS.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
# Catppuccin Mocha LS_COLORS via vivid (truecolor) — themes `ls`, the eza
# fallback, and the fzf-tab/completion menu (consumed by list-colors below).
# Falls back to gdircolors' generic ANSI palette if vivid isn't installed.
if command -v vivid >/dev/null; then
  export LS_COLORS="$(vivid generate catppuccin-mocha)"
elif command -v gdircolors >/dev/null; then
  eval "$(gdircolors -b)"
fi
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no                          # required: let fzf-tab own the menu
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'       # group headers fzf-tab can switch on
zstyle ':fzf-tab:*' use-fzf-default-opts yes            # inherit your Mocha fzf colors
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-flags --height=60% --border=rounded
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=always $realpath'
zstyle ':fzf-tab:complete:*:*' fzf-preview \
  '[[ -d $realpath ]] && eza -1 --color=always --icons=always $realpath || bat -n --color=always --line-range :200 $realpath 2>/dev/null || cat $realpath 2>/dev/null'
source $HOMEBREW_PREFIX/share/fzf-tab/fzf-tab.zsh

# Catppuccin Mocha — eza theme + aliases (eza wasn't aliased to ls before)
export EZA_CONFIG_DIR="$HOME/.config/eza"
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --git --group-directories-first'
alias la='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons --group-directories-first'

# ripgrep — Catppuccin Mocha match colors live in ~/.config/ripgrep/config
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

# zellij — persistent terminal sessions (survive a window close / restart).
# `zj` attaches to (or creates) a session named "main". NOT auto-started — run
# it when you want persistence; otherwise use Ghostty's native splits.
alias zj='zellij attach --create main'

# zoxide — smarter `cd` (z / zi). Replaces the oh-my-zsh `z` plugin (removed above).
_cache_eval zoxide init zsh
# atuin — fuzzy, full-text shell history on Ctrl-R (was installed but never wired).
# --disable-up-arrow keeps ↑ on zsh / zsh-autocomplete history; atuin owns Ctrl-R.
_cache_eval atuin init zsh --disable-up-arrow


# (pipx appended a duplicate ~/.local/bin here; removed — line ~5 of this file
#  already prepends it, and `typeset -U path` keeps PATH unique.)

# Secrets are encrypted at rest in ~/.config/zsh/secrets.zsh.age, sealed to BOTH
# the Apple Secure Enclave (silent, machine-bound — can't be copied off this Mac
# or read from a Time Machine backup) AND ~/.age/key.txt (portable break-glass
# recovery). They're decrypted into the environment on login; the plaintext only
# ever lives in a shell variable (no temp file). Guarded so a missing
# age/plugin/key never breaks the shell. To edit secrets: `editsecrets` (below).
_load_secrets() {
    local enc="$HOME/.config/zsh/secrets.zsh.age" id="$HOME/.age/se-key.txt"
    [[ -r "$enc" && -r "$id" ]] || return 0
    local plain
    plain="$(age -d -i "$id" "$enc" 2>/dev/null)" \
        || { print -r -- "⚠️  secrets: could not decrypt $enc" >&2; return 1; }
    eval "$plain"
}
_load_secrets

# Edit the encrypted secrets: decrypt → $EDITOR → re-encrypt to every recipient
# in ~/.age/secrets.recipients (Secure Enclave + portable). Plaintext lives only
# in a 600 temp during the edit and is overwritten (`rm -P`) afterward.
editsecrets() {
    local enc="$HOME/.config/zsh/secrets.zsh.age" id="$HOME/.age/se-key.txt"
    local recips="$HOME/.age/secrets.recipients" tmp
    [[ -r "$recips" ]] || { print -r -- "editsecrets: missing $recips" >&2; return 1; }
    tmp="$(mktemp "${TMPDIR:-/tmp}/secrets.XXXXXX.zsh")" || return 1
    chmod 600 "$tmp"
    [[ -r "$enc" ]] && { age -d -i "$id" "$enc" > "$tmp" || { command rm -f "$tmp"; return 1; }; }
    "${EDITOR:-vi}" "$tmp"
    if age -R "$recips" -o "$enc" "$tmp"; then
        chmod 600 "$enc"
        print -r -- "🔒 re-encrypted → $enc"
        print -r -- "↻ run 'source ~/.zshrc' (or open a new shell) to load changes"
    else
        print -r -- "editsecrets: re-encryption failed — $enc left unchanged" >&2
    fi
    command rm -P "$tmp" 2>/dev/null || command rm -f "$tmp"
}
export PATH="$HOME/bin:$PATH"

# Cipher Configuration (non-secret — the OpenAI key it uses comes from secrets.zsh)
export CIPHER_CONFIG_PATH="$HOME/.cipher/config.yaml"
export CIPHER_LOG_LEVEL="info"


# Odds API key now lives in ~/.config/zsh/secrets.zsh (it was a literal {{…}}
# template placeholder here, so the braces became part of the value in zsh).

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/dro/.lmstudio/bin"
# End of LM Studio CLI section

# MLX-LM: local model paths (shared with LM Studio)
export LMS_MODELS="$HOME/.lmstudio/models"
export QWEN_THINK="$LMS_MODELS/lmstudio-community/Qwen3-30B-A3B-Thinking-2507-MLX-4bit"


test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
# iTerm2 utilities (imgcat, it2dl, it2check, …) live here as executable scripts;
# adding the dir to PATH makes them work in scripts/non-interactive shells, not just
# via the interactive aliases. `typeset -U path` (top of file) keeps PATH de-duped.
[ -d "${HOME}/.iterm2" ] && export PATH="${HOME}/.iterm2:$PATH"

# Docker CLI completions are now wired into fpath ABOVE (before oh-my-zsh's
# compinit), so Docker Desktop's separate autoload/compinit has been removed
# here to avoid running compinit twice.


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r '/Users/dro/.opam/opam-init/init.zsh' ]] || source '/Users/dro/.opam/opam-init/init.zsh' > /dev/null 2> /dev/null
# END opam configuration

# Raise file descriptor limit for Sibyl (many concurrent httpx/websocket clients)
ulimit -n 65536 2>/dev/null || true   # quiet-fail if it ever exceeds the hard limit

# claude — wrap the Claude Code CLI so every session starts in ultracode mode.
#
# Ultracode (xhigh reasoning + auto-workflow orchestration) has no persistent
# settings.json key — it's session-only and resets each launch. The only way to
# make it the de-facto default is to inject the flag at launch time. This wrapper
# does that for BOTH bare `claude` AND every `claude` call inside `sibyl()` below
# (shell functions resolve `claude` at call time, so they hit this wrapper too).
# `command claude` calls the real binary, avoiding recursion. Escape hatch: run
# `command claude ...` directly, or `NO_ULTRACODE=1 claude ...`, for a plain session.
claude() {
    if [[ -n "${NO_ULTRACODE:-}" ]]; then
        command claude "$@"
    else
        command claude --settings '{"ultracode": true}' "$@"
    fi
}

# sibyl — launch a Claude Code session for the sibyl repo, ISOLATED BY DEFAULT.
#
# Parallel sessions that share the main checkout collide on git HEAD/index:
# one session's `git checkout` switches the branch for ALL of them. So the
# default here is one git worktree per session — never the shared main tree.
# Background: ~/rice/sibyl/docs/parallel-sessions.md
#
#   sibyl <tag> [base]   tracked work: new worktree ~/rice/sibyl-<tag> on branch
#                        claude/<tag>-<date> (off origin/main), seed its venv,
#                        then launch claude there.      e.g.  sibyl gepa
#   sibyl                throwaway: native `claude --worktree` (auto-named, under
#                        .claude/worktrees/, on branch worktree-<name>)
#   sibyl -m | --main    open the MAIN checkout (git mutations are DENIED there
#                        by the PreToolUse guard — inspection / planning only)
#   sibyl -h | --help    show this help
sibyl() {
    local repo="$HOME/rice/sibyl"
    case "${1:-}" in
        -h|--help)
            print -r -- "usage:"
            print -r -- "  sibyl <tag> [base]   isolated worktree session (tracked work)"
            print -r -- "  sibyl                throwaway native --worktree session"
            print -r -- "  sibyl -m|--main      read-only MAIN checkout (no git mutations)"
            return 0
            ;;
        -m|--main)
            shift
            cd "$repo" || return
            claude "$@"
            ;;
        ""|-q|--quick)
            [[ "${1:-}" == -q || "${1:-}" == --quick ]] && shift
            cd "$repo" || return
            claude --worktree "$@"
            ;;
        -*)
            # any other bare flag → treat as a quick worktree session
            cd "$repo" || return
            claude --worktree "$@"
            ;;
        *)
            local tag="$1"; shift
            local base="${1:-origin/main}"
            [[ -n "${1:-}" ]] && shift
            local wt="${repo}-${tag}"
            (
                cd "$repo" || exit 1
                git fetch -q origin 2>/dev/null || true
                scripts/new-claude-session.sh "$tag" "$base"
            ) || return
            unset VIRTUAL_ENV
            cd "$wt" || return
            uv sync --extra dev >/dev/null 2>&1 || true
            claude "$@"
            ;;
    esac
}

# OpenClaw — admin device token for the gmk gateway (reached via the SSH
# tunnel managed by ~/Library/LaunchAgents/com.dro.openclaw-tunnel.plist).
# Lets `openclaw dashboard`, `openclaw agent`, etc. include the token in
# the Control UI URL fragment without having to pass --token every call.
# (OPENCLAW_GATEWAY_TOKEN now lives in ~/.config/zsh/secrets.zsh.)

# YubiKey / GnuPG agent for SSH
export GPG_TTY="${TTY:-$(tty)}"
unset SSH_AGENT_PID
# 2026-05-21: prefer Secretive's SSH agent (Touch ID via Secure Enclave)
# when its socket is present. Falls back to gpg-agent (Yubikey-as-SSH-key
# emulation) when Secretive isn't running — keeps the Yubikey usable for
# travel / recovery without further config changes.
_SECRETIVE_SOCK="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
if [ -S "$_SECRETIVE_SOCK" ]; then
    export SSH_AUTH_SOCK="$_SECRETIVE_SOCK"
elif [ -z "$SSH_AUTH_SOCK" ] || [ "$SSH_AUTH_SOCK" != "$(gpgconf --list-dirs agent-ssh-socket)" ]; then
    export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi
unset _SECRETIVE_SOCK
gpgconf --launch gpg-agent 2>/dev/null

# Agent switchers — for the rare case you need to use a different signing
# identity in the current shell (e.g. Bitwarden's portable key when
# pairing on a borrowed machine, or Yubikey for recovery). Each function
# only affects the current shell; new shells fall back to the
# Secretive-prefers-fallback-to-gpg logic above.
git-use-secretive() {
    local sock="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
    [ -S "$sock" ] || { echo "Secretive socket not present — is the app running?" >&2; return 1; }
    export SSH_AUTH_SOCK="$sock"
    echo "→ Secretive (Touch ID, Mac-only)"
}
git-use-bitwarden() {
    local sock="$HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock"
    [ -S "$sock" ] || { echo "Bitwarden socket not present — is the desktop app running + SSH agent enabled?" >&2; return 1; }
    export SSH_AUTH_SOCK="$sock"
    echo "→ Bitwarden (vault-bound, portable)"
}
git-use-yubikey() {
    local sock; sock="$(gpgconf --list-dirs agent-ssh-socket 2>/dev/null)"
    [ -n "$sock" ] || { echo "gpgconf not available" >&2; return 1; }
    export SSH_AUTH_SOCK="$sock"
    gpgconf --launch gpg-agent 2>/dev/null
    echo "→ gpg-agent (Yubikey PIN + touch)"
}

# ───────────────────────── age encrypt/decrypt helpers (added by Claude Code, 2026-06-20) ─────────────────────────
# Recipient-based (asymmetric) encryption with `age`. AGE_RECIPIENT is the
# PUBLIC key; anything sealed to it can only be opened by the matching PRIVATE
# key in AGE_IDENTITY. Encrypting needs no secret, so it's safe to run anywhere.
# Verify the pair any time with:  age-keygen -y "$AGE_IDENTITY"
export AGE_RECIPIENT="age1u8ycayx2rzcxfsuesukfhj99efk45qjteu4hmn78g37mdamdxffq86kj9x"
export AGE_IDENTITY="$HOME/.age/key.txt"

# Bundle files/dirs into ONE compressed, encrypted archive.
#   encrypt EP_archive EP*          ->  EP_archive.tar.gz.age
#   encrypt taxes ~/Documents/2025  ->  taxes.tar.gz.age
encrypt() {
    if (( $# < 2 )); then
        print -r -- "usage: encrypt <archive-name> <file/dir/glob>..." >&2
        return 2
    fi
    local out="$1"; shift
    # `-f -` streams the tarball to stdout so nothing hits disk unencrypted;
    # `--` stops a file named like `-foo` from being read as a tar option.
    tar -czf - -- "$@" | age -r "$AGE_RECIPIENT" -o "${out}.tar.gz.age" \
        && print -r -- "🔒 ${out}.tar.gz.age"
}

# Shared, safe extractor — used by both decrypt (key) and pdecrypt (passphrase).
#
# THE FOOTGUN: `tar -x` unpacks into whatever directory you're standing in and
# OVERWRITES same-named files there without asking. Run a decrypt in the wrong
# folder and you can silently clobber real work. So we never extract into $PWD —
# we make a fresh subdir named after the archive (option a). A re-run can never
# overwrite your cwd; worst case you get EP_archive/, then EP_archive-1/, -2/, …
# usage: _age_unpack <archive> [extra age -d args...]
_age_unpack() {
    setopt localoptions pipefail        # so age failing isn't masked by tar (last in pipe)
    local archive="$1"; shift
    local base="${archive:t}"           # basename, drop any leading path
    base="${base%.tar.gz.age}"; base="${base%.age}"   # strip our suffix
    local dest="$base" n=1
    while [[ -e "$dest" ]]; do dest="${base}-${n}"; (( n++ )); done
    mkdir -p -- "$dest"
    if age -d "$@" "$archive" | tar -xzvf - -C "$dest"; then
        print -r -- "🔓 extracted to ./$dest/"
    else
        rmdir -- "$dest" 2>/dev/null    # don't leave an empty dir behind on failure
        print -r -- "✗ decrypt/extract failed for: $archive" >&2
        return 1
    fi
}

# Decrypt + extract a key-encrypted archive made by `encrypt`.
#   decrypt EP_archive.tar.gz.age   ->  ./EP_archive/
decrypt() {
    (( $# >= 1 )) || { print -r -- "usage: decrypt <archive.tar.gz.age>" >&2; return 2; }
    _age_unpack "$1" -i "$AGE_IDENTITY"
}

# Peek inside a key-encrypted archive WITHOUT extracting (list contents only).
#   agels EP_archive.tar.gz.age
agels() { age -d -i "$AGE_IDENTITY" "$1" | tar -tzvf -; }

# Single file, no tar wrapper — when an archive is overkill.
#   enc secret.pdf       ->  secret.pdf.age
#   dec secret.pdf.age   ->  secret.pdf   (in place; original .age is kept)
enc() { age -r "$AGE_RECIPIENT" -o "$1.age" "$1"   && print -r -- "🔒 $1.age"; }
dec() { age -d -i "$AGE_IDENTITY" -o "${1%.age}" "$1" && print -r -- "🔓 ${1%.age}"; }

# Passphrase mode — for sharing with someone who has no key; they just need the
# password. NOTE: passphrase archives are opened with NO `-i` (age refuses to
# mix a passphrase with an identity), so use `pdecrypt`, not `decrypt`.
#   pencrypt sharepack file1 dir2   ->  sharepack.tar.gz.age   (prompts for a passphrase)
#   pdecrypt sharepack.tar.gz.age   ->  ./sharepack/           (prompts for the passphrase)
pencrypt() {
    (( $# >= 2 )) || { print -r -- "usage: pencrypt <archive-name> <file/dir>..." >&2; return 2; }
    local out="$1"; shift
    tar -czf - -- "$@" | age -p -o "${out}.tar.gz.age" \
        && print -r -- "🔒 ${out}.tar.gz.age (passphrase)"
}
pdecrypt() {
    (( $# >= 1 )) || { print -r -- "usage: pdecrypt <archive.tar.gz.age>" >&2; return 2; }
    _age_unpack "$1"
}

# ───────────────────────── interactive UX plugins (sourced LAST) ─────────────────────────
# These must load after oh-my-zsh, Starship, and every alias/function/widget
# defined above, per their upstream READMEs. (zsh-autocomplete stays near the top.)
# zsh-autosuggestions (gray ghost-text from history) — KEPT; perf + dark-bg tweaks.
ZSH_AUTOSUGGEST_USE_ASYNC=1
# (ZSH_AUTOSUGGEST_MANUAL_REBIND removed 2026-06-26 — it broke bracketed paste,
#  i.e. drag-drop / paste of file paths into the terminal.)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'   # Mocha overlay0 — dim but legible
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# fast-syntax-highlighting (replaces zsh-syntax-highlighting) — faster + more
# accurate. MUST be sourced last among ZLE plugins. Themed Catppuccin Mocha via
# `fast-theme XDG:catppuccin-mocha` (persists in ~/.config/fsh/). The old
# macchiato zsh-syntax-highlighting theme is retired.
source $HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

# ── fastfetch greeter — runs once, ONLY in a real top-level human terminal ──
# Guards: interactive shell? not an agent/CI? not an IDE terminal? top-level
# (not nested/tmux)? stdout a real TTY? Otherwise stay silent (so it never
# spews into the Claude Code Bash tool, scripts, pipes, or subshells).
_ff_greet() {
  case $- in *i*) : ;; *) return ;; esac
  [[ -n $CLAUDECODE || -n $CLAUDE_CODE_ENTRYPOINT || -n $AI_AGENT || -n $CI ]] && return
  [[ $TERM_PROGRAM == vscode || -n $VSCODE_INJECTION || -n $NVIM || -n $INSIDE_EMACS ]] && return
  (( ${SHLVL:-1} > 1 )) && return
  [[ -t 1 ]] || return
  command -v fastfetch >/dev/null 2>&1 && fastfetch
}
_ff_greet
unfunction _ff_greet

# ── Starship transient prompt for zsh — ENABLED 2026-06-26 ──────────────────
# Collapses each finished prompt to a tiny green ❯, keeping long scrollback
# clean. Safe now that zsh-autocomplete is gone (it was the main conflictor).
# If Enter ever stops accepting commands, comment out this whole block — open a
# FRESH shell to test; your current shell keeps working until you do.
zle-line-init() {
  emulate -L zsh
  [[ $CONTEXT == start ]] || return 0
  while true; do
    zle .recursive-edit; local -i ret=$?
    [[ $ret == 0 && $KEYS == $'\4' ]] || break
    [[ -o ignore_eof ]] || exit 0
  done
  local save=$PROMPT; PROMPT='%F{#a6e3a1}❯%f '
  zle .reset-prompt; PROMPT=$save
  if (( ret )); then zle .send-break; else zle .accept-line; fi
  return ret
}
zle -N zle-line-init
