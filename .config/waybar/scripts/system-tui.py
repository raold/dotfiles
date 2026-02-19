#!/usr/bin/python3
"""System monitoring TUI dashboard for Framework 13 AMD.

Live-updating CPU/memory/thermal/scheduler dashboard using rich.
Designed for Ryzen 7040 (16 threads) + Radeon 780M on Arch Linux
with CachyOS kernel and sched-ext support.
"""

import signal
import select
import sys
import termios
import time
import tty
from dataclasses import dataclass, field
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

NUM_CORES = 16

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


def discover_hwmon() -> dict[str, str | list[str]]:
    """Map hwmon name -> path (e.g. 'cros_ec' -> '/sys/class/hwmon/hwmon8').

    For names with multiple entries (like spd5118), store as list.
    """
    mapping: dict[str, str | list[str]] = {}
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
            if name in mapping:
                existing = mapping[name]
                if isinstance(existing, list):
                    existing.append(str(d))
                else:
                    mapping[name] = [existing, str(d)]
            else:
                mapping[name] = str(d)
    return mapping


def fmt_bytes(n: int) -> str:
    """Format bytes into human-readable binary units (KiB, MiB, GiB)."""
    if n < 0:
        return "0 B"
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(n) < 1024:
            if unit == "B":
                return f"{n} {unit}"
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PiB"


def make_bar(value: float, max_val: float, width: int = 10, color: str = GREEN) -> Text:
    """Create a colored progress bar using block characters."""
    if max_val <= 0:
        ratio = 0.0
    else:
        ratio = min(value / max_val, 1.0)
    filled = int(ratio * width)
    bar = Text()
    bar.append("█" * filled, style=color)
    bar.append("░" * (width - filled), style=FG_DIM)
    return bar


def temp_color(temp_c: float) -> str:
    """Return color string based on temperature thresholds."""
    if temp_c >= 85:
        return RED
    if temp_c >= 70:
        return ORANGE
    if temp_c >= 55:
        return YELLOW
    return GREEN


def freq_color(ratio: float) -> str:
    """Return color string based on frequency ratio (cur/max)."""
    if ratio > 0.90:
        return RED
    if ratio > 0.70:
        return ORANGE
    if ratio > 0.40:
        return YELLOW
    return GREEN


# ── Data classes ───────────────────────────────────────────────────────


@dataclass
class CoreData:
    """Per-core CPU data."""
    core_id: int = 0
    freq_khz: int = 0
    max_freq_khz: int = 0
    governor: str = ""
    epp: str = ""


@dataclass
class CpuData:
    """Aggregate CPU data."""
    cores: list[CoreData] = field(default_factory=list)
    driver: str = ""
    boost: bool = False
    avg_freq_ghz: float = 0.0


@dataclass
class SchedData:
    """Scheduler info from sched-ext."""
    sched_type: str = "EEVDF (default)"
    sched_name: str = ""
    sched_version: str = ""
    state: str = "disabled"


@dataclass
class ThermalData:
    """Thermal sensor readings (all in milli-Celsius except fan_rpm)."""
    cpu_ec: int = 0
    ambient: int = 0
    ddr: int = 0
    gpu: int = 0
    nvme: int = 0
    fan_rpm: int = 0


@dataclass
class MemoryData:
    """Memory stats from /proc/meminfo (all in kB)."""
    total_kb: int = 0
    free_kb: int = 0
    available_kb: int = 0
    buffers_kb: int = 0
    cached_kb: int = 0
    swap_total_kb: int = 0
    swap_free_kb: int = 0

    @property
    def used_kb(self) -> int:
        return self.total_kb - self.free_kb - self.buffers_kb - self.cached_kb

    @property
    def swap_used_kb(self) -> int:
        return self.swap_total_kb - self.swap_free_kb


@dataclass
class ZramData:
    """ZRAM stats from /sys/block/zram0/mm_stat."""
    orig_bytes: int = 0
    compr_bytes: int = 0
    algo: str = ""

    @property
    def ratio(self) -> float:
        if self.compr_bytes > 0:
            return self.orig_bytes / self.compr_bytes
        return 0.0


# ── Readers ────────────────────────────────────────────────────────────


