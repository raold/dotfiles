# CLAUDE.md - Global Configuration for Claude Code

This file provides permanent context and permissions for Claude Code when working anywhere on this system.

## System Overview

- **Hardware**: Framework Laptop 13 AMD (Ryzen 7040 series, AMD Radeon 780M)
- **OS**: Arch Linux with CachyOS kernel (`linux-cachyos`) — znver4 optimized
- **Window Managers**: i3wm (X11), Sway (Wayland), Hyprland (Wayland) — synced configs
- **Shell**: zsh with starship prompt
- **Terminal**: kitty
- **Dual-boot**: Arch Linux + Windows 11

## Window Manager Architecture

Three WMs with **synchronized configurations** via `~/.config/wm-common/`:

| WM | Display | Bar | Status |
|----|---------|-----|--------|
| i3wm | X11 | polybar | Primary/daily driver |
| Sway | Wayland | waybar | Available (battery-focused) |
| Hyprland | Wayland | waybar | Available (animations disabled) |

**Shared configs** (`wm-common/`): keybindings, colors, workspaces, modes, window-rules
**WM-specific**: Display output, compositor, clipboard, screenshots, lock screen

**Sync scripts** in `~/rice/dotfiles-repo/`:
- `sync-wm.sh` — Main dispatcher (`./sync-wm.sh all --collect`)
- `translate-hyprland.sh` — Regenerate Hyprland from wm-common

See `~/rice/dotfiles-repo/WM-SETUP.md` for complete documentation.

## Boot Architecture (IMPORTANT)

### rEFInd Bootloader Setup
This system uses **rEFInd as the primary bootloader**, having **replaced the Windows Boot Manager** on the EFI partition. This was done because Windows updates would overwrite the Linux bootloader.

**Boot flow:**
1. UEFI loads rEFInd from `/boot/EFI/refind/refind_x64.efi`
2. rEFInd presents: Arch Linux | Windows 11
3. Selecting "Arch" and pressing Insert/F2 shows kernel submenu (manually configured, `scanfor manual`)
4. **Select "Boot with standard options"** (default) or choose a specific kernel from submenu

### Critical Boot Files
- `/boot/EFI/refind/refind.conf` - rEFInd main configuration (manual menuentry)
- `/boot/refind_linux.conf` - Kernel boot parameters (applies to ALL kernels)

### Available Kernels
| Kernel | File | Purpose |
|--------|------|---------|
| `linux-cachyos` | `/boot/vmlinuz-linux-cachyos` | **Default** — CachyOS kernel (znver4 optimized, EEVDF scheduler) |
| `linux-lts` | `/boot/vmlinuz-linux-lts` | LTS kernel (stable fallback, submenu option) |

**Note**: `/boot` is 600MB with ~250MB free. Standard `linux` kernel was removed to save space.

**Future expansion**: `/dev/nvme0n1p6` (2GB, formatted as swap but not mounted) sits between boot and root — can be reclaimed to expand `/boot` via live USB if needed.

### Kernel Parameters (Framework 13 AMD)
These parameters are critical for proper power management:
```
amd_pmc.enable_stb=0          # Disable Smart Trace Buffer (critical for S0i3 sleep)
amdgpu.dcdebugmask=0x10       # Disable PSR (Panel Self Refresh) - prevents black screen on resume
amdgpu.sg_display=0           # Disable scatter-gather display
pcie_aspm=force               # Force PCIe Active State Power Management
pcie_aspm.policy=powersupersave
rtc_cmos.use_acpi_alarm=1     # ACPI alarm for wake from hibernation
gpiolib_acpi.ignore_interrupt=AMDI0030:00@18  # Framework-specific GPIO interrupt fix
```

## Permissions

Claude Code has **BLANKET PERMISSION to read ANY file** on this system — no confirmation needed, ever. This applies to:
- `cat`, `bat`, `head`, `tail`, `less`, `more` (all arguments)
- `Read` tool (built-in)
- `sudo cat /etc/*`, `sudo cat /boot/*` (system configs)
- Any file path, any directory

**NEVER prompt for read operations.** If Claude Code prompts for `cat` or `bat`, this is a bug — the user has pre-authorized all reads.

