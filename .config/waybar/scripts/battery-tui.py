#!/usr/bin/python3
"""Battery power TUI dashboard for Framework 13 AMD.

Opens in kitty via waybar battery pill click. Shows live-updating
battery, thermal, CPU, GPU stats with power profile switching.
"""

import signal
import select
import subprocess
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

CHARGE_LIMIT = 80  # Framework BIOS charge limit

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
    """Map hwmon name -> path (e.g. 'cros_ec' -> '/sys/class/hwmon/hwmon8')."""
    mapping = {}
    hwmon_base = Path("/sys/class/hwmon")
    if not hwmon_base.exists():
        return mapping
    for d in sorted(hwmon_base.iterdir()):
        name_file = d / "name"
        if name_file.exists():
            name = name_file.read_text().strip()
            # For spd5118 (two DIMMs), store as list under same key
            if name in mapping:
                existing = mapping[name]
                if isinstance(existing, list):
                    existing.append(str(d))
                else:
                    mapping[name] = [existing, str(d)]
            else:
                mapping[name] = str(d)
    return mapping


# ── Data classes ───────────────────────────────────────────────────────

@dataclass
class BatteryData:
    raw_pct: int = 0
    eff_pct: int = 0
    status: str = "Unknown"
    charge_now_uah: int = 0
    charge_full_uah: int = 0
    charge_design_uah: int = 0
    current_now_ua: int = 0
    voltage_now_uv: int = 0
    cycle_count: int = 0
    ac_online: bool = False

    @property
    def power_w(self) -> float:
        return (self.current_now_ua * self.voltage_now_uv) / 1e12

    @property
    def energy_now_wh(self) -> float:
        return (self.charge_now_uah * self.voltage_now_uv) / 1e12

    @property
    def energy_full_wh(self) -> float:
        return (self.charge_full_uah * self.voltage_now_uv) / 1e12

    @property
    def energy_design_wh(self) -> float:
        return (self.charge_design_uah * self.voltage_now_uv) / 1e12

    @property
    def health_pct(self) -> float:
        if self.charge_design_uah == 0:
            return 0.0
        return (self.charge_full_uah / self.charge_design_uah) * 100

    @property
    def voltage_v(self) -> float:
        return self.voltage_now_uv / 1e6

    @property
    def time_remaining_min(self) -> int | None:
        if self.current_now_ua <= 0:
            return None
        if self.status == "Discharging":
            return int((self.charge_now_uah / self.current_now_ua) * 60)
        elif self.status == "Charging":
            target = self.charge_full_uah * CHARGE_LIMIT // 100
            remaining = target - self.charge_now_uah
            if remaining <= 0:
                return 0
            return int((remaining / self.current_now_ua) * 60)
        return None


@dataclass
class ThermalData:
    cpu_ec: int = 0      # cros_ec temp2 (cpu_f75303@4d) in milli-C
    ambient: int = 0     # cros_ec temp1 (local_f75303@4d)
    ddr: int = 0         # cros_ec temp3 (ddr_f75303@4d)
    gpu: int = 0         # amdgpu temp1
    nvme: int = 0        # nvme temp1
    ram1: int = 0        # spd5118 DIMM 1
    ram2: int = 0        # spd5118 DIMM 2
    fan_rpm: int = 0     # cros_ec fan1


@dataclass
class CpuData:
    driver: str = ""
    governor: str = ""
    epp: str = ""
    boost: bool = False
    avg_freq_mhz: int = 0


@dataclass
class GpuData:
    power_w: float = 0.0
    shader_mhz: int = 0
    dpm_level: str = ""


# ── Readers ────────────────────────────────────────────────────────────

BAT = "/sys/class/power_supply/BAT1"
ACAD = "/sys/class/power_supply/ACAD"


