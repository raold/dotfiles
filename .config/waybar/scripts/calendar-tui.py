#!/usr/bin/python3
"""Calendar & weather TUI dashboard for Framework 13 AMD.

Opens in kitty via waybar clock pill click. Live-updating calendar
with month navigation, current conditions, hourly and 3-day forecasts.
Weather via Open-Meteo API (free, no key). Location auto-detected via IP.
"""

import calendar
import json
import signal
import select
import sys
import termios
import time
import tty
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta
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

LOCATION_CACHE = "/tmp/waybar-weather-location.json"
WEATHER_INTERVAL = 300  # 5 minutes

# ── WMO weather codes ─────────────────────────────────────────────────
WMO_CODES = {
    0: ("\u2600", "Clear Sky"),
    1: ("\U0001f324", "Mainly Clear"),
    2: ("\u26c5", "Partly Cloudy"),
    3: ("\u2601", "Overcast"),
    45: ("\U0001f32b", "Fog"),
    48: ("\U0001f32b", "Rime Fog"),
    51: ("\U0001f326", "Light Drizzle"),
    53: ("\U0001f326", "Drizzle"),
    55: ("\U0001f327", "Heavy Drizzle"),
    61: ("\U0001f327", "Light Rain"),
    63: ("\U0001f327", "Rain"),
    65: ("\U0001f327", "Heavy Rain"),
    66: ("\U0001f328", "Freezing Rain"),
    67: ("\U0001f328", "Heavy Freezing Rain"),
    71: ("\u2744", "Light Snow"),
    73: ("\u2744", "Snow"),
    75: ("\u2744", "Heavy Snow"),
    77: ("\u2744", "Snow Grains"),
    80: ("\U0001f326", "Light Showers"),
    81: ("\U0001f327", "Showers"),
    82: ("\U0001f327", "Heavy Showers"),
    85: ("\U0001f328", "Light Snow Showers"),
    86: ("\U0001f328", "Snow Showers"),
    95: ("\u26c8", "Thunderstorm"),
    96: ("\u26c8", "Thunderstorm + Hail"),
    99: ("\u26c8", "Heavy Thunderstorm"),
}

# Night variants for clear/partly cloudy
NIGHT_ICONS = {
    0: "\u263e",   # crescent moon
    1: "\u263e",
    2: "\u2601",   # cloud (night partly cloudy)
}


# ── Helpers ────────────────────────────────────────────────────────────

def wind_direction(degrees: float) -> str:
    """Convert wind degrees to compass direction."""
    dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    idx = int((degrees + 22.5) / 45) % 8
    return dirs[idx]


def uv_color(uv: float) -> tuple[str, str]:
    """Return (color, label) for UV index."""
    if uv <= 2:
        return GREEN, "Low"
    if uv <= 5:
        return YELLOW, "Moderate"
    if uv <= 7:
        return ORANGE, "High"
    return RED, "Very High"


def precip_color(pct: float) -> str:
    """Return color for precipitation probability."""
    if pct >= 75:
        return RED
    if pct >= 50:
        return ORANGE
    if pct >= 20:
        return YELLOW
    return GREEN


def wmo_icon(code: int, is_night: bool = False) -> str:
    """Get weather icon for WMO code, with night variants."""
    if is_night and code in NIGHT_ICONS:
        return NIGHT_ICONS[code]
    icon, _ = WMO_CODES.get(code, ("\u2600", "Unknown"))
    return icon


def wmo_desc(code: int) -> str:
    """Get weather description for WMO code."""
    _, desc = WMO_CODES.get(code, ("\u2600", "Unknown"))
    return desc


