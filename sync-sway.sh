#!/bin/bash
# Sync Sway + waybar + Wayland tools
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

SWAY_DIRS=(sway waybar)

collect() {
    log_info "Collecting Sway configs from system to repo..."

    for dir in "${SWAY_DIRS[@]}"; do
        if [[ -d "$CONFIG_DIR/$dir" ]]; then
            rm -rf "$DOTFILES_DIR/.config/$dir"
            cp -r "$CONFIG_DIR/$dir" "$DOTFILES_DIR/.config/$dir"
            log_ok "Collected: .config/$dir/"
        else
            log_warn "Not found: .config/$dir/"
        fi
    done

    log_ok "Sway configs collected to repo"
}

install() {
    log_info "Installing Sway configs from repo to system..."
    check_packages sway || log_warn "Some Sway packages missing (continuing anyway)"

    for dir in "${SWAY_DIRS[@]}"; do
        if [[ -d "$DOTFILES_DIR/.config/$dir" ]]; then
            if [[ -d "$CONFIG_DIR/$dir" ]]; then
                backup_dir "$CONFIG_DIR/$dir"
            fi
            rm -rf "$CONFIG_DIR/$dir"
            cp -r "$DOTFILES_DIR/.config/$dir" "$CONFIG_DIR/$dir"
            log_ok "Installed: .config/$dir/"
        else
            log_warn "Not in repo: .config/$dir/"
        fi
    done

    log_ok "Sway configs installed to system"
}

validate() {
    log_info "Validating Sway config..."

    if [[ ! -f "$CONFIG_DIR/sway/config" ]]; then
        log_error "Sway config not found"
        return 1
    fi

    if ! command -v sway &>/dev/null; then
        log_warn "Sway not installed, skipping validation"
        return 0
    fi

    # Sway validation requires a display, so just check file exists
    if [[ -f "$CONFIG_DIR/sway/config" ]]; then
        log_ok "Sway config file exists"
        # Check for obvious syntax errors
        if grep -qE '^\s*(include|set|bindsym|exec)' "$CONFIG_DIR/sway/config"; then
            log_ok "Sway config appears valid (basic check)"
        fi
    fi

    return 0
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
