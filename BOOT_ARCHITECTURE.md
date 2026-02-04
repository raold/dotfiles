# Boot Architecture Documentation

> **System:** Framework Laptop with AMD CPU
> **OS:** Arch Linux + Windows 11 dual-boot
> **Bootloader:** rEFInd
> **Last Updated:** 2026-01-22

---

## Partition Layout

| Partition | Size | Type | Mount | UUID | Purpose |
|-----------|------|------|-------|------|---------|
| `nvme0n1p1` | 100M | EFI (ESP) | — | `A822-107C` | Windows EFI partition |
| `nvme0n1p2` | 16M | MSR | — | — | Microsoft Reserved |
| `nvme0n1p3` | 982G | NTFS | — | `DA6622CF6622ABE7` | Windows C: drive |
| `nvme0n1p4` | 917M | NTFS | — | `4CBADB9EBADB833E` | Windows Recovery |
| `nvme0n1p5` | 600M | EFI (ESP) | `/boot` | `ACE6-9D1E` | Arch EFI/boot partition |
| `nvme0n1p6` | 2G | swap | — | `2463db77-d0c1-417f-a00c-7f9df87b0d26` | Linux swap (not mounted, using /swapfile) |
| `nvme0n1p7` | 876G | ext4 | `/` | `c367a553-2673-40c2-87f3-7db256ef1447` | Arch root |

### Partition UUIDs (PARTUUID)

These are GPT partition GUIDs used in rEFInd `volume` directives:

| Partition | PARTUUID |
|-----------|----------|
| `nvme0n1p1` (Windows ESP) | `dd13a825-93d3-4f79-bf42-3ab4ff82d5a0` |
| `nvme0n1p5` (Arch ESP)    | `639512fa-8c83-4f9c-9e43-8b9f32d0181d` |
| `nvme0n1p7` (Arch root)   | `c21470fe-0a6c-4e8b-a24d-1dd860bf719f` |

---

## Boot Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      UEFI Firmware                              │
│  BootOrder: 0003 → 0000 → 2001 → 2002 → 2003                    │
└───────────────────────────┬─────────────────────────────────────┘
                            │
          ┌─────────────────┴─────────────────┐
          │                                   │
          ▼                                   ▼
┌─────────────────────┐           ┌──────────────────────────────────┐
│ Boot0003: rEFInd    │           │ Boot0000: "Windows Boot Manager" │
│ (Arch ESP - p5)     │           │ (Windows ESP - p1)               │
│                     │           │                                  │
│ /EFI/refind/        │           │ BUT: bootmgfw.efi IS rEFInd!     │
│   refind_x64.efi    │           │ (Windows shim protection)        │
└──────────┬──────────┘           └────────────────┬─────────────────┘
           │                                       │
           └───────────────┬───────────────────────┘
                           │
                           ▼
                 ┌─────────────────────┐
                 │      rEFInd         │
                 │  (Either path!)     │
                 └──────────┬──────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       ┌─────────────┐           ┌─────────────────┐
       │    Arch     │           │    Windows      │
       │  Linux      │           │    11           │
       └─────────────┘           └─────────────────┘
```

---

## Triple-Layer Windows Protection

Your setup has three layers of protection against Windows hijacking the bootloader:

### Layer 1: EFI Boot Order
```
BootOrder: 0003, 0000, 2001, 2002, 2003
           ^^^^
           rEFInd is FIRST
```

### Layer 2: Windows Bootloader Shim
On the Windows ESP (`nvme0n1p1`):
```
/EFI/Microsoft/Boot/bootmgfw.efi     → IS ACTUALLY rEFInd (332KB)
/EFI/Microsoft/Boot/bootmgfw-orig.efi → Real Windows bootloader (1.7MB)
```

Even if Windows/firmware resets boot order, loading "Windows Boot Manager" actually loads rEFInd.

### Layer 3: Fallback Bootloader
```
/EFI/Boot/bootx64.efi → IS ALSO rEFInd
```

The UEFI fallback path also loads rEFInd.

---

## rEFInd Configuration Files

There are **two** rEFInd installations with separate configs:

| Location | Config Path | Used When |
|----------|-------------|-----------|
| Windows ESP (p1) | `/EFI/refind/refind.conf` | Booting via Boot0000 (shim) |
| Arch ESP (p5) | `/boot/EFI/refind/refind.conf` | Booting via Boot0003 (direct) |

Both configs are now synchronized with identical menu entries.

### Key Configuration Settings

```ini
timeout 20              # 20 second menu timeout
use_nvram false         # Store variables on disk, not NVRAM
scanfor manual          # Only use manual menu entries (no auto-detect)
```

### Arch Menu Entry

```ini
menuentry "Arch" {
    icon     /EFI/refind/themes/refind-gruvbox-theme/icons/os_arch.png
    volume   639512fa-8c83-4f9c-9e43-8b9f32d0181d
    loader   /vmlinuz-linux-cachyos
    initrd   /amd-ucode.img
    initrd   /initramfs-linux-cachyos.img
    options  "root=UUID=c367a553-2673-40c2-87f3-7db256ef1447 zswap.enabled=0 rw rootfstype=ext4 ..."

    submenuentry "Boot using fallback initramfs" { ... }
    submenuentry "Boot to single-user mode" { ... }
    submenuentry "Boot with minimal options" { ... }
    submenuentry "Boot to terminal" { ... }
    submenuentry "Emergency shell (bypass systemd)" { ... }
}
```

### Windows Menu Entry

```ini
menuentry "Windows" {
    icon     /EFI/refind/themes/refind-gruvbox-theme/icons/os_win.png
    volume   dd13a825-93d3-4f79-bf42-3ab4ff82d5a0
    loader   /EFI/Microsoft/Boot/bootmgfw-orig.efi
}
```

---

## Kernel Boot Parameters

Your Arch kernel boots with these parameters:

| Parameter | Purpose |
|-----------|---------|
| `root=UUID=c367a553-...` | Root filesystem |
| `zswap.enabled=0` | Disable zswap (using zram instead) |
| `rw` | Mount root read-write |
| `rootfstype=ext4` | Root filesystem type |
| `amd_pstate=active` | AMD P-State driver in active mode |
| `pcie_aspm=force` | Force PCIe Active State Power Management |
| `pcie_aspm.policy=powersupersave` | Maximum power saving |
| `rtc_cmos.use_acpi_alarm=1` | ACPI alarm for RTC |
| `amd_pmc.enable_stb=0` | Disable AMD PMC Smart Trace Buffer (critical for S0i3 sleep) |
| `gpiolib_acpi.ignore_interrupt=AMDI0030:00@18` | Fix GPIO interrupt issue |
| `resume=UUID=... resume_offset=3989504` | Hibernation support |
| `vt.default_*` | Gruvbox terminal colors |

---

## Recovery Procedures

### If Windows Breaks Boot Order

```bash
# Boot from Arch USB, then:
sudo efibootmgr -o 0003,0000,2001,2002,2003
```

### If Windows Replaces bootmgfw.efi

```bash
# Mount Windows ESP
sudo mount /dev/nvme0n1p1 /mnt