def fetch_json(url: str, timeout: int = 5) -> dict | None:
    """Fetch JSON from URL, return None on failure."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "waybar-calendar-tui/1.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, OSError, json.JSONDecodeError, ValueError):
        return None


# ── Location ───────────────────────────────────────────────────────────

@dataclass
class Location:
    latitude: float = 0.0
    longitude: float = 0.0
    city: str = ""
    region: str = ""


def get_location() -> Location:
    """Get location from cache or IP geolocation API."""
    cache = Path(LOCATION_CACHE)

    # Try cache first
    if cache.exists():
        try:
            data = json.loads(cache.read_text())
            return Location(
                latitude=data["latitude"],
                longitude=data["longitude"],
                city=data.get("city", ""),
                region=data.get("region", ""),
            )
        except (json.JSONDecodeError, KeyError, OSError):
            pass

    # Primary: ipapi.co
    data = fetch_json("https://ipapi.co/json/", timeout=5)
    if data and "latitude" in data:
        loc = Location(
            latitude=float(data["latitude"]),
            longitude=float(data["longitude"]),
            city=data.get("city", ""),
            region=data.get("region", ""),
        )
        try:
            cache.write_text(json.dumps({
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "city": loc.city,
                "region": loc.region,
            }))
        except OSError:
            pass
        return loc

    # Fallback: ip-api.com
    data = fetch_json("http://ip-api.com/json/", timeout=5)
    if data and "lat" in data:
        loc = Location(
            latitude=float(data["lat"]),
            longitude=float(data["lon"]),
            city=data.get("city", ""),
            region=data.get("regionName", ""),
        )
        try:
            cache.write_text(json.dumps({
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "city": loc.city,
                "region": loc.region,
            }))
        except OSError:
            pass
        return loc

    return Location()


# ── Weather data ───────────────────────────────────────────────────────

@dataclass
class CurrentWeather:
    temp_f: float = 0.0
    feels_f: float = 0.0
    humidity: int = 0
    wind_mph: float = 0.0
    wind_dir_deg: float = 0.0
    uv_index: float = 0.0
    weather_code: int = 0


@dataclass
class HourlyForecast:
    time_str: str = ""     # ISO time string
    temp_f: float = 0.0
    precip_pct: float = 0.0
    weather_code: int = 0


@dataclass
class DailyForecast:
    date_str: str = ""     # ISO date string
    weather_code: int = 0
    high_f: float = 0.0
    low_f: float = 0.0
    precip_pct: float = 0.0


@dataclass
class WeatherData:
    current: CurrentWeather = field(default_factory=CurrentWeather)
    hourly: list[HourlyForecast] = field(default_factory=list)
    daily: list[DailyForecast] = field(default_factory=list)
    sunrise: str = ""      # ISO time for today
    sunset: str = ""       # ISO time for today
    available: bool = False


def fetch_weather(loc: Location) -> WeatherData:
    """Fetch weather from Open-Meteo API."""
    if loc.latitude == 0.0 and loc.longitude == 0.0:
        return WeatherData()

    url = (
        f"https://api.open-meteo.com/v1/forecast?"
        f"latitude={loc.latitude}&longitude={loc.longitude}"
        f"&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
        f"weather_code,wind_speed_10m,wind_direction_10m,uv_index"
        f"&hourly=temperature_2m,precipitation_probability,weather_code"
        f"&daily=weather_code,temperature_2m_max,temperature_2m_min,"
        f"precipitation_probability_max,sunrise,sunset"
        f"&temperature_unit=fahrenheit&wind_speed_unit=mph"
        f"&timezone=auto&forecast_days=4"
    )

    data = fetch_json(url, timeout=5)
    if not data:
        return WeatherData()

    result = WeatherData(available=True)

    # Current conditions
    cur = data.get("current", {})
    result.current = CurrentWeather(
        temp_f=cur.get("temperature_2m", 0.0),
        feels_f=cur.get("apparent_temperature", 0.0),
        humidity=int(cur.get("relative_humidity_2m", 0)),
        wind_mph=cur.get("wind_speed_10m", 0.0),
        wind_dir_deg=cur.get("wind_direction_10m", 0.0),
        uv_index=cur.get("uv_index", 0.0),
        weather_code=int(cur.get("weather_code", 0)),
    )

    # Hourly forecast
    hourly = data.get("hourly", {})
    h_times = hourly.get("time", [])
    h_temps = hourly.get("temperature_2m", [])
    h_precip = hourly.get("precipitation_probability", [])
    h_codes = hourly.get("weather_code", [])

    for i in range(len(h_times)):
        result.hourly.append(HourlyForecast(
            time_str=h_times[i],
            temp_f=h_temps[i] if i < len(h_temps) else 0.0,
            precip_pct=h_precip[i] if i < len(h_precip) else 0.0,
            weather_code=int(h_codes[i]) if i < len(h_codes) else 0,
        ))

    # Daily forecast
    daily = data.get("daily", {})
    d_dates = daily.get("time", [])
    d_codes = daily.get("weather_code", [])
    d_highs = daily.get("temperature_2m_max", [])
    d_lows = daily.get("temperature_2m_min", [])
    d_precip = daily.get("precipitation_probability_max", [])
    d_sunrise = daily.get("sunrise", [])
    d_sunset = daily.get("sunset", [])

    for i in range(len(d_dates)):
        result.daily.append(DailyForecast(
            date_str=d_dates[i],
            weather_code=int(d_codes[i]) if i < len(d_codes) else 0,
            high_f=d_highs[i] if i < len(d_highs) else 0.0,
            low_f=d_lows[i] if i < len(d_lows) else 0.0,
            precip_pct=d_precip[i] if i < len(d_precip) else 0.0,
        ))

    # Today's sunrise/sunset
    if d_sunrise:
        result.sunrise = d_sunrise[0]
    if d_sunset:
        result.sunset = d_sunset[0]

    return result


def is_nighttime(now: datetime, sunrise_str: str, sunset_str: str) -> bool:
    """Check if the current time is between sunset and sunrise (nighttime)."""
    try:
        sunrise = datetime.fromisoformat(sunrise_str)
        sunset = datetime.fromisoformat(sunset_str)
        return now < sunrise or now >= sunset
    except (ValueError, TypeError):
        return False


def is_hour_night(hour_str: str, sunrise_str: str, sunset_str: str) -> bool:
    """Check if a given hour timestamp is nighttime."""
    try:
        hour_dt = datetime.fromisoformat(hour_str)
        sunrise = datetime.fromisoformat(sunrise_str)
        sunset = datetime.fromisoformat(sunset_str)
        return hour_dt < sunrise or hour_dt >= sunset
    except (ValueError, TypeError):
        return False


# ── Renderers ──────────────────────────────────────────────────────────

def render_calendar(month_offset: int) -> Panel:
    """Render the calendar panel for current month + offset."""
    now = datetime.now()

    # Calculate target month
    target_year = now.year
    target_month = now.month + month_offset
    while target_month > 12:
        target_month -= 12
        target_year += 1
    while target_month < 1:
        target_month += 12
        target_year -= 1

    is_current_month = (target_year == now.year and target_month == now.month)

    # Month title
    month_name = calendar.month_name[target_month]
    title_text = Text(f"{month_name} {target_year}", style=f"bold {FG}", justify="center")

    # Calendar grid
    t = Table.grid(padding=(0, 0))
    for _ in range(7):
        t.add_column(min_width=5, justify="right")

    # Day headers (Monday-first)
    headers = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    header_texts = []
    for i, h in enumerate(headers):
        if i == 5:  # Saturday
            header_texts.append(Text(f" {h} ", style=f"bold {BLUE}"))
        elif i == 6:  # Sunday
            header_texts.append(Text(f" {h} ", style=f"bold {RED}"))
        else:
            header_texts.append(Text(f" {h} ", style=f"bold {FG_DIM}"))
    t.add_row(*header_texts)

    # Week rows
    weeks = calendar.monthcalendar(target_year, target_month)
    for week in weeks:
        day_texts = []
        for i, day in enumerate(week):
            if day == 0:
                day_texts.append(Text("     "))
            elif is_current_month and day == now.day:
                day_texts.append(Text(f"[{day:>2}] ", style=f"bold {ORANGE}"))
            elif i == 5:  # Saturday
                day_texts.append(Text(f" {day:>2}  ", style=BLUE))
            elif i == 6:  # Sunday
                day_texts.append(Text(f" {day:>2}  ", style=RED))
            else:
                day_texts.append(Text(f" {day:>2}  ", style=FG))
        t.add_row(*day_texts)

    # Pad to 6 rows so the panel size stays consistent
    for _ in range(6 - len(weeks)):
        t.add_row(*[Text("     ") for _ in range(7)])

    # Navigation hint
    nav = Text(justify="center")
    nav.append("  \u25c0 ", style=FG_DIM)
    nav.append("h/\u2190", style=f"bold {FG}")
    nav.append("  prev", style=FG_DIM)
    nav.append("  \u2502  ", style=FG_DIM)
    nav.append("next  ", style=FG_DIM)
    nav.append("l/\u2192", style=f"bold {FG}")
    nav.append(" \u25b6  ", style=FG_DIM)

    today_hint = Text("t = today", style=FG_DIM, justify="center")

    outer = Table.grid(padding=(0, 0))
    outer.add_column()
    outer.add_row(title_text)
    outer.add_row(Text(""))
    outer.add_row(t)
    outer.add_row(Text(""))
    outer.add_row(nav)
    outer.add_row(today_hint)

    return Panel(outer, title="Calendar", border_style=ORANGE, padding=(0, 1))


def render_now(weather: WeatherData) -> Panel:
    """Render the current time & weather panel."""
    now = datetime.now()

    t = Table.grid(padding=(0, 1))
    t.add_column(min_width=34)

    # Date
    date_str = now.strftime("%A, %B %-d")
    t.add_row(Text(f"  {date_str}", style=f"bold {FG}"))

    # Time
    time_str = now.strftime("%I:%M:%S %p")
    t.add_row(Text(f"  {time_str}", style=f"bold {YELLOW}"))
    t.add_row(Text(""))

    if not weather.available:
        t.add_row(Text("  Weather unavailable", style=FG_DIM))
        for _ in range(6):
            t.add_row(Text(""))
        return Panel(t, title="Now", border_style=BLUE, padding=(0, 1))

    cur = weather.current
    night = is_nighttime(now, weather.sunrise, weather.sunset)
    icon = wmo_icon(cur.weather_code, night)
    desc = wmo_desc(cur.weather_code)

    # Weather icon + description
    t.add_row(Text(f"  {icon}  {desc}", style=f"bold {FG}"))

    # Temperature
    temp_c = (cur.temp_f - 32) * 5 / 9
    feels_c = (cur.feels_f - 32) * 5 / 9
    t.add_row(Text(f"  {cur.temp_f:.0f}\u00b0F ({temp_c:.0f}\u00b0C)  Feels {cur.feels_f:.0f}\u00b0F", style=FG))

    # Humidity
    t.add_row(Text(f"  Humidity: {cur.humidity}%", style=FG))

    # Wind
    wind_dir = wind_direction(cur.wind_dir_deg)
    t.add_row(Text(f"  Wind: {cur.wind_mph:.0f} mph {wind_dir}", style=FG))

    # UV Index
    uv_col, uv_label = uv_color(cur.uv_index)
    uv_text = Text(f"  UV Index: {cur.uv_index:.0f} ", style=FG)
    uv_text.append(f"({uv_label})", style=uv_col)
    t.add_row(uv_text)

    # Sunrise/Sunset
    try:
        sr = datetime.fromisoformat(weather.sunrise)
        ss = datetime.fromisoformat(weather.sunset)
        t.add_row(Text(f"  Sunrise: {sr.strftime('%-I:%M %p')}", style=YELLOW))
        t.add_row(Text(f"  Sunset:  {ss.strftime('%-I:%M %p')}", style=ORANGE))
    except (ValueError, TypeError):
        t.add_row(Text(""))
        t.add_row(Text(""))

    return Panel(t, title="Now", border_style=BLUE, padding=(0, 1))


def render_hourly(weather: WeatherData) -> Panel:
    """Render the hourly forecast panel (next 10 hours)."""
    if not weather.available or not weather.hourly:
        return Panel(
            Text("  Weather unavailable", style=FG_DIM),
            title="Hourly Forecast",
            border_style=AQUA,
            padding=(0, 1),
        )

    now = datetime.now()

    # Find the current hour index in the hourly data
    start_idx = 0
    for i, h in enumerate(weather.hourly):
        try:
            h_dt = datetime.fromisoformat(h.time_str)
            if h_dt >= now.replace(minute=0, second=0, microsecond=0):
                start_idx = i
                break
        except (ValueError, TypeError):
            continue

    # Take next 10 hours
    hours = weather.hourly[start_idx:start_idx + 10]
    if not hours:
        return Panel(
            Text("  No hourly data", style=FG_DIM),
            title="Hourly Forecast",
            border_style=AQUA,
            padding=(0, 1),
        )

    t = Table.grid(padding=(0, 0))
    for _ in range(len(hours)):
        t.add_column(min_width=7, justify="center")

    # Time labels
    time_labels = []
    icon_labels = []
    temp_labels = []
    precip_labels = []

    for h in hours:
        try:
            h_dt = datetime.fromisoformat(h.time_str)
            label = h_dt.strftime("%-I%p").lower()
            # Capitalize AM/PM
            label = label[:-2] + label[-2:].upper()
        except (ValueError, TypeError):
            label = "?"

        night = is_hour_night(h.time_str, weather.sunrise, weather.sunset)
        icon = wmo_icon(h.weather_code, night)
        pc = precip_color(h.precip_pct)

        time_labels.append(Text(label, style=FG_DIM, justify="center"))
        icon_labels.append(Text(f" {icon} ", justify="center"))
        temp_labels.append(Text(f"{h.temp_f:.0f}\u00b0", style=FG, justify="center"))
        precip_labels.append(Text(f"{h.precip_pct:.0f}%", style=pc, justify="center"))

    t.add_row(*time_labels)
    t.add_row(*icon_labels)
    t.add_row(*temp_labels)
    t.add_row(*precip_labels)

    return Panel(t, title="Hourly Forecast", border_style=AQUA, padding=(0, 1))


def render_daily(weather: WeatherData) -> Panel:
    """Render the 3-day forecast panel (skip today)."""
    if not weather.available or len(weather.daily) < 2:
        return Panel(
            Text("  Weather unavailable", style=FG_DIM),
            title="3-Day Forecast",
            border_style=PURPLE,
            padding=(0, 1),
        )

    t = Table.grid(padding=(0, 1))
    t.add_column(min_width=14)   # Day name + date
    t.add_column(min_width=22)   # Icon + description
    t.add_column(min_width=20)   # High/Low
    t.add_column(min_width=12)   # Rain %

    # Skip today (index 0), show next 3
    days = weather.daily[1:4]

    for d in days:
        try:
            d_dt = datetime.fromisoformat(d.date_str)
            day_label = d_dt.strftime("%a %b %-d")
        except (ValueError, TypeError):
            day_label = d.date_str

        icon = wmo_icon(d.weather_code, False)
        desc = wmo_desc(d.weather_code)
        pc = precip_color(d.precip_pct)

        t.add_row(
            Text(f"  {day_label}", style=f"bold {FG}"),
            Text(f"{icon}  {desc}", style=FG),
            Text(f"High {d.high_f:.0f}\u00b0 / Low {d.low_f:.0f}\u00b0", style=FG),
            Text(f"Rain: {d.precip_pct:.0f}%", style=pc),
        )

    return Panel(t, title="3-Day Forecast", border_style=PURPLE, padding=(0, 1))


def render_footer() -> Text:
    """Render the bottom status bar."""
    ft = Text(justify="center")
    ft.append("  q ", style=f"bold {FG}")
    ft.append("quit", style=FG_DIM)
    ft.append("  \u2502  ", style=FG_DIM)
    ft.append("h/\u2190 ", style=f"bold {FG}")
    ft.append("prev", style=FG_DIM)
    ft.append("  \u2502  ", style=FG_DIM)
    ft.append("l/\u2192 ", style=f"bold {FG}")
    ft.append("next", style=FG_DIM)
    ft.append("  \u2502  ", style=FG_DIM)
    ft.append("t ", style=f"bold {FG}")
    ft.append("today", style=FG_DIM)
    ft.append("  \u2502  ", style=FG_DIM)
    ft.append("\u21bb weather 5m", style=FG_DIM)
    return ft


# ── Layout builder ─────────────────────────────────────────────────────

def build_layout(month_offset: int, weather: WeatherData) -> Layout:
    """Assemble the full dashboard layout."""
    layout = Layout()

    # Main: body + footer
    layout.split_column(
        Layout(name="body", ratio=1),
        Layout(name="footer", size=1),
    )

    # Body: top row (calendar + now) and bottom section (hourly + daily)
    layout["body"].split_column(
        Layout(name="top", ratio=5),
        Layout(name="bottom", ratio=3),
    )

    # Top: calendar (left) + now (right)
    layout["top"].split_row(
        Layout(name="calendar", ratio=1),
        Layout(name="now", ratio=1),
    )

    # Bottom: hourly on top, daily below
    layout["bottom"].split_column(
        Layout(name="hourly", ratio=1),
        Layout(name="daily", ratio=1),
    )

    # Populate
    layout["calendar"].update(render_calendar(month_offset))
    layout["now"].update(render_now(weather))
    layout["hourly"].update(render_hourly(weather))
    layout["daily"].update(render_daily(weather))
    layout["footer"].update(render_footer())

    return layout


# ── Main ───────────────────────────────────────────────────────────────

def main() -> None:
    console = Console()

    # Save terminal state for clean restore
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)

    def restore_terminal(*_: object) -> None:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

    signal.signal(signal.SIGINT, lambda *_: (restore_terminal(), sys.exit(0)))
    signal.signal(signal.SIGTERM, lambda *_: (restore_terminal(), sys.exit(0)))

    # Auto-detect location at startup
    location = get_location()

    # State
    month_offset = 0
    weather = WeatherData()
    last_weather_time = 0.0
    last_render_time = 0.0

    try:
        tty.setcbreak(fd)

        with Live(
            console=console,
            screen=True,
            refresh_per_second=4,
            transient=True,
        ) as live:
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
                                if arrow == "C":    # Right arrow = next month
                                    month_offset += 1
                                    last_render_time = 0
                                elif arrow == "D":  # Left arrow = prev month
                                    month_offset -= 1
                                    last_render_time = 0
                        else:
                            break  # Bare Escape = quit
                        continue
                    if key in ("q", "Q"):
                        break
                    if key in ("h", "H"):
                        month_offset -= 1
                        last_render_time = 0
                    elif key in ("l", "L"):
                        month_offset += 1
                        last_render_time = 0
                    elif key in ("t", "T"):
                        month_offset = 0
                        last_render_time = 0

                now = time.monotonic()

                # Refresh weather every 5 minutes
                if now - last_weather_time >= WEATHER_INTERVAL:
                    last_weather_time = now
                    weather = fetch_weather(location)

                # Re-render every 1 second (for clock updates)
                if now - last_render_time >= 1.0:
                    last_render_time = now
                    layout = build_layout(month_offset, weather)
                    live.update(layout)

    finally:
        restore_terminal()


if __name__ == "__main__":
    main()