def read_cpu() -> CpuData:
    """Read per-core and aggregate CPU data."""
    cores: list[CoreData] = []
    total_freq = 0
    count = 0

    for i in range(NUM_CORES):
        base = f"/sys/devices/system/cpu/cpu{i}/cpufreq"
        freq = sysfs_int(f"{base}/scaling_cur_freq")
        max_freq = sysfs_int(f"{base}/scaling_max_freq")
        governor = sysfs_read(f"{base}/scaling_governor")
        epp = sysfs_read(f"{base}/energy_performance_preference")

        cores.append(CoreData(
            core_id=i,
            freq_khz=freq,
            max_freq_khz=max_freq,
            governor=governor,
            epp=epp,
        ))

        if freq > 0:
            total_freq += freq
            count += 1

    avg_ghz = (total_freq / count / 1e6) if count > 0 else 0.0
    driver = sysfs_read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver")
    boost = sysfs_read("/sys/devices/system/cpu/cpufreq/boost") == "1"

    return CpuData(cores=cores, driver=driver, boost=boost, avg_freq_ghz=avg_ghz)


def read_scheduler() -> SchedData:
    """Read sched-ext scheduler info."""
    data = SchedData()
    state = sysfs_read("/sys/kernel/sched_ext/state")
    data.state = state if state else "disabled"

    if state == "enabled":
        ops = sysfs_read("/sys/kernel/sched_ext/root/ops")
        data.sched_type = "sched-ext"
        if ops:
            # e.g. "lavd_1.0.21_g7298f797_x86_64_unknown_linux_gnu"
            parts = ops.split("_")
            if len(parts) >= 2:
                data.sched_name = parts[0]
                data.sched_version = parts[1]
            else:
                data.sched_name = ops
    else:
        data.sched_type = "EEVDF (default)"
        data.sched_name = "EEVDF"

    return data


def read_thermals(hwmon: dict[str, str | list[str]]) -> ThermalData:
    """Read thermal sensors from hwmon."""
    data = ThermalData()

    cros = hwmon.get("cros_ec", "")
    if isinstance(cros, str) and cros:
        data.cpu_ec = sysfs_int(f"{cros}/temp2_input")
        data.ambient = sysfs_int(f"{cros}/temp1_input")
        data.ddr = sysfs_int(f"{cros}/temp3_input")
        data.fan_rpm = sysfs_int(f"{cros}/fan1_input")

    gpu_path = hwmon.get("amdgpu", "")
    if isinstance(gpu_path, str) and gpu_path:
        data.gpu = sysfs_int(f"{gpu_path}/temp1_input")

    nvme_path = hwmon.get("nvme", "")
    if isinstance(nvme_path, str) and nvme_path:
        data.nvme = sysfs_int(f"{nvme_path}/temp1_input")

    return data


def read_memory() -> MemoryData:
    """Read memory stats from /proc/meminfo."""
    data = MemoryData()
    try:
        text = Path("/proc/meminfo").read_text()
    except OSError:
        return data

    fields = {
        "MemTotal:": "total_kb",
        "MemFree:": "free_kb",
        "MemAvailable:": "available_kb",
        "Buffers:": "buffers_kb",
        "Cached:": "cached_kb",
        "SwapTotal:": "swap_total_kb",
        "SwapFree:": "swap_free_kb",
    }

    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] in fields:
            try:
                setattr(data, fields[parts[0]], int(parts[1]))
            except ValueError:
                pass

    return data


def read_zram() -> ZramData:
    """Read ZRAM stats from /sys/block/zram0/mm_stat."""
    data = ZramData()

    mm_stat = sysfs_read("/sys/block/zram0/mm_stat")
    if mm_stat:
        parts = mm_stat.split()
        if len(parts) >= 2:
            try:
                data.orig_bytes = int(parts[0])
                data.compr_bytes = int(parts[1])
            except ValueError:
                pass

    # Parse active algorithm from comp_algorithm (e.g. "lzo lzo-rle [zstd]")
    algo_str = sysfs_read("/sys/block/zram0/comp_algorithm")
    if algo_str:
        for token in algo_str.split():
            if token.startswith("[") and token.endswith("]"):
                data.algo = token[1:-1]
                break

    return data


# ── Renderers ──────────────────────────────────────────────────────────


