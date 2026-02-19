#!/usr/bin/python3
"""Disk/storage TUI dashboard for Framework 13 AMD.

Opens in kitty via waybar disk click. Shows live-updating filesystem
usage, NVMe info, I/O stats, and ZRAM compression details.
"""

import os
import re
import select
import signal
import sys
import termios
import time
import tty
from dataclasses import dataclass
from pathlib import Path

from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

# ── Gruvbox Material Dark palette ──────────────────────────────────────
BG = "#282828"
BG_SOFT = "#32302f"
FG = "#d4be98"
FG_DIM = "#928374"
RED = "#ea6962"
GREEN = "#a9b665"
YELLOW = "#d8a657"
BLUE = "#7daea3"
ORANGE = "#e78a4e"
AQUA = "#89b482"
PURPLE = "#d3869b"

# Filesystem types worth displaying
INTERESTING_FS = {"ext4", "vfat", "btrfs", "xfs", "f2fs", "ntfs", "fuseblk"}
INTERESTING_TMPFS_MOUNTS = {"/tmp", "/dev/shm"}

# ── sysfs helpers ──────────────────────────────────────────────────────


def sysfs_read(path: str, default: str = "") -> str:
    """Read a sysfs file, returning default on any error."""
    try:
        return Path(path).read_text().strip()
    except (OSError, ValueError):
        return default


def sysfs_int(path: str, default: int = 0) -> int:
    """Read a sysfs file as int."""
    try:
        return int(Path(path).read_text().strip())
    except (OSError, ValueError):
        return default


def discover_hwmon() -> dict[str, str]:
    """Map hwmon name -> path (e.g. 'nvme' -> '/sys/class/hwmon/hwmon3')."""
    mapping: dict[str, str] = {}
    hwmon_base = Path("/sys/class/hwmon")
    if not hwmon_base.exists():
        return mapping
    for d in sorted(hwmon_base.iterdir()):
        name_file = d / "name"
        if name_file.exists():
            try:
                name = name_file.read_text().strip()
            except OSError:
                continue
            if name not in mapping:
                mapping[name] = str(d)
    return mapping


def fmt_bytes(n: int | float) -> str:
    """Format bytes as human-readable (1024-based: B, KiB, MiB, GiB, TiB)."""
    if n < 0:
        return "0 B"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    value = float(n)
    for unit in units:
        if abs(value) < 1024.0 or unit == units[-1]:
            if value >= 100:
                return f"{value:.1f} {unit}"
            elif value >= 10:
                return f"{value:.1f} {unit}"
            else:
                return f"{value:.2f} {unit}"
        value /= 1024.0
    return f"{value:.1f} TiB"


