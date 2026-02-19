#!/usr/bin/python3
"""Network monitoring TUI dashboard for Framework 13 AMD.

Opens in kitty via waybar network click. Shows live-updating WiFi,
connection, bandwidth, and interface stats with sparkline graphs.
"""

import re
import select
import signal
import subprocess
import sys
import termios
import time
import tty
from collections import deque
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

IFACE = "wlan0"
HISTORY_LEN = 20
SPARKLINE_CHARS = "▁▂▃▄▅▆▇█"


# ── sysfs / procfs helpers ─────────────────────────────────────────────

def sysfs_read(path: str, default: str = "") -> str:
    """Read a sysfs/procfs file, returning default on any error."""
    try:
        return Path(path).read_text().strip()
    except (OSError, ValueError):
        return default


def run_cmd(cmd: list[str], timeout: float = 2.0) -> str:
    """Run a subprocess and return stdout, or empty string on failure."""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
        )
        return result.stdout
    except (subprocess.SubprocessError, FileNotFoundError):
        return ""


# ── Frequency to channel mapping ──────────────────────────────────────

def freq_to_channel(freq_mhz: int) -> int:
    """Convert WiFi frequency in MHz to channel number."""
    if 2412 <= freq_mhz <= 2484:
        if freq_mhz == 2484:
            return 14
        return (freq_mhz - 2407) // 5
    if 5170 <= freq_mhz <= 5835:
        return (freq_mhz - 5000) // 5
    if 5955 <= freq_mhz <= 7115:
        return (freq_mhz - 5950) // 5
    return 0


# ── Data classes ───────────────────────────────────────────────────────

@dataclass
class WiFiData:
    connected: bool = False
    ssid: str = ""
    bssid: str = ""
    signal_dbm: int = -100
    freq_mhz: int = 0
    channel: int = 0
    width_mhz: int = 0
    tx_rate: str = ""
    rx_rate: str = ""
    mode: str = ""  # HE (WiFi 6), VHT (WiFi 5), HT (WiFi 4)
    mac: str = ""
    iface_type: str = ""
    wiphy: int = 0


@dataclass
class ConnectionData:
    ip_addr: str = ""
    prefix_len: int = 0
    gateway: str = ""
    dns_label: str = ""
    mtu: int = 0


@dataclass
class BandwidthData:
    rx_bytes: int = 0
    tx_bytes: int = 0
    rx_rate: float = 0.0  # bytes/s
    tx_rate: float = 0.0
    total_rx: int = 0
    total_tx: int = 0


@dataclass
class ConnectionCount:
    tcp_established: int = 0
    udp: int = 0

    @property
    def total(self) -> int:
        return self.tcp_established + self.udp


@dataclass
class InterfaceData:
    driver: str = ""
    state: str = ""
    iface_type: str = ""
    wiphy: int = 0


# ── Readers ────────────────────────────────────────────────────────────