def render_cpu(cpu: CpuData) -> Panel:
    """Render the CPU cores panel with per-core table and summary."""
    t = Table.grid(padding=(0, 1))
    t.add_column(justify="right", min_width=4, style=FG_DIM)   # Core
    t.add_column(justify="right", min_width=10)                  # Freq
    t.add_column(min_width=16)                                   # Bar
    t.add_column(min_width=11)                                   # Governor
    t.add_column(min_width=16)                                   # EPP

    # Header
    t.add_row(
        Text("Core", style=f"bold {FG}"),
        Text("Freq (GHz)", style=f"bold {FG}"),
        Text("Bar", style=f"bold {FG}"),
        Text("Governor", style=f"bold {FG}"),
        Text("EPP", style=f"bold {FG}"),
    )

    for core in cpu.cores:
        freq_ghz = core.freq_khz / 1e6
        max_ghz = core.max_freq_khz / 1e6

        if core.max_freq_khz > 0:
            ratio = core.freq_khz / core.max_freq_khz
        else:
            ratio = 0.0

        pct = int(ratio * 100)
        color = freq_color(ratio)

        bar = make_bar(core.freq_khz, core.max_freq_khz, 10, color)
        bar_with_pct = Text()
        bar_with_pct.append_text(bar)
        bar_with_pct.append(f"  {pct:>3}%", style=color)

        t.add_row(
            Text(f"{core.core_id:>2}", style=FG),
            Text(f"{freq_ghz:.2f}", style=color),
            bar_with_pct,
            Text(core.governor, style=BLUE),
            Text(core.epp, style=PURPLE),
        )

    # Summary line
    summary = Text()
    summary.append(f"  Avg: {cpu.avg_freq_ghz:.2f} GHz", style=f"bold {FG}")
    summary.append("    Driver: ", style=FG_DIM)
    summary.append(cpu.driver, style=AQUA)
    summary.append("    Boost: ", style=FG_DIM)
    if cpu.boost:
        summary.append("Enabled", style=GREEN)
    else:
        summary.append("Disabled", style=RED)

    outer = Table.grid()
    outer.add_column()
    outer.add_row(t)
    outer.add_row(Text(""))
    outer.add_row(summary)

    return Panel(outer, title="CPU Cores", border_style=AQUA, padding=(0, 1))


def render_scheduler(sched: SchedData) -> Panel:
    """Render the scheduler info panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=8)
    t.add_column()

    t.add_row("Type:", Text(sched.sched_type, style=AQUA))

    if sched.state == "enabled" and sched.sched_name:
        sched_label = f"scx_{sched.sched_name}"
        if sched.sched_version:
            sched_label += f" v{sched.sched_version}"
        t.add_row("Sched:", Text(sched_label, style=f"bold {GREEN}"))
    else:
        t.add_row("Sched:", Text(sched.sched_name or "N/A", style=FG))

    state_color = GREEN if sched.state == "enabled" else YELLOW
    t.add_row("State:", Text(sched.state, style=state_color))

    return Panel(t, title="Scheduler", border_style=AQUA, padding=(0, 1))


def render_thermals(th: ThermalData) -> Panel:
    """Render the thermals panel with sensor bars."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column(min_width=7, justify="right")
    t.add_column(min_width=12)

    sensors = [
        ("CPU (EC)", th.cpu_ec),
        ("Ambient", th.ambient),
        ("DDR", th.ddr),
        ("GPU", th.gpu),
        ("NVMe", th.nvme),
    ]

    for name, val_mc in sensors:
        if val_mc == 0:
            t.add_row(f"{name}:", Text("N/A", style=FG_DIM), Text(""))
        else:
            temp_c = val_mc / 1000
            color = temp_color(temp_c)
            bar = make_bar(temp_c, 100, 9, color)
            t.add_row(f"{name}:", Text(f"{temp_c:.0f}°C", style=color), bar)

    # Fan RPM
    if th.fan_rpm > 0:
        fan_color = ORANGE if th.fan_rpm > 5000 else YELLOW if th.fan_rpm > 3000 else GREEN
        t.add_row("Fan:", Text(f"{th.fan_rpm} RPM", style=fan_color), Text(""))
    else:
        t.add_row("Fan:", Text("Off", style=GREEN), Text(""))

    return Panel(t, title="Thermals", border_style=RED, padding=(0, 1))


