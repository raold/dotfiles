#!/usr/bin/env python3
"""Set inactive windows to transparent, focused window to opaque."""

import i3ipc

ACTIVE_OPACITY = 1.0
INACTIVE_OPACITY = 0.85

def on_window_focus(ipc, event):
    focused = event.container
    tree = ipc.get_tree()
    for window in tree.leaves():
        if window.id == focused.id:
            window.command(f"opacity {ACTIVE_OPACITY}")
        else:
            window.command(f"opacity {INACTIVE_OPACITY}")

ipc = i3ipc.Connection()

# Set initial state
tree = ipc.get_tree()
focused = tree.find_focused()
for window in tree.leaves():
    if focused and window.id == focused.id:
        window.command(f"opacity {ACTIVE_OPACITY}")
    else:
        window.command(f"opacity {INACTIVE_OPACITY}")

ipc.on("window::focus", on_window_focus)
ipc.main()