def fmt_count(n: int) -> str:
    """Format large counts with K/M suffix."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n / 1_000:.0f}K"
    return str(n)


# ── Data classes ───────────────────────────────────────────────────────


@dataclass
class FilesystemEntry:
    mount: str = ""
    device: str = ""
    fstype: str = ""
    size: int = 0
    used: int = 0
    avail: int = 0
    use_pct: float = 0.0


@dataclass
class NvmeData:
    model: str = ""
    firmware: str = ""
    temp_mc: int = 0  # milli-Celsius
    state: str = ""


@dataclass
class IoStats:
    reads: int = 0
    read_sectors: int = 0
    writes: int = 0
    write_sectors: int = 0
    read_bytes: int = 0
    write_bytes: int = 0
    read_bps: float = 0.0   # bytes per second
    write_bps: float = 0.0  # bytes per second


@dataclass
class ZramData:
    disksize: int = 0
    orig_data_size: int = 0
    compr_data_size: int = 0
    mem_used_total: int = 0
    comp_algorithm: str = ""

    @property
    def ratio(self) -> float:
        if self.compr_data_size == 0:
            return 0.0
        return self.orig_data_size / self.compr_data_size


# ── Readers ────────────────────────────────────────────────────────────


def read_filesystems() -> list[FilesystemEntry]:
    """Discover mounted filesystems from /proc/mounts and statvfs them."""
    entries: list[FilesystemEntry] = []
    seen_mounts: set[str] = set()
    seen_devices: dict[str, str] = {}  # device -> first mount point

    # Primary mount points to prefer over bind mounts
    PRIMARY_MOUNTS = {"/", "/boot", "/home", "/tmp", "/dev/shm",
                      "/mnt/expansion", "/mnt/timeshift"}

    try:
        mounts_text = Path("/proc/mounts").read_text()
    except OSError:
        return entries

    for line in mounts_text.splitlines():
        parts = line.split()
        if len(parts) < 3:
            continue
        device, mount, fstype = parts[0], parts[1], parts[2]

        # Filter to interesting types
        if fstype in INTERESTING_FS:
            pass
        elif fstype == "tmpfs" and mount in INTERESTING_TMPFS_MOUNTS:
            pass
        else:
            continue

        # Deduplicate by mount point (first occurrence wins)
        if mount in seen_mounts:
            continue
        seen_mounts.add(mount)

        # For real block devices, skip bind mounts (same device, non-primary path)
        if device.startswith("/dev/"):
            if device in seen_devices:
                # Already have a mount for this device; skip unless this is more primary
                if mount not in PRIMARY_MOUNTS:
                    continue
            seen_devices[device] = mount

        try:
            st = os.statvfs(mount)
        except OSError:
            continue

        block_size = st.f_frsize
        total = st.f_blocks * block_size
        free = st.f_bfree * block_size
        avail = st.f_bavail * block_size
        used = total - free

        if total == 0:
            continue

        use_pct = (used / total) * 100

        entries.append(FilesystemEntry(
            mount=mount,
            device=device,
            fstype=fstype,
            size=total,
            used=used,
            avail=avail,
            use_pct=use_pct,
        ))

    # Sort: / first, /boot second, then alphabetically
    def sort_key(e: FilesystemEntry) -> tuple[int, str]:
        if e.mount == "/":
            return (0, "")
        if e.mount == "/boot":
            return (1, "")
        return (2, e.mount)

    entries.sort(key=sort_key)
    return entries


def read_nvme(hwmon: dict[str, str]) -> NvmeData:
    """Read NVMe device info from sysfs."""
    data = NvmeData(
        model=sysfs_read("/sys/class/nvme/nvme0/model"),
        firmware=sysfs_read("/sys/class/nvme/nvme0/firmware_rev"),
        state=sysfs_read("/sys/class/nvme/nvme0/state"),
    )

    # Temperature from hwmon
    nvme_hwmon = hwmon.get("nvme", "")
    if nvme_hwmon:
        data.temp_mc = sysfs_int(f"{nvme_hwmon}/temp1_input")

    return data


def read_io_stats() -> tuple[int, int, int, int]:
    """Read raw I/O stats from /sys/block/nvme0n1/stat.

    Returns (reads_completed, sectors_read, writes_completed, sectors_written).
    """
    raw = sysfs_read("/sys/block/nvme0n1/stat")
    if not raw:
        return (0, 0, 0, 0)
    fields = raw.split()
    if len(fields) < 7:
        return (0, 0, 0, 0)
    try:
        return (
            int(fields[0]),  # reads completed
            int(fields[2]),  # sectors read
            int(fields[4]),  # writes completed
            int(fields[6]),  # sectors written
        )
    except (ValueError, IndexError):
        return (0, 0, 0, 0)


def compute_io(
    prev_raw: tuple[int, int, int, int],
    curr_raw: tuple[int, int, int, int],
    dt: float,
) -> IoStats:
    """Compute I/O stats with throughput from two samples."""
    reads, read_sec, writes, write_sec = curr_raw
    read_bytes = read_sec * 512
    write_bytes = write_sec * 512

    read_bps = 0.0
    write_bps = 0.0
    if dt > 0 and prev_raw != (0, 0, 0, 0):
        delta_read = (read_sec - prev_raw[1]) * 512
        delta_write = (write_sec - prev_raw[3]) * 512
        read_bps = max(0.0, delta_read / dt)
        write_bps = max(0.0, delta_write / dt)

    return IoStats(
        reads=reads,
        read_sectors=read_sec,
        writes=writes,
        write_sectors=write_sec,
        read_bytes=read_bytes,
        write_bytes=write_bytes,
        read_bps=read_bps,
        write_bps=write_bps,
    )


def read_zram() -> ZramData:
    """Read ZRAM stats from sysfs."""
    data = ZramData()

    data.disksize = sysfs_int("/sys/block/zram0/disksize")

    mm_stat = sysfs_read("/sys/block/zram0/mm_stat")
    if mm_stat:
        fields = mm_stat.split()
        if len(fields) >= 3:
            try:
                data.orig_data_size = int(fields[0])
                data.compr_data_size = int(fields[1])
                data.mem_used_total = int(fields[2])
            except ValueError:
                pass

    # Parse compression algorithm (active one in brackets: [zstd])
    algo_raw = sysfs_read("/sys/block/zram0/comp_algorithm")
    match = re.search(r"\[(\w+)\]", algo_raw)
    if match:
        data.comp_algorithm = match.group(1)
    else:
        data.comp_algorithm = algo_raw

    return data


# ── Bar helpers ────────────────────────────────────────────────────────


def make_bar(value: int, max_val: int, width: int = 10, color: str = GREEN) -> Text:
    """Create a colored progress bar."""
    if max_val <= 0:
        ratio = 0.0
    else:
        ratio = min(value / max_val, 1.0)
    filled = int(ratio * width)
    bar = Text()
    bar.append("\u2588" * filled, style=color)
    bar.append("\u2591" * (width - filled), style=FG_DIM)
    return bar


def usage_color(pct: float) -> str:
    """Color for disk usage percentage."""
    if pct >= 95:
        return RED
    if pct >= 85:
        return ORANGE
    if pct >= 70:
        return YELLOW
    return GREEN


def temp_color(temp_c: float) -> str:
    """Color for temperature in Celsius."""
    if temp_c >= 70:
        return RED
    if temp_c >= 55:
        return ORANGE
    if temp_c >= 40:
        return YELLOW
    return GREEN


# ── Renderers ──────────────────────────────────────────────────────────


def render_filesystems(entries: list[FilesystemEntry]) -> Panel:
    """Render the filesystem table."""
    t = Table(
        padding=(0, 1),
        show_header=True,
        header_style=f"bold {FG}",
        show_edge=False,
        show_lines=False,
        expand=True,
        box=None,
    )
    t.add_column("Mount", style=BLUE, min_width=10, no_wrap=True)
    t.add_column("Type", style=FG_DIM, min_width=5)
    t.add_column("Size", style=FG, justify="right", min_width=8)
    t.add_column("Used", style=FG, justify="right", min_width=8)
    t.add_column("Avail", style=FG, justify="right", min_width=8)
    t.add_column("Use%", justify="right", min_width=5)
    t.add_column("Bar", min_width=12, no_wrap=True)

    for e in entries:
        color = usage_color(e.use_pct)
        pct_text = Text(f"{e.use_pct:.0f}%", style=f"bold {color}")
        bar = make_bar(int(e.use_pct), 100, 10, color)

        t.add_row(
            e.mount,
            e.fstype,
            fmt_bytes(e.size),
            fmt_bytes(e.used),
            fmt_bytes(e.avail),
            pct_text,
            bar,
        )

    return Panel(t, title="Filesystems", border_style=BLUE, padding=(0, 1))


def render_nvme(nvme: NvmeData) -> Panel:
    """Render NVMe device info panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=8)
    t.add_column(min_width=22)

    t.add_row("Model:", Text(nvme.model, style=FG))
    t.add_row("FW:", Text(nvme.firmware, style=FG))

    # Temperature with bar
    if nvme.temp_mc > 0:
        temp_c = nvme.temp_mc / 1000
        color = temp_color(temp_c)
        temp_text = Text()
        temp_text.append(f"{temp_c:.0f}\u00b0C  ", style=f"bold {color}")
        temp_text.append_text(make_bar(int(temp_c), 80, 9, color))
        t.add_row("Temp:", temp_text)
    else:
        t.add_row("Temp:", Text("N/A", style=FG_DIM))

    state_color = GREEN if nvme.state == "live" else YELLOW
    t.add_row("State:", Text(nvme.state, style=state_color))

    return Panel(t, title="NVMe", border_style=AQUA, padding=(0, 1))