def render_memory(mem: MemoryData) -> Panel:
    """Render the memory panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=12)
    t.add_column(min_width=28)

    total_gib = mem.total_kb / 1048576
    used_gib = mem.used_kb / 1048576
    buffers_gib = mem.buffers_kb / 1048576
    cached_gib = mem.cached_kb / 1048576
    available_gib = mem.available_kb / 1048576
    swap_used_gib = mem.swap_used_kb / 1048576
    swap_total_gib = mem.swap_total_kb / 1048576

    t.add_row("Total:", Text(f"{total_gib:.1f} GiB", style=FG))

    # Used with bar
    used_text = Text()
    used_text.append(f"{used_gib:.1f} GiB  ", style=ORANGE)
    used_text.append_text(make_bar(mem.used_kb, mem.total_kb, 9, ORANGE))
    t.add_row("Used:", used_text)

    t.add_row("Buffers:", Text(f"{buffers_gib:.1f} GiB", style=BLUE))
    t.add_row("Cached:", Text(f"{cached_gib:.1f} GiB", style=AQUA))
    t.add_row("Available:", Text(f"{available_gib:.1f} GiB", style=GREEN))
    t.add_row("Swap:", Text(f"{swap_used_gib:.1f} / {swap_total_gib:.1f} GiB", style=PURPLE))

    return Panel(t, title="Memory", border_style=BLUE, padding=(0, 1))


def render_zram(zram: ZramData) -> Panel:
    """Render the ZRAM panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=8)
    t.add_column()

    t.add_row("Orig:", Text(fmt_bytes(zram.orig_bytes), style=FG))

    compr_text = Text()
    compr_text.append(fmt_bytes(zram.compr_bytes), style=AQUA)
    if zram.ratio > 0:
        compr_text.append(f"   Ratio: {zram.ratio:.2f}x", style=GREEN)
    t.add_row("Compr:", compr_text)

    t.add_row("Algo:", Text(zram.algo or "N/A", style=PURPLE))

    return Panel(t, title="ZRAM", border_style=PURPLE, padding=(0, 1))


def render_footer() -> Text:
    """Render the bottom status bar."""
    ft = Text(justify="center")
    ft.append("  q ", style=f"bold {FG}")
    ft.append("quit", style=FG_DIM)
    ft.append("  ", style=FG_DIM)
    spacer = " " * 50
    ft.append(spacer, style=FG_DIM)
    ft.append("↻ 1.5s  ", style=FG_DIM)
    return ft


# ── Layout builder ─────────────────────────────────────────────────────


def build_layout(
    cpu: CpuData,
    sched: SchedData,
    thermals: ThermalData,
    mem: MemoryData,
    zram: ZramData,
) -> Layout:
    """Assemble the full dashboard layout."""
    layout = Layout()

    # Main split: body + footer
    layout.split_column(
        Layout(name="body", ratio=1),
        Layout(name="footer", size=1),
    )

    # Body: CPU panel on top, bottom section below
    layout["body"].split_column(
        Layout(name="cpu", ratio=5),
        Layout(name="bottom", ratio=4),
    )

    # Bottom: left column (scheduler + memory + zram) | right column (thermals)
    layout["bottom"].split_row(
        Layout(name="bottom_left", ratio=1),
        Layout(name="bottom_right", ratio=1),
    )

    # Bottom-left: scheduler, memory, zram stacked
    layout["bottom_left"].split_column(
        Layout(name="scheduler", ratio=2),
        Layout(name="memory", ratio=3),
        Layout(name="zram", ratio=2),
    )

    # Populate panels
    layout["cpu"].update(render_cpu(cpu))
    layout["scheduler"].update(render_scheduler(sched))
    layout["bottom_right"].update(render_thermals(thermals))
    layout["memory"].update(render_memory(mem))
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
                    last_data_time = now

                    cpu = read_cpu()
                    sched = read_scheduler()
                    thermals = read_thermals(hwmon)
                    mem = read_memory()
                    zram = read_zram()

                    layout = build_layout(cpu, sched, thermals, mem, zram)
                    live.update(layout)

    finally:
        restore_terminal()


if __name__ == "__main__":
    main()