def read_wifi() -> WiFiData:
    """Parse WiFi info from iw commands."""
    data = WiFiData()

    # iw dev wlan0 link — connection details
    link_out = run_cmd(["iw", "dev", IFACE, "link"])
    if not link_out or "Not connected" in link_out:
        return data

    data.connected = True

    # BSSID: "Connected to XX:XX:XX:XX:XX:XX"
    m = re.search(r"Connected to\s+([0-9a-fA-F:]{17})", link_out)
    if m:
        data.bssid = m.group(1).lower()

    # SSID
    m = re.search(r"SSID:\s+(.+)", link_out)
    if m:
        data.ssid = m.group(1).strip()

    # Frequency from link output
    m = re.search(r"freq:\s+([\d.]+)", link_out)
    if m:
        data.freq_mhz = int(float(m.group(1)))

    # Signal
    m = re.search(r"signal:\s+(-?\d+)\s+dBm", link_out)
    if m:
        data.signal_dbm = int(m.group(1))

    # TX bitrate and mode detection
    m = re.search(r"tx bitrate:\s+(.+)", link_out)
    if m:
        line = m.group(1).strip()
        rate_m = re.match(r"([\d.]+)\s+MBit/s", line)
        data.tx_rate = f"{rate_m.group(1)} Mbit/s" if rate_m else line.split()[0]
        if "HE-" in line:
            data.mode = "HE (WiFi 6)"
        elif "VHT-" in line:
            data.mode = "VHT (WiFi 5)"
        elif "HT-" in line or "MCS" in line:
            data.mode = "HT (WiFi 4)"
        else:
            data.mode = "Legacy"

    # RX bitrate
    m = re.search(r"rx bitrate:\s+(.+)", link_out)
    if m:
        line = m.group(1).strip()
        rate_m = re.match(r"([\d.]+)\s+MBit/s", line)
        data.rx_rate = f"{rate_m.group(1)} Mbit/s" if rate_m else line.split()[0]

    # iw dev wlan0 info — channel, width, mac, type, wiphy
    info_out = run_cmd(["iw", "dev", IFACE, "info"])

    # Channel and width: "channel 157 (5785 MHz), width: 80 MHz"
    m = re.search(
        r"channel\s+(\d+)\s+\((\d+)\s+MHz\),\s+width:\s+(\d+)\s+MHz",
        info_out,
    )
    if m:
        data.channel = int(m.group(1))
        if data.freq_mhz == 0:
            data.freq_mhz = int(m.group(2))
        data.width_mhz = int(m.group(3))
    elif data.freq_mhz > 0:
        data.channel = freq_to_channel(data.freq_mhz)

    # MAC address
    m = re.search(r"addr\s+([0-9a-fA-F:]{17})", info_out)
    if m:
        data.mac = m.group(1).lower()

    # Type (managed, etc.)
    m = re.search(r"type\s+(\S+)", info_out)
    if m:
        data.iface_type = m.group(1)

    # Wiphy
    m = re.search(r"wiphy\s+(\d+)", info_out)
    if m:
        data.wiphy = int(m.group(1))

    return data


def read_connection() -> ConnectionData:
    """Read IP, gateway, DNS, MTU."""
    data = ConnectionData()

    # IP address: "inet 192.168.4.54/24 ..."
    ip_out = run_cmd(["ip", "-4", "addr", "show", IFACE])
    m = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)/(\d+)", ip_out)
    if m:
        data.ip_addr = m.group(1)
        data.prefix_len = int(m.group(2))

    # Gateway: "default via 192.168.4.1 ..."
    route_out = run_cmd(["ip", "route", "show", "default", "dev", IFACE])
    m = re.search(r"default via\s+(\d+\.\d+\.\d+\.\d+)", route_out)
    if m:
        data.gateway = m.group(1)

    # DNS: check /etc/resolv.conf
    try:
        resolv = Path("/etc/resolv.conf").read_text().lower()
        if "nextdns" in resolv:
            data.dns_label = "NextDNS"
        else:
            # Extract nameserver IPs
            servers = re.findall(
                r"nameserver\s+(\d+\.\d+\.\d+\.\d+)", resolv,
            )
            data.dns_label = ", ".join(servers[:2]) if servers else "Unknown"
    except OSError:
        data.dns_label = "Unknown"

    # MTU
    mtu_str = sysfs_read(f"/sys/class/net/{IFACE}/mtu")
    if mtu_str.isdigit():
        data.mtu = int(mtu_str)

    return data


class BandwidthTracker:
    """Track bandwidth by reading /proc/net/dev periodically."""

    def __init__(self) -> None:
        self.prev_rx: int = 0
        self.prev_tx: int = 0
        self.prev_time: float = 0.0
        self.rx_history: deque[float] = deque(maxlen=HISTORY_LEN)
        self.tx_history: deque[float] = deque(maxlen=HISTORY_LEN)
        self.initialized: bool = False

    def update(self) -> BandwidthData:
        """Read /proc/net/dev and compute rates."""
        data = BandwidthData()
        try:
            content = Path("/proc/net/dev").read_text()
        except OSError:
            return data

        for line in content.splitlines():
            line = line.strip()
            if not line.startswith(f"{IFACE}:"):
                continue
            # Format: "wlan0: rx_bytes rx_packets ... tx_bytes tx_packets ..."
            parts = line.split(":", 1)[1].split()
            if len(parts) < 16:
                break
            rx_bytes = int(parts[0])
            tx_bytes = int(parts[8])
            data.total_rx = rx_bytes
            data.total_tx = tx_bytes

            now = time.monotonic()
            if self.initialized and self.prev_time > 0:
                dt = now - self.prev_time
                if dt > 0:
                    rx_rate = (rx_bytes - self.prev_rx) / dt
                    tx_rate = (tx_bytes - self.prev_tx) / dt
                    # Clamp negative values (counter reset)
                    data.rx_rate = max(rx_rate, 0.0)
                    data.tx_rate = max(tx_rate, 0.0)
                    self.rx_history.append(data.rx_rate)
                    self.tx_history.append(data.tx_rate)

            self.prev_rx = rx_bytes
            self.prev_tx = tx_bytes
            self.prev_time = now
            self.initialized = True
            break

        return data