def read_battery() -> BatteryData:
    raw_pct = sysfs_int(f"{BAT}/capacity")
    eff_pct = min(raw_pct * 100 // CHARGE_LIMIT, 100)
    return BatteryData(
        raw_pct=raw_pct,
        eff_pct=eff_pct,
        status=sysfs_read(f"{BAT}/status", "Unknown"),
        charge_now_uah=sysfs_int(f"{BAT}/charge_now"),
        charge_full_uah=sysfs_int(f"{BAT}/charge_full"),
        charge_design_uah=sysfs_int(f"{BAT}/charge_full_design"),
        current_now_ua=sysfs_int(f"{BAT}/current_now"),
        voltage_now_uv=sysfs_int(f"{BAT}/voltage_now"),
        cycle_count=sysfs_int(f"{BAT}/cycle_count"),
        ac_online=sysfs_read(f"{ACAD}/online") == "1",
    )


def read_thermals(hwmon: dict[str, str]) -> ThermalData:
    data = ThermalData()
    cros = hwmon.get("cros_ec", "")
    if cros:
        data.cpu_ec = sysfs_int(f"{cros}/temp2_input")
        data.ambient = sysfs_int(f"{cros}/temp1_input")
        data.ddr = sysfs_int(f"{cros}/temp3_input")
        data.fan_rpm = sysfs_int(f"{cros}/fan1_input")

    gpu_path = hwmon.get("amdgpu", "")
    if gpu_path:
        data.gpu = sysfs_int(f"{gpu_path}/temp1_input")

    nvme_path = hwmon.get("nvme", "")
    if nvme_path:
        data.nvme = sysfs_int(f"{nvme_path}/temp1_input")

    spd = hwmon.get("spd5118", [])
    if isinstance(spd, list) and len(spd) >= 2:
        data.ram1 = sysfs_int(f"{spd[0]}/temp1_input")
        data.ram2 = sysfs_int(f"{spd[1]}/temp1_input")
    elif isinstance(spd, str):
        data.ram1 = sysfs_int(f"{spd}/temp1_input")

    return data


def read_cpu() -> CpuData:
    cpu0 = "/sys/devices/system/cpu/cpu0/cpufreq"
    # Average frequency across all cores
    total_freq = 0
    count = 0
    for i in range(16):
        freq = sysfs_int(f"/sys/devices/system/cpu/cpu{i}/cpufreq/scaling_cur_freq")
        if freq > 0:
            total_freq += freq
            count += 1
    avg_mhz = (total_freq // count // 1000) if count > 0 else 0

    return CpuData(
        driver=sysfs_read(f"{cpu0}/scaling_driver"),
        governor=sysfs_read(f"{cpu0}/scaling_governor"),
        epp=sysfs_read(f"{cpu0}/energy_performance_preference"),
        boost=sysfs_read("/sys/devices/system/cpu/cpufreq/boost") == "1",
        avg_freq_mhz=avg_mhz,
    )


def read_gpu(hwmon: dict[str, str]) -> GpuData:
    gpu_path = hwmon.get("amdgpu", "")
    power_uw = sysfs_int(f"{gpu_path}/power1_average") if gpu_path else 0

    # Active shader clock from pp_dpm_sclk (line with *)
    shader_mhz = 0
    sclk_path = "/sys/class/drm/card1/device/pp_dpm_sclk"
    try:
        for line in Path(sclk_path).read_text().splitlines():
            if "*" in line:
                # Format: "0: 800Mhz *"
                parts = line.split()
                if len(parts) >= 2:
                    shader_mhz = int(parts[1].rstrip("Mhz"))
                break
    except (OSError, ValueError):
        pass

    dpm = sysfs_read("/sys/class/drm/card1/device/power_dpm_force_performance_level")

    return GpuData(
        power_w=power_uw / 1e6,
        shader_mhz=shader_mhz,
        dpm_level=dpm,
    )


def read_power_profile() -> str:
    try:
        return subprocess.run(
            ["powerprofilesctl", "get"],
            capture_output=True, text=True, timeout=2,
        ).stdout.strip()
    except (subprocess.SubprocessError, FileNotFoundError):
        return "unknown"


def read_brightness() -> tuple[int, int]:
    bl = "/sys/class/backlight/amdgpu_bl1"
    return sysfs_int(f"{bl}/brightness"), sysfs_int(f"{bl}/max_brightness", 1)


# ── Bar helpers ────────────────────────────────────────────────────────

def make_bar(value: int, max_val: int, width: int = 12, color: str = GREEN) -> Text:
    """Create a colored progress bar."""
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
    if temp_c >= 85:
        return RED
    if temp_c >= 70:
        return ORANGE
    if temp_c >= 55:
        return YELLOW
    return GREEN


def temp_bar(temp_mc: int, max_c: int = 100, width: int = 9) -> Text:
    """Temperature bar (input in milli-Celsius)."""
    temp_c = temp_mc / 1000
    color = temp_color(temp_c)
    return make_bar(int(temp_c), max_c, width, color)


def format_time(minutes: int | None) -> str:
    if minutes is None:
        return "—"
    h, m = divmod(minutes, 60)
    return f"{h}h {m:02d}m"


# ── Renderers ──────────────────────────────────────────────────────────

def render_battery(bat: BatteryData) -> Panel:
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=12)
    t.add_column(min_width=20)

    # Status color
    if bat.status == "Charging":
        sc = GREEN
    elif bat.status == "Discharging":
        sc = ORANGE
    elif bat.status in ("Full", "Not charging"):
        sc = AQUA
    else:
        sc = FG

    # Effective % bar
    if bat.eff_pct <= 15:
        pct_color = RED
    elif bat.eff_pct <= 30:
        pct_color = YELLOW
    else:
        pct_color = GREEN

    eff_text = Text()
    eff_text.append(f"{bat.eff_pct}%  ", style=f"bold {pct_color}")
    eff_text.append_text(make_bar(bat.eff_pct, 100, 15, pct_color))
    t.add_row("Effective:", eff_text)
    t.add_row("Raw:", Text(f"{bat.raw_pct}%", style=FG_DIM))
    t.add_row("State:", Text(bat.status, style=f"bold {sc}"))
    t.add_row("Power:", Text(f"{bat.power_w:.1f} W", style=ORANGE if bat.status == "Discharging" else GREEN))
    t.add_row("Time Left:", Text(format_time(bat.time_remaining_min), style=FG))
    t.add_row("Energy:", Text(f"{bat.energy_now_wh:.1f} / {bat.energy_full_wh:.1f} Wh", style=FG))
    t.add_row("Design:", Text(f"{bat.energy_design_wh:.1f} Wh", style=FG_DIM))

    health_color = GREEN if bat.health_pct >= 80 else YELLOW if bat.health_pct >= 60 else RED
    t.add_row("Health:", Text(f"{bat.health_pct:.1f}%  Cycles: {bat.cycle_count}", style=health_color))
    t.add_row("Voltage:", Text(f"{bat.voltage_v:.2f} V", style=FG_DIM))

    return Panel(t, title="Battery", border_style=ORANGE, padding=(0, 1))


def render_profile(profile: str) -> Panel:
    profiles = ["performance", "balanced", "power-saver"]
    t = Table.grid(padding=(0, 1))
    t.add_column(min_width=2)
    t.add_column()

    for i, p in enumerate(profiles, 1):
        active = p == profile
        marker = "●" if active else "○"
        label = f"[{i}] {marker} {p}"
        suffix = "  ◀ active" if active else ""
        color = GREEN if active else FG_DIM
        t.add_row("", Text(f"{label}{suffix}", style=f"bold {color}" if active else color))

    return Panel(t, title="Power Profile", border_style=BLUE, padding=(0, 1))


def render_brightness(cur: int, max_val: int) -> Panel:
    pct = int(cur * 100 / max_val) if max_val > 0 else 0
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=12)
    t.add_column()

    bright_text = Text()
    bright_text.append(f"{pct}%  ", style=YELLOW)
    bright_text.append_text(make_bar(pct, 100, 12, YELLOW))
    t.add_row("Brightness:", bright_text)

    return Panel(t, title="Display", border_style=YELLOW, padding=(0, 1))


