#!/bin/bash
# Disable Thunderbolt NHI wakeup sources to allow S0i3 during s2idle.
# Framework 13 AMD — NHI0/NHI1 on c3:00.5/c3:00.6 block deepest idle.

case "$1" in
    pre)
        # Disable PCI wakeup for Thunderbolt NHI controllers (S0i3 blockers)
        echo disabled > /sys/bus/pci/devices/0000:c3:00.5/power/wakeup 2>/dev/null
        echo disabled > /sys/bus/pci/devices/0000:c3:00.6/power/wakeup 2>/dev/null
        ;;
    post)
        # Re-enable after resume (Thunderbolt needs wakeup for hotplug)
        echo enabled > /sys/bus/pci/devices/0000:c3:00.5/power/wakeup 2>/dev/null
        echo enabled > /sys/bus/pci/devices/0000:c3:00.6/power/wakeup 2>/dev/null
        ;;
esac