def read_connections() -> ConnectionCount:
    """Count TCP established and UDP connections from /proc/net."""
    data = ConnectionCount()

    # TCP established (state 01)
    for path in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            lines = Path(path).read_text().splitlines()
            for line in lines[1:]:  # skip header
                fields = line.split()
                if len(fields) >= 4 and fields[3] == "01":
                    data.tcp_established += 1
        except OSError:
            pass

    # UDP (just count active entries)
    for path in ("/proc/net/udp", "/proc/net/udp6"):
        try:
            lines = Path(path).read_text().splitlines()
            data.udp += max(len(lines) - 1, 0)  # minus header
        except OSError:
            pass

    return data


def read_interface(wifi: WiFiData) -> InterfaceData:
    """Read interface details from sysfs."""
    data = InterfaceData()

    # Driver: follow symlink
    driver_link = Path(f"/sys/class/net/{IFACE}/device/driver")
    try:
        data.driver = driver_link.resolve().name
    except OSError:
        data.driver = "unknown"

    # Operstate
    data.state = sysfs_read(f"/sys/class/net/{IFACE}/operstate", "unknown").upper()

    # Type and wiphy from WiFi data (already parsed from iw)
    data.iface_type = wifi.iface_type or "unknown"
    data.wiphy = wifi.wiphy

    return data


# ── Signal quality ─────────────────────────────────────────────────────

def signal_quality(dbm: int) -> tuple[float, str, str]:
    """Return (quality_0_to_1, label, color) for signal strength."""
    if dbm >= -30:
        return 1.0, "Excellent", GREEN
    if dbm >= -50:
        return 0.8, "Very Good", GREEN
    if dbm >= -60:
        return 0.65, "Good", AQUA
    if dbm >= -70:
        return 0.45, "Fair", YELLOW
    if dbm >= -80:
        return 0.25, "Weak", ORANGE
    return 0.1, "Poor", RED


def make_signal_bar(dbm: int, width: int = 10) -> Text:
    """Create a colored signal bar from dBm value."""
    quality, _label, color = signal_quality(dbm)
    filled = max(int(quality * width), 0)
    bar = Text()
    bar.append("█" * filled, style=color)
    bar.append("░" * (width - filled), style=FG_DIM)
    return bar


# ── Sparkline ──────────────────────────────────────────────────────────

def sparkline(values: deque[float], width: int = 20) -> str:
    """Generate a sparkline string from a deque of float values."""
    if not values:
        return SPARKLINE_CHARS[0] * width

    # Pad with zeros on the left if fewer than width values
    padded = [0.0] * max(width - len(values), 0) + list(values)
    # Take the last `width` values
    padded = padded[-width:]

    max_val = max(padded) if padded else 1.0
    if max_val <= 0:
        return SPARKLINE_CHARS[0] * width

    result = []
    for v in padded:
        idx = int((v / max_val) * (len(SPARKLINE_CHARS) - 1))
        idx = min(idx, len(SPARKLINE_CHARS) - 1)
        result.append(SPARKLINE_CHARS[idx])
    return "".join(result)


# ── Human-readable byte formatting ────────────────────────────────────

def fmt_bytes(b: float, suffix: str = "") -> str:
    """Format bytes to human-readable string."""
    if b < 0:
        b = 0.0
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(b) < 1024:
            if unit == "B":
                return f"{b:.0f} {unit}{suffix}"
            return f"{b:.2f} {unit}{suffix}"
        b /= 1024
    return f"{b:.2f} PB{suffix}"


