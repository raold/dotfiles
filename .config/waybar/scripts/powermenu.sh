#!/usr/bin/env bash
# Power menu for Wayland (Sway/Hyprland) with pills rofi theme

dir="$HOME/.config/rofi"
uptime=$(uptime -p | sed -e 's/up //g')

rofi_command="rofi -no-config -theme $dir/powermenu-pills.rasi"

# Options
lock=" Lock"
suspend="󰤄 Sleep"
logout="󰍃 Logout"
reboot="󰜉 Reboot"
shutdown="⏻ Shutdown"

# Confirmation
confirm_exit() {
    rofi -dmenu \
        -no-config \
        -i \
        -no-fixed-num-lines \
        -p "Are You Sure? : " \
        -theme "$dir/confirm-pills.rasi"
}

msg() {
    rofi -no-config -theme "$dir/confirm-pills.rasi" -e "Options: yes / y / no / n"
}

options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

chosen="$(echo -e "$options" | $rofi_command -p "Uptime: $uptime" -dmenu -selected-row 0)"
case $chosen in
    $shutdown)
        ans=$(confirm_exit &)
        if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
            systemctl poweroff
        elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
            exit 0
        else
            msg
        fi
        ;;
    $reboot)
        ans=$(confirm_exit &)
        if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
            systemctl reboot
        elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
            exit 0
        else
            msg
        fi
        ;;
    $lock)
        # Wayland lock
        if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
            hyprlock
        elif [[ -n "$SWAYSOCK" ]]; then
            swaylock -f
        elif [[ -x /usr/bin/betterlockscreen ]]; then
            betterlockscreen -l
        fi
        ;;
    $suspend)
        ans=$(confirm_exit &)
        if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
            playerctl -a pause 2>/dev/null
            systemctl suspend
        elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
            exit 0
        else
            msg
        fi
        ;;
    $logout)
        ans=$(confirm_exit &)
        if [[ $ans == "yes" || $ans == "YES" || $ans == "y" || $ans == "Y" ]]; then
            if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
                hyprctl dispatch exit
            elif [[ -n "$SWAYSOCK" ]]; then
                swaymsg exit
            elif [[ -n "$(pgrep -x i3)" ]]; then
                i3-msg exit
            fi
        elif [[ $ans == "no" || $ans == "NO" || $ans == "n" || $ans == "N" ]]; then
            exit 0
        else
            msg
        fi
        ;;
esac