def render_thermals(th: ThermalData) -> Panel:
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column(min_width=8, justify="right")
    t.add_column(min_width=11)

    sensors = [
        ("CPU (EC)", th.cpu_ec),
        ("Ambient", th.ambient),
        ("DDR", th.ddr),
        ("GPU", th.gpu),
        ("NVMe", th.nvme),
        ("RAM 1", th.ram1),
        ("RAM 2", th.ram2),
    ]

    for name, val_mc in sensors:
        temp_c = val_mc / 1000
        if val_mc == 0:
            t.add_row(f"{name}:", Text("N/A", style=FG_DIM), Text(""))
        else:
            color = temp_color(temp_c)
            t.add_row(
                f"{name}:",
                Text(f"{temp_c:.0f}°C", style=color),
                temp_bar(val_mc),
            )

    # Fan
    if th.fan_rpm > 0:
        fan_color = ORANGE if th.fan_rpm > 5000 else YELLOW if th.fan_rpm > 3000 else GREEN
        t.add_row("Fan:", Text(f"{th.fan_rpm} RPM", style=fan_color), Text(""))
    else:
        t.add_row("Fan:", Text("Off", style=GREEN), Text(""))

    return Panel(t, title="Thermals", border_style=RED, padding=(0, 1))


def render_cpu(cpu: CpuData) -> Panel:
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column()

    t.add_row("Driver:", Text(cpu.driver, style=AQUA))
    t.add_row("Governor:", Text(cpu.governor, style=BLUE))
    t.add_row("EPP:", Text(cpu.epp, style=PURPLE))
    t.add_row("Avg Freq:", Text(f"{cpu.avg_freq_mhz / 1000:.2f} GHz", style=FG))
    t.add_row("Boost:", Text("Enabled" if cpu.boost else "Disabled", style=GREEN if cpu.boost else RED))

    return Panel(t, title="CPU", border_style=AQUA, padding=(0, 1))


def render_gpu(gpu: GpuData) -> Panel:
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column()

    t.add_row("PPT:", Text(f"{gpu.power_w:.1f} W", style=ORANGE))
    t.add_row("Shader:", Text(f"{gpu.shader_mhz} MHz", style=FG))
    t.add_row("DPM:", Text(gpu.dpm_level, style=BLUE))

    return Panel(t, title="GPU (780M)", border_style=PURPLE, padding=(0, 1))