def fmt_rate(bps: float) -> str:
    """Format bytes/s to human-readable rate."""
    return fmt_bytes(bps, "/s")


# ── Renderers ──────────────────────────────────────────────────────────

def render_wifi(wifi: WiFiData) -> Panel:
    """Render the WiFi panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column(min_width=24)

    if not wifi.connected:
        t.add_row("Status:", Text("Disconnected", style=f"bold {RED}"))
        return Panel(t, title="WiFi", border_style=RED, padding=(0, 1))

    t.add_row("SSID:", Text(wifi.ssid, style=f"bold {FG}"))
    t.add_row("BSSID:", Text(wifi.bssid, style=FG_DIM))

    # Signal with bar
    _quality, label, color = signal_quality(wifi.signal_dbm)
    sig_text = Text()
    sig_text.append(f"{wifi.signal_dbm} dBm  ", style=f"bold {color}")
    sig_text.append_text(make_signal_bar(wifi.signal_dbm))
    t.add_row("Signal:", sig_text)

    # Frequency and channel
    freq_str = f"{wifi.freq_mhz} MHz"
    if wifi.channel > 0:
        freq_str += f" (ch {wifi.channel})"
    t.add_row("Freq:", Text(freq_str, style=BLUE))

    # Channel width
    if wifi.width_mhz > 0:
        t.add_row("Width:", Text(f"{wifi.width_mhz} MHz", style=FG))

    # TX/RX rates
    if wifi.tx_rate:
        t.add_row("TX Rate:", Text(wifi.tx_rate, style=AQUA))
    if wifi.rx_rate:
        t.add_row("RX Rate:", Text(wifi.rx_rate, style=AQUA))

    # WiFi mode
    if wifi.mode:
        t.add_row("Mode:", Text(wifi.mode, style=PURPLE))

    return Panel(t, title="WiFi", border_style=BLUE, padding=(0, 1))


def render_connection(conn: ConnectionData, wifi: WiFiData) -> Panel:
    """Render the Connection panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column(min_width=24)

    if not wifi.connected:
        t.add_row("Status:", Text("No connection", style=f"bold {RED}"))
        return Panel(t, title="Connection", border_style=RED, padding=(0, 1))

    ip_str = conn.ip_addr
    if conn.prefix_len > 0:
        ip_str += f"/{conn.prefix_len}"
    t.add_row("IP:", Text(ip_str, style=f"bold {FG}"))
    t.add_row("Gateway:", Text(conn.gateway or "—", style=FG))
    t.add_row("DNS:", Text(conn.dns_label or "—", style=AQUA))
    t.add_row("MAC:", Text(wifi.mac or "—", style=FG_DIM))
    t.add_row("MTU:", Text(str(conn.mtu) if conn.mtu else "—", style=FG_DIM))

    return Panel(t, title="Connection", border_style=GREEN, padding=(0, 1))


def render_bandwidth(
    bw: BandwidthData,
    rx_history: deque[float],
    tx_history: deque[float],
) -> Panel:
    """Render the Bandwidth panel with sparklines."""
    t = Table.grid(padding=(0, 1))
    t.add_column(min_width=34)

    # Current rates
    rx_text = Text()
    rx_text.append("  ↓ RX:  ", style=FG_DIM)
    rx_text.append(fmt_rate(bw.rx_rate), style=f"bold {GREEN}")
    t.add_row(rx_text)

    tx_text = Text()
    tx_text.append("  ↑ TX:  ", style=FG_DIM)
    tx_text.append(fmt_rate(bw.tx_rate), style=f"bold {ORANGE}")
    t.add_row(tx_text)

    t.add_row(Text(""))

    # Totals
    total_rx = Text()
    total_rx.append("  Total RX: ", style=FG_DIM)
    total_rx.append(fmt_bytes(bw.total_rx), style=FG)
    t.add_row(total_rx)

    total_tx = Text()
    total_tx.append("  Total TX: ", style=FG_DIM)
    total_tx.append(fmt_bytes(bw.total_tx), style=FG)
    t.add_row(total_tx)

    t.add_row(Text(""))

    # Sparklines
    rx_spark = Text()
    rx_spark.append("  ", style=FG_DIM)
    rx_spark.append(sparkline(rx_history), style=GREEN)
    rx_spark.append(" RX", style=FG_DIM)
    t.add_row(rx_spark)

    tx_spark = Text()
    tx_spark.append("  ", style=FG_DIM)
    tx_spark.append(sparkline(tx_history), style=ORANGE)
    tx_spark.append(" TX", style=FG_DIM)
    t.add_row(tx_spark)

    return Panel(t, title="Bandwidth", border_style=YELLOW, padding=(0, 1))


