#!/bin/bash
# Battery module for waybar — uses upower for averaged estimates

CHARGE_LIMIT=70  # Framework BIOS charge limit (70% raw = 100% effective)
UPOWER_DEV="/org/freedesktop/UPower/devices/battery_BAT1"

# Parse upower output once
upower_info=$(upower -i "$UPOWER_DEV" 2>/dev/null)

state=$(echo "$upower_info" | awk '/^\s+state:/ {print $2}')
raw_pct=$(echo "$upower_info" | awk '/^\s+percentage:/ {gsub(/%/,""); print $2}')
energy_rate=$(echo "$upower_info" | awk '/^\s+energy-rate:/ {print $2}')
time_to_empty=$(echo "$upower_info" | awk '/^\s+time to empty:/ {print $4, $5}')
time_to_full=$(echo "$upower_info" | awk '/^\s+time to full:/ {print $4, $5}')

# Normalize percentage: 0–CHARGE_LIMIT% raw → 0–100% effective
eff_pct=$(( raw_pct * 100 / CHARGE_LIMIT ))
(( eff_pct > 100 )) && eff_pct=100

# Format watts to 1 decimal place
watts=$(python3 -c "print(f'{float(${energy_rate:-0}):.1f}W')")

# Format time from upower's "X.Y hours" or "X.Y minutes" into "Xh Ym"
format_time() {
    local val="$1" unit="$2"
    if [[ -z "$val" ]]; then return 1; fi
    local total_min
    if [[ "$unit" == hours* ]]; then
        total_min=$(python3 -c "print(int(round($val * 60)))")
    else
        total_min=$(python3 -c "print(int(round($val)))")
    fi
    local h=$(( total_min / 60 )) m=$(( total_min % 60 ))
    echo "${h}h ${m}m"
}

# Get time string based on state
time_str=""
case "$state" in
    discharging)
        time_str=$(format_time $time_to_empty) ;;
    charging)
        # upower doesn't know about our charge limit — recalculate from energy values
        # energy × (CHARGE_LIMIT/100) = target energy; (target - current) / rate = hours
        energy_now=$(echo "$upower_info" | awk '/^\s+energy:/ {print $2}')
        energy_full=$(echo "$upower_info" | awk '/^\s+energy-full:/ {print $2}')
        if [[ -n "$energy_rate" && "$energy_rate" != "0" ]]; then
            time_str=$(python3 -c "
target = $energy_full * $CHARGE_LIMIT / 100
remaining = target - $energy_now
if remaining > 0 and $energy_rate > 0:
    hours = remaining / $energy_rate
    total_min = int(round(hours * 60))
    print(f'{total_min // 60}h {total_min % 60}m')
" 2>/dev/null)
        fi
        ;;
esac

# Pick icon based on status + effective capacity
case "$state" in
    charging)
        icon=$'\U000F0084'  # 󰂄
        class="charging"
        ;;
    pending-charge)
        icon=$'\U000F06A5'  # 󰚥
        class="plugged"
        ;;
    fully-charged)
        icon=$'\U000F06A5'  # 󰚥
        class="full"
        ;;
    discharging|*)
        if (( eff_pct <= 15 )); then
            icon=$'\U000F008E'  # 󰂎
            class="critical"
        elif (( eff_pct <= 30 )); then
            icon=$'\U000F007A'  # 󰁺
            class="warning"
        elif (( eff_pct <= 60 )); then
            icon=$'\U000F007C'  # 󰁼
            class="discharging"
        elif (( eff_pct <= 80 )); then
            icon=$'\U000F007E'  # 󰁾
            class="discharging"
        else
            icon=$'\U000F0079'  # 󰁹
            class="good"
        fi
        ;;
esac

# Build pill text
if [[ "$state" == "fully-charged" ]]; then
    text="$icon Full"
elif [[ -n "$time_str" ]]; then
    text="$icon ${eff_pct}% $time_str $watts"
else
    text="$icon ${eff_pct}% $watts"
fi

# Tooltip with raw % for reference
tooltip="${state}\n${eff_pct}% (raw ${raw_pct}%)\n${watts}"
[[ -n "$time_str" ]] && tooltip="${tooltip}\n${time_str} remaining"

echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\", \"class\": \"$class\", \"percentage\": $eff_pct}"
