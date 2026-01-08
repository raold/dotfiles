#!/bin/bash
# Sync wm-common/ shared configs
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

REPO_WM_COMMON="$DOTFILES_DIR/.config/wm-common"
SYS_WM_COMMON="$CONFIG_DIR/wm-common"

SHARED_FILES=(
    variables.conf
    colors.conf
    keybindings.conf
    workspaces.conf
    modes.conf
    window-rules.conf
)

collect() {
    log_info "Collecting wm-common/ from system to repo..."
    mkdir -p "$REPO_WM_COMMON"

    for file in "${SHARED_FILES[@]}"; do
        if [[ -f "$SYS_WM_COMMON/$file" ]]; then
            cp "$SYS_WM_COMMON/$file" "$REPO_WM_COMMON/$file"
            log_ok "Collected: wm-common/$file"
        else
            log_warn "Not found: wm-common/$file"
        fi
    done

    log_ok "Shared configs collected to repo"
}

install() {
    log_info "Installing wm-common/ from repo to system..."

    if [[ -d "$SYS_WM_COMMON" ]]; then
        backup_dir "$SYS_WM_COMMON"
    fi

    mkdir -p "$SYS_WM_COMMON"

    for file in "${SHARED_FILES[@]}"; do
        if [[ -f "$REPO_WM_COMMON/$file" ]]; then
            cp "$REPO_WM_COMMON/$file" "$SYS_WM_COMMON/$file"
            log_ok "Installed: wm-common/$file"
        else
            log_warn "Not in repo: wm-common/$file"
        fi
    done

    log_ok "Shared configs installed to system"

    # Prompt to regenerate Hyprland configs
    if [[ -d "$CONFIG_DIR/hypr" ]]; then
        log_info "Hyprland configs detected. Consider running:"
        echo "  $SCRIPT_DIR/translate-hyprland.sh"
    fi
}

validate() {
    log_info "Validating wm-common/ configs..."
    local errors=0

    for file in "${SHARED_FILES[@]}"; do
        if [[ ! -f "$SYS_WM_COMMON/$file" ]]; then
            log_error "Missing: wm-common/$file"
            ((errors++))
        else
            log_ok "Found: wm-common/$file"
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_ok "All wm-common/ files present"
        return 0
    else
        log_error "$errors files missing"
        return 1
    fi
}

case "$1" in
    --collect)  collect ;;
    --install)  install ;;
    --validate) validate ;;
    *)
        echo "Usage: $0 [--collect|--install|--validate]"
        exit 1
        ;;
esac
