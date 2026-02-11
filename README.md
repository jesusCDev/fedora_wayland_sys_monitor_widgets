# System Monitor Inline — KDE Plasma 6 Widget

A minimal, color-coded system monitor widget for the KDE Plasma 6 panel. Displays CPU, GPU, RAM, and battery usage as colored text directly in your top bar.

![Plasma 6](https://img.shields.io/badge/Plasma-6.0%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## What It Looks Like

```
CPU 2%   GPU 8%   RAM 45%   BAT 80%
```

Each metric is color-coded: **CPU** in blue, **GPU** in green, **RAM** in purple, **BAT** in yellow. Colors turn **red** when thresholds are hit (90% for usage, 15% for battery).

## Features

- **CPU usage** — reads from `/proc/stat` with delta calculation
- **GPU usage** — queries KDE's KSystemStats via D-Bus (works with any driver: nouveau, i915, amdgpu, nvidia)
- **RAM usage** — reads from `/proc/meminfo`, can display as percentage or GB
- **Battery level** — reads from `/sys/class/power_supply/`, optional `|` separator
- **1-second updates** by default (configurable 1–60s)
- **Two color themes** — normal and bright (for dark panels)
- **Red warnings** — CPU/GPU/RAM turn red at 90%+, battery at 15% or below
- **Configurable spacing** — adjust space between items (default 3, range 1–10)
- **Fully configurable** — show/hide each metric, decimal precision, RAM in GB, battery position, separator style, update interval

## Settings

Right-click the widget → Configure → General:

| Setting | Description |
|---------|-------------|
| Show CPU/GPU/RAM/Battery | Toggle each metric on/off |
| Show decimals | Display values like `1.2%` instead of `1%` |
| RAM in GB | Show `7.4GB` instead of `23%` |
| Bright colors | High-contrast colors for dark panel themes |
| Warnings | Red color at 90% usage / 15% battery |
| Battery position | Battery on right or left side |
| Item spacing | Space between items (1–10, default 3) |
| Battery separator | Show `\|` divider between battery and other items |
| Update interval | Refresh rate from 1 to 60 seconds |

## Installation

### From source (recommended for development)

```bash
# Clone the repo
git clone https://github.com/jesuscdev/fedora-wayland-sys-monitor-widgets.git
cd fedora-wayland-sys-monitor-widgets

# Symlink into Plasma's widget directory
ln -sf "$(pwd)/org.jesuscdev.sysmonitor" ~/.local/share/plasma/plasmoids/org.jesuscdev.sysmonitor

# Restart plasmashell
kquitapp6 plasmashell && kstart plasmashell
```

### Using kpackagetool6

```bash
kpackagetool6 -t Plasma/Applet -i org.jesuscdev.sysmonitor
```

To update after changes:

```bash
kpackagetool6 -t Plasma/Applet -u org.jesuscdev.sysmonitor
```

### Adding to your panel

1. Right-click your panel → **Add Widgets...**
2. Search for **"System Monitor Inline"**
3. Drag it onto your panel

You can add multiple instances with different settings to arrange metrics however you want.

## GPU Note

The widget uses KDE's **KSystemStats** D-Bus service for GPU data, so it works with any GPU driver (nouveau, i915, amdgpu, proprietary nvidia). By default it reads `gpu/gpu1/usage`. If your GPU is on a different index, you may need to edit `main.qml` and change `gpu/gpu1/usage` to match your system.

To check available GPU sensors:

```bash
busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 \
  org.kde.ksystemstats1 allSensors | tr ',' '\n' | grep "gpu.*usage"
```

## File Structure

```
org.jesuscdev.sysmonitor/
  metadata.json                    # Widget identity and Plasma 6 metadata
  contents/
    config/
      main.xml                     # Configuration schema (all settings)
      config.qml                   # Registers the config page
    ui/
      main.qml                     # Widget logic, display, and data collection
      configGeneral.qml            # Settings UI for the Configure dialog
```

## Requirements

- KDE Plasma 6.0+
- Qt 6 / Qt Quick 2.15
- `org.kde.plasma.plasma5support` QML module (included with Plasma 6)
- `busctl` (included with systemd)

## Troubleshooting

**Widget not showing data:** Restart plasmashell: `kquitapp6 plasmashell && kstart plasmashell`

**Settings not appearing after update:** Remove the widget from the panel, clear the QML cache, then re-add it:
```bash
rm -rf ~/.cache/plasmashell/qmlcache/
kquitapp6 plasmashell && kstart plasmashell
```

**Check for QML errors:**
```bash
journalctl --user -u plasma-plasmashell -f
```

## License

MIT
