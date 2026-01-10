#!/usr/bin/env python3
"""
Kitty kitten: clip2path
Pastes clipboard image as file path, or text if no image
"""

import subprocess
import os
from datetime import datetime


def main(args):
    pass


def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    # Check if clipboard contains an image
    try:
        result = subprocess.run(
            ['xclip', '-selection', 'clipboard', '-t', 'TARGETS', '-o'],
            capture_output=True,
            text=True
        )
        targets = result.stdout

        if 'image/png' in targets:
            # Save image to temp file
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filepath = f'/tmp/clipboard_{timestamp}.png'

            subprocess.run(
                ['xclip', '-selection', 'clipboard', '-t', 'image/png', '-o'],
                stdout=open(filepath, 'wb'),
                check=True
            )

            # Paste the file path
            window.paste_text(filepath)
        else:
            # No image - paste text normally
            result = subprocess.run(
                ['xclip', '-selection', 'clipboard', '-o'],
                capture_output=True,
                text=True
            )
            if result.stdout:
                window.paste_text(result.stdout)

    except Exception as e:
        # Fallback to regular paste on any error
        window.paste_from_clipboard()
