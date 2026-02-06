#!/bin/bash
# Rofi calendar popup for waybar clock pill
# Drops down directly below the clicked pill
# Gruvbox Material Dark themed with month navigation

STATE="/tmp/waybar-cal-offset"
POS_FILE="/tmp/waybar-cal-pos"

# ── Position: anchor rofi below the waybar pill ──────
# Waybar: margin-top(6) + height(32) + gap(6) = 44px from top
BAR_BOTTOM=44

get_position() {
    local cursor_x=""

    if pgrep -x Hyprland >/dev/null 2>&1; then
        cursor_x=$(hyprctl cursorpos 2>/dev/null | cut -d',' -f1 | tr -d ' ')
    elif pgrep -x sway >/dev/null 2>&1; then
        cursor_x=$(swaymsg -t get_seats 2>/dev/null | jq -r '.[0].cursor.x // empty' 2>/dev/null | cut -d'.' -f1)
    fi

    if [[ -n "$cursor_x" && "$cursor_x" =~ ^[0-9]+$ ]]; then
        # Anchor rofi's top-center to cursor X, just below the bar
        echo "window { location: north west; anchor: north; x-offset: ${cursor_x}px; y-offset: ${BAR_BOTTOM}px; }"
    else
        # Fallback: top-right area where clock typically lives
        echo "window { location: north east; anchor: north east; x-offset: -200px; y-offset: ${BAR_BOTTOM}px; }"
    fi
}

# Capture position on first launch, reuse for month navigation
if [[ -f "$POS_FILE" ]]; then
    POS=$(cat "$POS_FILE")
else
    POS=$(get_position)
    echo "$POS" > "$POS_FILE"
fi

# ── Calendar logic ───────────────────────────────────
[[ -f "$STATE" ]] && offset=$(cat "$STATE") || offset=0

target=$(date -d "$(date +%Y-%m-01) ${offset} months" +%Y-%m-%d 2>/dev/null)
[[ -z "$target" ]] && target=$(date +%Y-%m-%d)

year=$(date -d "$target" +%Y)
month=$(date -d "$target" +%-m)
month_name=$(date -d "$target" +"%B %Y")

today=$(date +%-d)
is_current=0
[[ "$(date +%Y-%m)" == "$(date -d "$target" +%Y-%m)" ]] && is_current=1

# Generate calendar body (Monday-first, skip header lines)
cal_body=$(cal -m "$month" "$year" | tail -n +3)

# Highlight today in orange if viewing current month
if [[ "$is_current" -eq 1 ]]; then
    cal_body=$(echo "$cal_body" | sed -E "s|\b${today}\b|<b><span foreground=\"#e78a4e\">&</span></b>|g")
fi

# Build the calendar display for rofi message area
cal_msg="<span foreground='#a89984'>Mo Tu We Th Fr Sa Su</span>"$'\n'"${cal_body}"

# Navigation options
options="◀  Previous\n▶  Next"
[[ "$offset" -ne 0 ]] && options+="\n   Today"

# ── Show rofi calendar ───────────────────────────────
selected=$(echo -e "$options" | rofi -dmenu \
    -mesg "$cal_msg" \
    -p "📅 $month_name" \
    -theme ~/.config/rofi/calendar-pills.rasi \
    -theme-str "$POS" \
    -markup-rows \
    -no-custom \
    -selected-row 0 2>/dev/null)

case "$selected" in
    *"Previous"*)
        echo "$((offset - 1))" > "$STATE"
        exec "$0"
        ;;
    *"Next"*)
        echo "$((offset + 1))" > "$STATE"
        exec "$0"
        ;;
    *"Today"*)
        rm -f "$STATE"
        exec "$0"
        ;;
    *)
        rm -f "$STATE" "$POS_FILE"
        ;;
esac
