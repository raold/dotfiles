#!/usr/bin/env bash

# Toggle gsimplecal - if running, kill it; if not, open it
if pgrep -x gsimplecal > /dev/null; then
    killall gsimplecal
else
    gsimplecal &
fi