def render_connections(counts: ConnectionCount) -> Panel:
    """Render the Connections count panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=16)
    t.add_column(min_width=6, justify="right")

    t.add_row("TCP established:", Text(str(counts.tcp_established), style=BLUE))
    t.add_row("UDP:", Text(str(counts.udp), style=AQUA))
    t.add_row("Total:", Text(str(counts.total), style=f"bold {FG}"))

    return Panel(t, title="Connections", border_style=AQUA, padding=(0, 1))


def render_interface(iface: InterfaceData) -> Panel:
    """Render the Interface panel."""
    t = Table.grid(padding=(0, 1))
    t.add_column(style=FG_DIM, min_width=10)
    t.add_column(min_width=14)

    state_color = GREEN if iface.state == "UP" else RED
    t.add_row("Driver:", Text(iface.driver, style=PURPLE))
    t.add_row("State:", Text(iface.state, style=f"bold {state_color}"))
    t.add_row("Type:", Text(iface.iface_type, style=FG))
    t.add_row("Wiphy:", Text(str(iface.wiphy), style=FG_DIM))

    return Panel(t, title="Interface", border_style=PURPLE, padding=(0, 1))


def render_footer() -> Text:
    """Render the footer bar."""
    ft = Text(justify="center")
    ft.append("  q ", style=f"bold {FG}")
    ft.append("quit", style=FG_DIM)
    ft.append("  ", style=FG_DIM)
    # Right-aligned refresh indicator
    ft.append(" " * 40, style=FG_DIM)
    ft.append("↻ 1.0s", style=FG_DIM)
    return ft


# ── Layout builder ─────────────────────────────────────────────────────

def build_layout(
    wifi: WiFiData,
    conn: ConnectionData,
    bw: BandwidthData,
    rx_history: deque[float],
    tx_history: deque[float],
    counts: ConnectionCount,
    iface: InterfaceData,
) -> Layout:
    """Build the full dashboard layout."""
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

    # Left column: WiFi on top, Bandwidth on bottom
    layout["left"].split_column(
        Layout(name="wifi", ratio=1),
        Layout(name="bandwidth", ratio=1),
    )

    # Right column: Connection on top, Connections + Interface on bottom
    layout["right"].split_column(
        Layout(name="connection", ratio=1),
        Layout(name="right_bottom", ratio=1),
    )

    # Right bottom: Connections and Interface stacked
    layout["right_bottom"].split_column(
        Layout(name="connections", ratio=1),
        Layout(name="interface", ratio=1),
    )

    # Populate panels
    layout["wifi"].update(render_wifi(wifi))
    layout["connection"].update(render_connection(conn, wifi))
    layout["bandwidth"].update(render_bandwidth(bw, rx_history, tx_history))
    layout["connections"].update(render_connections(counts))
    layout["interface"].update(render_interface(iface))
    layout["footer"].update(render_footer())

    return layout


# ── Main ───────────────────────────────────────────────────────────────

def main() -> None:
    console = Console()
    bw_tracker = BandwidthTracker()

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

                # Refresh data every 1.0s
                now = time.monotonic()
                if now - last_data_time >= 1.0:
                    last_data_time = now

                    wifi = read_wifi()
                    conn = read_connection()
                    bw = bw_tracker.update()
                    counts = read_connections()
                    iface = read_interface(wifi)

                    layout = build_layout(
                        wifi, conn, bw,
                        bw_tracker.rx_history,
                        bw_tracker.tx_history,
                        counts, iface,
                    )
                    live.update(layout)

    finally:
        restore_terminal()


if __name__ == "__main__":
    main()
