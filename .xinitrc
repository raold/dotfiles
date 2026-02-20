#!/bin/sh

# Load font rendering settings (DPI, Xft antialiasing, hinting)
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

exec i3