def render_io(io: IoStats) -> Panel:
    """Render I/O stats panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column(min_width=22)

    # Cumulative totals
    t.add_row(
        "Read:",
        Text(
            f"{fmt_bytes(io.read_bytes)}  ({fmt_count(io.reads)} ops)",
            style=GREEN,
        ),
    )
    t.add_row(
        "Write:",
        Text(
            f"{fmt_bytes(io.write_bytes)}  ({fmt_count(io.writes)} ops)",
            style=ORANGE,
        ),
    )

    # Throughput
    read_mbs = io.read_bps / (1024 * 1024)
    write_mbs = io.write_bps / (1024 * 1024)

    read_color = AQUA if read_mbs > 0.1 else FG_DIM
    write_color = YELLOW if write_mbs > 0.1 else FG_DIM

    t.add_row("Read/s:", Text(f"{read_mbs:.1f} MiB/s", style=read_color))
    t.add_row("Write/s:", Text(f"{write_mbs:.1f} MiB/s", style=write_color))

    return Panel(t, title="I/O Stats", border_style=ORANGE, padding=(0, 1))


def render_zram(zram: ZramData) -> Panel:
    """Render ZRAM compression stats panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column(min_width=18)

    t.add_row("Size:", Text(fmt_bytes(zram.disksize), style=FG))
    t.add_row("Orig:", Text(fmt_bytes(zram.orig_data_size), style=FG))
    t.add_row("Compr:", Text(fmt_bytes(zram.compr_data_size), style=AQUA))

    ratio = zram.ratio
    if ratio > 0:
        ratio_color = GREEN if ratio >= 2.0 else YELLOW if ratio >= 1.5 else ORANGE
        t.add_row("Ratio:", Text(f"{ratio:.2f}x", style=f"bold {ratio_color}"))
    else:
        t.add_row("Ratio:", Text("N/A", style=FG_DIM))

    t.add_row("Compr Alg:", Text(zram.comp_algorithm, style=PURPLE))

    return Panel(t, title="ZRAM", border_style=PURPLE, padding=(0, 1))


