#!/bin/bash
# Battery module for waybar — polls power_supply sysfs directly

BAT="/sys/class/power_supply/BAT1"

capacity=$(cat "$BAT/capacity")
status=$(cat "$BAT/status")

# Calculate watts from current × voltage
current=$(cat "$BAT/current_now" 2>/dev/null || echo 0)
voltage=$(cat "$BAT/voltage_now" 2>/dev/null || echo 0)
watts=$(python3 -c "print(f'{$current/1e6 * $voltage/1e6:.1f}')")

# Pick icon based on status + capacity
case "$status" in
    Charging)
        icon=$'\U000F0084'  # 󰂄
        class="charging"
        text="$icon ${capacity}% ${watts}W"
        ;;
    "Not charging")
        icon=$'\U000F06A5'  # 󰚥
        class="plugged"
        text="$icon ${capacity}%"
        ;;
    Full)
        icon=$'\U000F06A5'  # 󰚥
        class="full"
        text="$icon Full"
        ;;
    Discharging|*)
        if (( capacity <= 15 )); then
            icon=$'\U000F008E'  # 󰂎
            class="critical"
        elif (( capacity <= 30 )); then
            icon=$'\U000F007A'  # 󰁺
            class="warning"
        elif (( capacity <= 60 )); then
            icon=$'\U000F007C'  # 󰁼
            class="discharging"
        elif (( capacity <= 80 )); then
            icon=$'\U000F007E'  # 󰁾
            class="discharging"
        else
            icon=$'\U000F0079'  # 󰁹
            class="good"
        fi
        text="$icon ${capacity}% ${watts}W"
        ;;
esac

tooltip="${status}\n${capacity}%\n${watts}W"

echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\", \"class\": \"$class\", \"percentage\": $capacity}"
