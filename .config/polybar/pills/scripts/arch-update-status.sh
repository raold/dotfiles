#!/usr/bin/env bash
# Polybar module for arch-update integration
# Shows combined repo + AUR update count with Gruvbox colors

# Icon config (Nerd Fonts)
ICON_UPDATED=""       # nf-md-package_check
ICON_UPDATES=""       # nf-md-package_down
ICON_MANY=""          # nf-md-package_variant_closed_plus

# State files from arch-update
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-update"
PACMAN_UPDATES="$STATE_DIR/last_updates_check_packages"
AUR_UPDATES="$STATE_DIR/last_updates_check_aur"

get_updates() {
    local pacman_count=0
    local aur_count=0

    # Read from arch-update state files if they exist
    [[ -f "$PACMAN_UPDATES" ]] && pacman_count=$(wc -l < "$PACMAN_UPDATES" 2>/dev/null | tr -d ' ')
    [[ -f "$AUR_UPDATES" ]] && aur_count=$(wc -l < "$AUR_UPDATES" 2>/dev/null | tr -d ' ')

    # Remove empty line counts
    [[ "$pacman_count" -eq 1 ]] && [[ ! -s "$PACMAN_UPDATES" ]] && pacman_count=0
    [[ "$aur_count" -eq 1 ]] && [[ ! -s "$AUR_UPDATES" ]] && aur_count=0

    echo "$((pacman_count + aur_count))"
}

while true; do
    UPDATES=$(get_updates)

    if (( UPDATES == 0 )); then
        # Up to date - muted green
        echo "%{F#b8bb26}$ICON_UPDATED%{F-}"
    elif (( UPDATES < 10 )); then
        # Few updates - yellow with count
        echo "%{F#fabd2f}$ICON_UPDATES $UPDATES%{F-}"
    elif (( UPDATES < 50 )); then
        # Many updates - orange with count
        echo "%{F#fe8019}$ICON_MANY $UPDATES%{F-}"
    else
        # Urgent - red with count
        echo "%{F#fb4934}$ICON_MANY $UPDATES!%{F-}"
    fi

    sleep 60
done