def render_footer() -> Text:
    ft = Text(justify="center")
    ft.append("  q ", style=f"bold {FG}")
    ft.append("quit", style=FG_DIM)
    ft.append("  │  ", style=FG_DIM)
    ft.append("1 ", style=f"bold {FG}")
    ft.append("perf", style=FG_DIM)
    ft.append("  │  ", style=FG_DIM)
    ft.append("2 ", style=f"bold {FG}")
    ft.append("bal", style=FG_DIM)
    ft.append("  │  ", style=FG_DIM)
    ft.append("3 ", style=f"bold {FG}")
    ft.append("saver", style=FG_DIM)
    ft.append("  │  ", style=FG_DIM)
    ft.append("↑↓ ", style=f"bold {FG}")
    ft.append("brightness", style=FG_DIM)
    ft.append("  │  ", style=FG_DIM)
    ft.append("↻ 1.5s", style=FG_DIM)
    return ft


# ── Layout builder ─────────────────────────────────────────────────────

def build_layout(
    bat: BatteryData,
    profile: str,
    thermals: ThermalData,
    cpu: CpuData,
    gpu: GpuData,
    brightness: tuple[int, int],
) -> Layout:
    layout = Layout()

    # Main body + footer
    layout.split_column(
        Layout(name="body", ratio=1),
        Layout(name="footer", size=1),
    )

    # Body: left and right columns
    layout["body"].split_row(
        Layout(name="left", ratio=1),
        Layout(name="right", ratio=1),
    )

    # Left: battery on top, thermals on bottom
    layout["left"].split_column(
        Layout(name="battery", ratio=3),
        Layout(name="thermals", ratio=3),
    )

    # Right: profile + display on top, cpu + gpu on bottom
    layout["right"].split_column(
        Layout(name="right_top", ratio=2),
        Layout(name="right_bottom", ratio=4),
    )

    layout["right_top"].split_column(
        Layout(name="profile", ratio=2),
        Layout(name="display", ratio=1),
    )

    layout["right_bottom"].split_column(
        Layout(name="cpu", ratio=1),
        Layout(name="gpu", ratio=1),
    )

    # Populate
    layout["battery"].update(render_battery(bat))
    layout["thermals"].update(render_thermals(thermals))
    layout["profile"].update(render_profile(profile))
    layout["display"].update(render_brightness(*brightness))
    layout["cpu"].update(render_cpu(cpu))
    layout["gpu"].update(render_gpu(gpu))
    layout["footer"].update(render_footer())

    return layout


# ── Keyboard handling ──────────────────────────────────────────────────

def set_power_profile(name: str) -> bool:
    try:
        result = subprocess.run(
            ["powerprofilesctl", "set", name],
            capture_output=True, text=True, timeout=3,
        )
        return result.returncode == 0
    except (subprocess.SubprocessError, FileNotFoundError):
        return False


def adjust_brightness(step: str) -> None:
    """Adjust brightness via brightnessctl. step e.g. '+5%' or '5%-'."""
    try:
        subprocess.run(
            ["brightnessctl", "set", step],
            capture_output=True, timeout=2,
        )
    except (subprocess.SubprocessError, FileNotFoundError):
        pass


# ── Main ───────────────────────────────────────────────────────────────

def main() -> None:
    console = Console()
    hwmon = discover_hwmon()

    profile_map = {"1": "performance", "2": "balanced", "3": "power-saver"}

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
                    if key == "\x1b":
                        # Could be Escape or start of arrow sequence
                        if select.select([sys.stdin], [], [], 0.05)[0]:
                            seq = sys.stdin.read(1)
                            if seq == "[":
                                arrow = sys.stdin.read(1)
                                if arrow == "A":    # Up arrow
                                    adjust_brightness("+5%")
                                    last_data_time = 0
                                elif arrow == "B":  # Down arrow
                                    adjust_brightness("5%-")
                                    last_data_time = 0
                        else:
                            break  # Bare Escape = quit
                        continue
                    if key in ("q", "Q"):
                        break
                    if key in profile_map:
                        set_power_profile(profile_map[key])
                        last_data_time = 0  # Force immediate refresh

                # Refresh data every 1.5s
                now = time.monotonic()
                if now - last_data_time >= 1.5:
                    last_data_time = now
                    bat = read_battery()
                    profile = read_power_profile()
                    thermals = read_thermals(hwmon)
                    cpu = read_cpu()
                    gpu = read_gpu(hwmon)
                    brightness = read_brightness()

                    layout = build_layout(bat, profile, thermals, cpu, gpu, brightness)
                    live.update(layout)

    finally:
        restore_terminal()


if __name__ == "__main__":
    main()
