#!/bin/bash
# Clock with hour-matching clock face icons for waybar

day=$(date +%-d)
case $day in
    1|21|31) suffix="st" ;; 2|22) suffix="nd" ;; 3|23) suffix="rd" ;; *) suffix="th" ;;
esac

if [[ "$1" == "--alt" ]]; then
    text="$(date +'%a, %d %b %Y')"
else
    text="$(date +'%I:%M %p %B') ${day}${suffix}"
fi

tooltip="$(date +'%A, %B %d, %Y\n%I:%M:%S %p')"

echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\"}"
