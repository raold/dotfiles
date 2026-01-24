# Startpage

Custom Chromium new tab page with Gruvbox Light theme, quick links, and system monitoring.

## Features

- **Quick Links**: Organized in customizable categories
- **Search Bar**: Brave Search (configurable)
- **Live Clock**: Updates every second
- **System Stats**: CPU, RAM, disk usage
- **Service Monitoring**: Green/red status indicators for configured URLs

## Installation

### 1. Copy files to their locations

```bash
# Web files
mkdir -p ~/.local/share/startpage/data
cp index.html style.css app.js config.json favicon.svg ~/.local/share/startpage/

# Scripts
cp startpage-stats.sh startpage-ping.sh ~/.local/bin/
chmod +x ~/.local/bin/startpage-stats.sh ~/.local/bin/startpage-ping.sh

# Systemd units
cp startpage-update.timer startpage-update.service startpage-server.service ~/.config/systemd/user/
```

### 2. Enable services

```bash
systemctl --user daemon-reload

# Web server (serves on localhost:7777)
systemctl --user enable --now startpage-server.service

# Stats updater (runs every 5 minutes)
systemctl --user enable --now startpage-update.timer
```

### 3. Configure Chromium

Set homepage/new tab to: `http://localhost:7777`

For new tab override, install "New Tab Redirect" extension and point it to `http://localhost:7777`.

## Configuration

Edit `~/.local/share/startpage/config.json`:

```json
{
  "search": {
    "engine": "brave",
    "url": "https://search.brave.com/search?q=",
    "placeholder": "Search with Brave..."
  },
  "links": [
    {
      "category": "Work",
      "items": [
        {"name": "GitHub", "url": "https://github.com"}
      ]
    }
  ],
  "services": [
    {"name": "My Service", "url": "https://example.com"}
  ]
}
```

## File Overview

| File | Purpose |
|------|---------|
| `index.html` | Main page structure |
| `style.css` | Gruvbox Light theme |
| `app.js` | Clock, data loading, rendering |
| `config.json` | User configuration |
| `favicon.svg` | Browser tab icon |
| `startpage-stats.sh` | Collects CPU/RAM/disk stats |
| `startpage-ping.sh` | Checks service availability |
| `startpage-server.service` | Python HTTP server on port 7777 |
| `startpage-update.timer` | Runs stats/ping scripts every 5 min |

## Gruvbox Light Palette

```css
--bg:      #fbf1c7   /* Background */
--bg1:     #ebdbb2   /* Card background */
--fg:      #3c3836   /* Text */
--gray:    #928374   /* Muted text */
--red:     #cc241d   /* Service down */
--green:   #98971a   /* Service up */
--blue:    #458588   /* Links */
--orange:  #d65d0e   /* Highlight */
```

## Troubleshooting

**Stats not showing?**
- Run `~/.local/bin/startpage-stats.sh` manually and check `~/.local/share/startpage/data/system.json`
- Check timer status: `systemctl --user status startpage-update.timer`

**Page not loading?**
- Check server: `systemctl --user status startpage-server.service`
- Verify port: `ss -tlnp | grep 7777`
