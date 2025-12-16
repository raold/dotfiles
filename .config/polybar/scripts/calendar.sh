#!/bin/bash
# Calendar popup for polybar using yad

yad --calendar \
    --title="Calendar" \
    --no-buttons \
    --undecorated \
    --fixed \
    --close-on-unfocus \
    --on-top \
    --skip-taskbar \
    --posx=1600 \
    --posy=40 \
    --width=250 \
    --height=200 \
    --class="calendar-popup" \
    >/dev/null 2>&1 &