def render_footer() -> Text:
    """Render the bottom status line."""
    ft = Text(justify="center")
    ft.append("  q ", style=f"bold {FG}")
    ft.append("quit", style=FG_DIM)
    ft.append("  ", style=FG_DIM)
    # Pad to push refresh indicator right
    ft.append(" " * 40, style=FG_DIM)
    ft.append("\u21bb 1.5s", style=FG_DIM)
    return ft


# ── Layout builder ─────────────────────────────────────────────────────


def build_layout(
    filesystems: list[FilesystemEntry],
    nvme: NvmeData,
    io: IoStats,
    zram: ZramData,
) -> Layout:
    """Build the full-screen layout."""
    layout = Layout()

    # Main body + footer
    layout.split_column(
        Layout(name="body", ratio=1),
        Layout(name="footer", size=1),
    )

    # Body: filesystems on top, details on bottom
    layout["body"].split_column(
        Layout(name="filesystems", size=3 + len(filesystems) + 2),  # header + rows + panel border
        Layout(name="details", ratio=1),
    )

    # Details: left (nvme + zram) and right (io)
    layout["details"].split_row(
        Layout(name="left_detail", ratio=1),
        Layout(name="right_detail", ratio=1),
    )

    # Left: nvme on top, zram on bottom
    layout["left_detail"].split_column(
        Layout(name="nvme", ratio=1),
        Layout(name="zram", ratio=1),
    )

    # Populate
    layout["filesystems"].update(render_filesystems(filesystems))
    layout["nvme"].update(render_nvme(nvme))
    layout["right_detail"].update(render_io(io))
    layout["zram"].update(render_zram(zram))
    layout["footer"].update(render_footer())

    return layout


# ── Main ───────────────────────────────────────────────────────────────


def main() -> None:
    console = Console()
    hwmon = discover_hwmon()

    # Save terminal state for clean restore
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    def restore_terminal(*_: object) -> None:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

    signal.signal(signal.SIGINT, lambda *_: (restore_terminal(), sys.exit(0)))
    signal.signal(signal.SIGTERM, lambda *_: (restore_terminal(), sys.exit(0)))

    try:
        tty.setcbreak(fd)

        # I/O tracking state
        prev_io_raw: tuple[int, int, int, int] = (0, 0, 0, 0)
        prev_io_time: float = 0.0

        with Live(
            console=console,
            screen=True,
            refresh_per_second=4,
            transient=True,
        ) as live:
            last_data_time = 0.0

            while True:
                # Poll keyboard (50ms timeout)
                if select.select([sys.stdin], [], [], 0.05)[0]:
                    key = sys.stdin.read(1)
                    if key in ("q", "Q", "\x1b"):  # q, Q, or Escape
                        break

                # Refresh data every 1.5s
                now = time.monotonic()
                if now - last_data_time >= 1.5:
                    dt = now - prev_io_time if prev_io_time > 0 else 0.0

                    # Read all data
                    filesystems = read_filesystems()
                    nvme = read_nvme(hwmon)
                    curr_io_raw = read_io_stats()
                    io = compute_io(prev_io_raw, curr_io_raw, dt)
                    zram = read_zram()

                    # Update I/O tracking
                    prev_io_raw = curr_io_raw
                    prev_io_time = now
                    last_data_time = now

                    layout = build_layout(filesystems, nvme, io, zram)
                    live.update(layout)

    finally:
        restore_terminal()


if __name__ == "__main__":
    main()