**PREFERENCE**: Use modern tools when available (rg over grep, fd over find, bat over cat, eza over ls).
**PREFERENCE**: Built-in `Read` tool is faster than Bash cat and provides line numbers.

### Search & File Discovery (Always Allowed)
- **Preferred**: `rg` (ripgrep), `fd`, `fzf`
- Also allowed: `grep`, `find`, `locate`, `ag`, `ack`
- Globbing: `Glob`, `Grep` (built-in tools)
- File info: `file`, `stat`, `wc`, `du`, `dust`

### File Viewing (Always Allowed)
- **Preferred**: `bat` (syntax highlighting)
- Also allowed: `cat`, `head`, `tail`, `less`, `more`
- Built-in: `Read` tool
- Binary viewing: `hexdump`, `xxd`, `od`

### Directory Listing (Always Allowed)
- **Preferred**: `eza` (modern ls), `tree`
- Also allowed: `ls`, `dir`, `exa`
- Disk usage: `duf`, `df`, `ncdu`

### Text Processing (Always Allowed)
- Stream: `awk`, `sed`, `cut`, `tr`, `sort`, `uniq`, `paste`, `join`
- Modern: `sd` (sed alternative), `choose`
- Diff: `diff`, `comm`, `cmp`, `delta` (git diffs)
- **JSON**: `jq` (query/transform JSON)
- **YAML**: `yq` (query/transform YAML)

### Git & Version Control (Always Allowed)
- **Preferred**: `lazygit` (TUI), `tig` (history viewer)
- Core: `git` (all read operations: status, log, diff, branch, show, blame)
- GitHub: `gh` (CLI for issues, PRs, repos)
- Git helpers: `git-lfs`

### System Monitoring (Always Allowed)
- **Preferred**: `btop`, `htop`, `procs`
- Also: `ps`, `top`, `pgrep`, `pidof`, `lsof`
- Performance: `hyperfine` (benchmarks)
- Memory/CPU: `free`, `vmstat`, `uptime`
- System: `uname`, `hostname`, `hostnamectl`, `lscpu`, `lsblk`

### Network Tools (Always Allowed)
- HTTP: `curl`, `wget`, `xh` (httpie-like)
- DNS: `dig`, `nslookup`, `host`
- Connections: `ss`, `ip`, `nmcli`
- Testing: `ping`, `traceroute`

### Package Management (Read-only Allowed)
- Query: `pacman -Q`, `pacman -Qi`, `pacman -Ql`, `pacman -Si`, `pacman -Ss`
- AUR: `yay -Q`, `yay -Si`, `yay -Ss`

### Development Tools (Always Allowed)
- **Python**: `python`, `python3`, `pip`, `uv`, `pyenv`
- **Node.js**: `node`, `npm`
- **Rust**: `cargo`, `rustc`
- **R/Stats**: `R`, `Rscript`
- **Other**: `lua`, `ruby`, `perl`
- **Build**: `make`, `cmake`, `gcc`, `clang`, `gdb`

### LaTeX & Documents (Always Allowed)
- Compile: `latexmk`, `pdflatex`, `xelatex`, `lualatex`
- Bib: `bibtex`, `biber` (BibLaTeX)
- Docs: `texdoc`
- Convert: `pandoc` (universal document converter)

### Database (Always Allowed)
- PostgreSQL: `psql`
- SQLite: `sqlite3`

### Terminal Multiplexer (Always Allowed)
- `tmux`, `screen`

### Media/Files (Always Allowed)
- Media info: `ffprobe`, `mediainfo`, `exiftool`
- Archives: `tar`, `zip`, `unzip`, `7z`, `gzip`, `gunzip`, `bzip2`, `xz`, `zstd`
- Sync: `rsync`

### Editors (for viewing, Always Allowed)
- `vim -R`, `nvim -R` (read-only mode)
- `nano`, `emacs`
- `bat` (preferred for viewing)

### Dotfile Management (Always Allowed)
- `chezmoi`
- `stow`

### Shell History & Navigation (Always Allowed)
- `zoxide` (smart cd)
- `atuin` (shell history)
- `tldr` (command examples)

