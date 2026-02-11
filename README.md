# System Monitor Inline — KDE Plasma 6 Widget

A minimal, color-coded system monitor widget for the KDE Plasma 6 panel. Displays CPU, GPU, RAM, network speed, and battery usage as colored text directly in your top bar.

![Plasma 6](https://img.shields.io/badge/Plasma-6.0%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## What It Looks Like

![System Monitor Inline screenshot](Screenshot_20260211_062436.png)

Each metric is color-coded: **CPU** in blue, **GPU** in green, **RAM** in purple, **NET** in cyan, **BAT** in yellow. Colors turn **red** when configurable thresholds are hit (or when network is disconnected).

## Features

- **CPU usage** — reads from `/proc/stat` with delta calculation
- **GPU usage** — queries KDE's KSystemStats via D-Bus (works with any driver: nouveau, i915, amdgpu, nvidia)
- **RAM usage** — reads from `/proc/meminfo`, can display as percentage or GB
- **Network speed** — live download rate with auto-scaling units (K/s, M/s, G/s), turns red when disconnected
- **Battery level** — reads from `/sys/class/power_supply/`, with optional time remaining and `│` separator
- **Charge limit aware** — battery time-to-full respects `charge_control_end_threshold` (e.g. 80% charge protection)
- **CPU/GPU temperature** — via hwmon sysfs sensors, displayed in °C (disabled by default)
- **Disk usage** — root filesystem usage percentage (disabled by default)
- **System uptime** — formatted as `3d 4h` or `2h 30m` (disabled by default)
- **Trend arrows** — shows rising/falling indicators on metrics (disabled by default)
- **Icon mode** — optional Font Awesome icons instead of text labels, battery icon changes with charge level (disabled by default)
- **Per-metric click actions** — left-click CPU/GPU/RAM/Disk opens a terminal command (default: `konsole -e htop`), Network opens WiFi settings, Battery/Uptime opens power settings. Middle-click opens popup
- **1-second updates** by default (configurable 1–60s)
- **Battery mode** — automatically reduces refresh rate when on battery power (default: 5s interval)
- **Resource-aware** — only runs data collection for enabled metrics
- **Two color themes** — normal and bright (for dark panels)
- **Configurable warnings** — adjustable thresholds per metric (default: 90% CPU/GPU/RAM, 15% battery)
- **Configurable spacing** — adjust space between items (default 3, range 1–10)
- **Custom colors** — override colors for any metric individually, with color picker
- **Fully configurable** — show/hide each metric, decimal precision, RAM in GB, battery position, separator style, update interval

## Settings

Right-click the widget → Configure. Settings are organized into 4 tabs:

### Metrics
Toggle each metric on/off: CPU, GPU, RAM, Network, Disk, Uptime, Battery, Battery time remaining, CPU/GPU temperature (°C).

### Display
| Setting | Description |
|---------|-------------|
| Show decimals | Display values like `1.2%` instead of `1%` |
| RAM in GB | Show `7.4GB` instead of `23%` |
| Bright colors | High-contrast colors for dark panel themes |
| Trend arrows | Show rise/fall indicators on metrics |
| Icons | Use Font Awesome icons instead of text labels |
| Battery position | Battery on right or left side |
| Charging icon | Show lightning bolt when charging |
| Battery separator | Show `│` divider between battery and other items |
| Item spacing | Space between items (1–10, default 3) |

### Alerts
| Setting | Description |
|---------|-------------|
| Warnings | Color change at configurable thresholds |
| Warning thresholds | Per-metric threshold (CPU, GPU, RAM, battery) |
| Update interval | Refresh rate from 1 to 60 seconds |
| Battery mode | Reduce refresh rate when on battery power |
| Battery mode interval | Refresh interval when on battery (1–60s, default 5) |
| Click command | Command to run on left-click for CPU/GPU/RAM/Disk (default: `konsole -e htop`) |

### Colors
Override color for any individual metric with text input or color picker. Leave empty for default.

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

## Temperature Note

Temperatures are read directly from hwmon sysfs sensors (`/sys/class/hwmon/`) in °C. CPU temperature uses the `coretemp` hwmon sensor (Package temp). GPU temperature uses the `thinkpad` hwmon sensor. If your GPU's discrete chip is powered off (common with nouveau), GPU temperature will be hidden automatically.

## File Structure

```
org.jesuscdev.sysmonitor/
  metadata.json                    # Widget identity and Plasma 6 metadata
  LICENSE-fontawesome.txt          # OFL license for Font Awesome font
  contents/
    config/
      main.xml                     # Configuration schema (all settings)
      config.qml                   # Registers the 4 config tabs
    fonts/
      fa-solid-900.ttf             # Font Awesome 6 Free Solid (optional icons)
    ui/
      main.qml                     # Widget logic, display, and data collection
      configMetrics.qml            # Settings: which metrics to show
      configDisplay.qml            # Settings: formatting and layout
      configAlerts.qml             # Settings: thresholds, intervals, actions
      configColors.qml             # Settings: custom color pickers
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

Font Awesome 6 Free is licensed under the [SIL Open Font License (OFL)](https://scripts.sil.org/OFL). See `LICENSE-fontawesome.txt`.
