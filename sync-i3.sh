#!/bin/bash
# Sync i3 + polybar + X11 tools
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

I3_DIRS=(i3 polybar picom)

collect() {
    log_info "Collecting i3 configs from system to repo..."

    for dir in "${I3_DIRS[@]}"; do
        if [[ -d "$CONFIG_DIR/$dir" ]]; then
            rm -rf "$DOTFILES_DIR/.config/$dir"
            cp -r "$CONFIG_DIR/$dir" "$DOTFILES_DIR/.config/$dir"
            log_ok "Collected: .config/$dir/"
        else
            log_warn "Not found: .config/$dir/"
        fi
    done

    log_ok "i3 configs collected to repo"
}

install() {
    log_info "Installing i3 configs from repo to system..."
    check_packages i3 || log_warn "Some i3 packages missing (continuing anyway)"

    for dir in "${I3_DIRS[@]}"; do
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

    log_ok "i3 configs installed to system"
}

validate() {
    log_info "Validating i3 config..."

    if [[ ! -f "$CONFIG_DIR/i3/config" ]]; then
        log_error "i3 config not found"
        return 1
    fi

    if i3 -C -c "$CONFIG_DIR/i3/config" 2>&1 | grep -qi "error"; then
        log_error "i3 config has errors:"
        i3 -C -c "$CONFIG_DIR/i3/config" 2>&1
        return 1
    fi

    log_ok "i3 config is valid"
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