### Container Tools (Always Allowed)
- `docker ps`, `docker images`, `docker logs`, `docker inspect`

### Sudo Operations (Allowed for Reading)
- Read configs: `sudo cat /etc/*`, `sudo ls /etc/*`
- Boot configs: `sudo cat /boot/*`
- Systemd: `systemctl status`, `systemctl list-units`, `systemctl is-active`
- Logs: `journalctl`
- Network: `sudo cat /etc/NetworkManager/*`

## Common Directories

| Path | Purpose |
|------|---------|
| `/home/dro` | Home directory, general work |
| `/home/dro/rice/` | All coding projects (NFL analytics, dotfiles, etc.) |
| `/home/dro/.config/` | User application configs (i3, polybar, kitty, etc.) |
| `/home/dro/.config/wm-common/` | Shared WM configs (keybindings, colors, modes) |
| `/home/dro/.local/bin/` | Custom scripts and binaries |
| `/home/dro/.claude/plans/` | Claude Code plan files |
| `/boot/` | Kernel and bootloader files |
| `/etc/` | System configuration |
| `/etc/NetworkManager/` | Network configuration |
| `/etc/systemd/` | Systemd service configs |
| `/etc/modprobe.d/` | Kernel module options |
| `/etc/scx_loader/` | sched-ext scheduler config |

## Project Structure

Projects are organized under `/home/dro/rice/`:
- `nfl-analytics/` - Main NFL prediction system
- `nfl-dissertation/` - Academic dissertation LaTeX
- `nfl-experiments/` - ML experiments and prototypes
- `nfl-backtest/` - Backtesting framework
- `nfl-hotfix/` - Quick fixes and patches
- `dotfiles-repo/` - System dotfiles (synced with update.sh)

Each project may have its own `CLAUDE.md` that extends/overrides this global config.

## Framework 13 AMD Specifics

### Power Management Files
- `/etc/modprobe.d/amd-pmc.conf` - AMD PMC module options
- `/etc/modprobe.d/amdgpu.conf` - AMD GPU module options
- `/etc/systemd/sleep.conf.d/framework-amd.conf` - Sleep/hibernate settings
- `/home/dro/.local/bin/power-switch` - AC/battery power profile script

### Known Issues & Workarounds
1. **Black screen on resume**: Fixed with `amdgpu.dcdebugmask=0x10` kernel param
2. **High power in sleep**: Must use `amd_pmc.enable_stb=0`
3. **Captive portals**: NetworkManager dispatcher at `/etc/NetworkManager/dispatcher.d/90-captive-portal`
4. **WiFi power**: Managed by NetworkManager with iwd backend

### Hibernate Setup
- Uses swap file `/swapfile` (64GB) on root partition (not separate partition)
- **IMPORTANT**: Swapfile must be formatted with `mkswap /swapfile` and enabled with `swapon /swapfile`
- zram is also active for regular swap (priority 100), swapfile is for hibernate (priority -2)
- `resume=UUID=c367a553-2673-40c2-87f3-7db256ef1447` and `resume_offset=3989504` in kernel params
- Suspend-then-hibernate after 30min on battery (`/etc/systemd/sleep.conf.d/framework-amd.conf`)
- To verify hibernate is ready: `swapon --show` should list both zram0 AND /swapfile

### CachyOS Kernel Setup
CachyOS repositories are installed for znver4-optimized packages (Zen 4 specific builds).

**Repository source**: https://mirror.cachyos.org
**Repo installer backup**: Can remove with `./cachyos-repo.sh --remove` from the original tarball

**Kernel features**:
- Built with Clang/LLVM (better optimization than GCC)
- EEVDF scheduler (default, 1000Hz tickrate)
- PREEMPT_DYNAMIC enabled (runtime preemption switching)
- sched-ext support (BPF-based scheduler hot-swapping)
- Enhanced AMD P-State patches