# Re-copy rEFInd over Windows bootloader
sudo cp /mnt/EFI/refind/refind_x64.efi /mnt/EFI/Microsoft/Boot/bootmgfw.efi
sudo cp /mnt/EFI/refind/refind_x64.efi /mnt/EFI/Boot/bootx64.efi

# Verify
sha256sum /mnt/EFI/Microsoft/Boot/bootmgfw.efi /mnt/EFI/refind/refind_x64.efi

sudo umount /mnt
```

### Emergency Boot (No rEFInd)

If rEFInd is completely broken, boot directly to Arch kernel:

1. Enter UEFI firmware (F2/Del at boot)
2. Add boot entry pointing to: `\EFI\BOOT\BOOTX64.EFI` on Arch ESP
3. Or use UEFI Shell to run: `fs0:\vmlinuz-linux-cachyos root=UUID=c367a553-... initrd=\initramfs-linux-cachyos.img`

### Reinstall rEFInd

```bash
# From Arch
sudo pacman -S refind
sudo refind-install

# Then restore shim on Windows ESP
sudo mount /dev/nvme0n1p1 /mnt
sudo cp /mnt/EFI/refind/refind_x64.efi /mnt/EFI/Microsoft/Boot/bootmgfw.efi
sudo umount /mnt
```

---

## File Locations Quick Reference

### Windows ESP (`/dev/nvme0n1p1`)
```
/EFI/
├── Boot/
│   └── bootx64.efi              # rEFInd (fallback)
├── Microsoft/
│   └── Boot/
│       ├── bootmgfw.efi         # rEFInd (shim)
│       └── bootmgfw-orig.efi    # Real Windows bootloader
└── refind/
    ├── refind_x64.efi           # rEFInd binary
    ├── refind.conf              # Config for this ESP
    └── themes/
        └── refind-gruvbox-theme/
```

### Arch ESP (`/dev/nvme0n1p5` mounted at `/boot`)
```
/boot/
├── vmlinuz-linux-cachyos         # CachyOS kernel (default)
├── vmlinuz-linux-lts            # LTS kernel (fallback)
├── initramfs-linux-cachyos.img  # CachyOS initramfs
├── initramfs-linux-lts.img      # LTS initramfs
├── amd-ucode.img                # AMD microcode
├── refind_linux.conf            # Kernel parameters (used with manual stanza)
└── EFI/
    ├── BOOT/
    │   └── BOOTX64.EFI          # systemd-boot (not used)
    └── refind/
        ├── refind_x64.efi       # rEFInd binary
        ├── refind.conf          # Config for this ESP
        └── themes/
            └── refind-gruvbox-theme/
```

---

## EFI Boot Entries

```
Boot0000* Windows Boot Manager  → nvme0n1p1:/EFI/Microsoft/Boot/bootmgfw.efi (IS rEFInd)
Boot0003* rEFInd Boot Manager   → nvme0n1p5:/EFI/refind/refind_x64.efi
Boot2001* EFI USB Device
Boot2002* EFI DVD/CDROM
Boot2003* EFI Network
```

---

## Backup Locations

| What | Location |
|------|----------|
| Windows ESP backup | `/EFI/backup_20251220_191423/` on nvme0n1p1 |
| rEFInd config backup | `/boot/EFI/refind/refind.conf.save` |
| Timeshift snapshots | `/mnt/timeshift/` (external drive) |

---

## Maintenance Notes

### After Kernel Updates
The manual stanza hardcodes `/vmlinuz-linux-cachyos`. CachyOS kernel updates replace this file in-place, so no action needed. If switching kernels, update the `loader` line in `refind.conf`.

### After Windows Major Updates
Check if boot order was reset:
```bash
efibootmgr | grep BootOrder
# Should be: 0003,0000,2001,2002,2003
```

If reset, fix with:
```bash
sudo efibootmgr -o 0003,0000,2001,2002,2003
```

### Syncing Configs
If you modify one rEFInd config, sync to the other:
```bash
sudo mount /dev/nvme0n1p1 /mnt
# Edit both:
#   /boot/EFI/refind/refind.conf (Arch ESP)
#   /mnt/EFI/refind/refind.conf  (Windows ESP)
sudo umount /mnt
```