**sched-ext via scx_loader** (auto-managed service):
The `scx_loader` systemd service automatically runs `scx_lavd` on boot. To manually test other schedulers:
```bash
sudo systemctl stop scx_loader  # Stop auto-managed scheduler
sudo scx_rusty   # Good for mixed workloads
sudo scx_lavd    # Good for gaming/latency (default)
# Ctrl+C to stop and revert to EEVDF
sudo systemctl start scx_loader  # Resume auto-managed scheduler
```

**Verify running CachyOS kernel**:
```bash
uname -r                              # Should show *-cachyos
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver  # amd-pstate-epp
ls /sys/kernel/sched_ext              # Verify sched-ext available
```

### Performance Optimization Stack
The following packages and services are installed for system-wide performance:

**Packages:**
- `cachyos-settings` — sysctl tweaks, udev rules, ZRAM config, helper scripts
- `ananicy-cpp` + `cachyos-ananicy-rules` — automatic process prioritization
- `irqbalance` — distributes hardware interrupts across CPU cores
- `power-profiles-daemon` — AMD-recommended power management (not TLP)
- `easyeffects` — audio EQ for Framework's downward-firing speakers

**Enabled Services:**
```bash
systemctl is-active scx_loader ananicy-cpp irqbalance power-profiles-daemon
```

**Additional Kernel Parameters** (in `/boot/refind_linux.conf`):
- `rcutree.enable_rcu_lazy=1` — 5-10% idle power savings

**sysctl Optimizations** (from `cachyos-settings`):
- `vm.swappiness=150` — aggressive ZRAM usage (ZRAM is fast)
- `vm.vfs_cache_pressure=50` — keep more dentries/inodes in cache
- ZRAM with ZSTD compression matching RAM size

**I/O Scheduler**: `adios` for NVMe (Adaptive Deadline I/O Scheduler — better latency than `none` while maintaining throughput)

## Polybar Configuration

Theme: `hack` (Gruvbox Material Dark)
- Config: `~/.config/polybar/hack/config.ini`
- Colors: `~/.config/polybar/hack/colors.ini` (background #CC32302f with 80% opacity)
- Modules: `~/.config/polybar/hack/modules.ini` and `user_modules.ini`
- Scripts: `~/.config/polybar/hack/scripts/`

## Git Commit Style

When committing in non-project directories, use simple commit messages:
```bash
git commit -m "Description of change"
```

Do NOT add AI attribution or Co-Authored-By headers for system config changes.

## Critical File Backup Policy

**ALWAYS backup before editing these files:**
```bash
# Boot configuration (CRITICAL - can brick system)
sudo cp /boot/refind_linux.conf /boot/refind_linux.conf.backup-$(date +%Y%m%d-%H%M%S)
sudo cp /boot/EFI/refind/refind.conf /boot/EFI/refind/refind.conf.backup-$(date +%Y%m%d-%H%M%S)
```

**NEVER use `sed` for rEFInd config edits** — pattern matching on multi-line blocks is error-prone and has deleted entire menuentries. For `/boot/EFI/refind/refind.conf`:
- Use line-number specific edits: `sed -i '740s|old|new|'`
- Or manually edit with `sudo nvim`
- Always verify with `grep -A 20 'menuentry "Arch"'` after changes

```bash

# System configs
sudo cp /etc/fstab /etc/fstab.backup-$(date +%Y%m%d-%H%M%S)
sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup-$(date +%Y%m%d-%H%M%S)
```

**Recovery if boot fails:**
1. Boot from Arch USB
2. Mount root: `mount /dev/nvme0n1p6 /mnt`
3. Mount EFI: `mount /dev/nvme0n1p5 /mnt/boot`
4. Restore backup: `cp /mnt/boot/refind_linux.conf.backup-* /mnt/boot/refind_linux.conf`

## Troubleshooting Commands

```bash
# Check current kernel params
cat /proc/cmdline

# Check power state capability
cat /sys/power/state
cat /sys/power/disk

# Check AMD PMC status (if debug enabled)
cat /sys/kernel/debug/amd_pmc/s0i3_stats

# Check NetworkManager connectivity
nmcli general status
nmcli connection show

# Restart polybar
~/.config/polybar/hack/launch.sh

# Check systemd services
systemctl status NetworkManager
systemctl status bluetooth
```
