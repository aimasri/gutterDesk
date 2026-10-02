# Tactile Desktop Environment: gutterDesk

## 1. Design Philosophy & Midnight Forest Palette

**gutterDesk** is designed around a tactile, keyboard-driven productivity workflow. Rather than consuming system resources on heavy desktop shells (GNOME Shell, KDE Plasma) or decorative background daemons, the desktop stack pairs **Openbox 3**, **Tint2**, and **Picom** with bespoke obsidian styling.

### The Midnight Forest Color Palette:
* **Obsidian Base:** `#060d08` (Deep charcoal green/black)
* **Surface Card:** `#0b140e` (Elevated panel and card background)
* **Pine Accent:** `#1f3d2b` (Focused window titlebars, active buttons)
* **Sage Highlight:** `#629e79` (Active border outlines, clock, highlight text)
* **Text Primary:** `#d8e2dc` (High-contrast clean typography)
* **Text Muted:** `#7c9082` (Inactive tabs, timestamps, secondary labels)
* **Icon Suite:** `Papirus-Dark` (Clean, flat vector iconography)

The palette is applied uniformly across GTK 2/3 (`dotfiles/themes/.themes/gutterdesk/gtk-3.0/gtk.css`), Openbox window decorations (`Forest-dark/themerc`), LightDM greeter cards, Guake terminal palettes, and Plymouth boot splash assets.

---

## 2. Window Management (Openbox 3)

### Core Keybindings:
All global hotkeys are defined declaratively in `dotfiles/openbox/.config/openbox/rc.xml`:

| Keybinding | Action | Command Executed |
| :--- | :--- | :--- |
| `F12` | Dropdown terminal toggle | `guake-toggle` |
| `Alt + F2` | Program runner | `gmrun` |
| `Super + Space` | Root desktop application menu | Openbox RootMenu |
| `Super + x` | Session & power control | Openbox ClientMenu / Exit Menu |
| `PrintScreen` | Full desktop screenshot | `scrot '~/images/screenshots/%Y-%m-%d-%T.png'` |
| `Alt + PrintScreen` | Active window screenshot | `scrot -u '~/images/screenshots/%Y-%m-%d-%T.png'` |
| `Shift + PrintScreen` | Interactive select area | `scrot -s '~/images/screenshots/%Y-%m-%d-%T.png'` |
| `Super + Left` | Snap window to left half | Openbox Unmaximize + Move/Resize (0, 0, 50%, 100%) |
| `Super + Right` | Snap window to right half | Openbox Unmaximize + Move/Resize (50%, 0, 50%, 100%) |
| `Super + Up` | Toggle maximize | `ToggleMaximize` |
| `Alt + Tab` | Window switcher | Openbox NextWindow (Current Desktop) |

### Autostart Execution Pipeline:
When an X11 session initializes, Openbox executes `~/.config/openbox/autostart` (symlinked from `dotfiles/openbox/.config/openbox/autostart`). The sequence runs in strict order:

1. **Display Calibration:** Executes `auto-wallpaper` to detect monitor geometries and set orientation-matched wallpapers via `nitrogen`.
2. **System Settings Daemon:** Spawns `xsettingsd` to enforce GTK themes, font antialiasing (Subpixel RGB, Hinting Slight), and `Papirus-Dark` icons across X11 apps.
3. **Screen Locker Daemon:** Spawns `light-locker --lock-on-suspend --lock-on-lid --no-late-locking`.
4. **Compositor:** Spawns `picom -b` for tear-free X11 rendering and window shadow rendering.
5. **Panel:** Spawns `tint2 &` status panel.
6. **Tactile Productivity Daemons:** Spawns `guake &`, `gutterdeck &`, and `guttertab &`.
7. **Volume Indicator:** Spawns `volumeicon &` ALSA/Pulse tray controller.

---

## 3. Modular Openbox Menu Engine (`gutterdesk-menu`)

### The Problem:
Traditional desktop distributions populate their application menus with dozens of pre-configured shortcuts for uninstalled software, leading to broken launchers and visual clutter.

### The Solution:
gutterDesk introduces a dynamic staged compilation pipeline:
* `menu.template.xml`: Pure core base menu (System, Preferences, File Manager, Browsers, Terminal, Power).
* `menu.d/*.xml`: Modular XML snippets representing optional functional capabilities (`creative.xml`, `trading.xml`, `torrent.xml`).
* `gutterdesk-menu`: Distro CLI tool that compiles the final `~/.config/openbox/menu.xml` and reconfigures Openbox in real time.

```
                      +-----------------------------+
                      |      menu.template.xml      |
                      |  (Contains insertion tags)  |
                      +--------------+--------------+
                                     |
               +---------------------+---------------------+
               |                     |                     |
     <!-- MODULE_CREATIVE -->  <!-- MODULE_TRADING -->  <!-- MODULE_TORRENT -->
               |                     |                     |
     [menu.d/creative.xml]   [menu.d/trading.xml]    [menu.d/torrent.xml]
               \                     |                     /
                +--------------------+--------------------+
                                     |
                                     v
                      +-----------------------------+
                      |   ~/.config/openbox/        |
                      |        menu.xml             |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      |    openbox --reconfigure    |
                      +-----------------------------+
```

### CLI Commands:
```bash
# Initialize base menu without uninstalled modules
gutterdesk-menu init

# Enable a module snippet upon module installation
gutterdesk-menu enable creative
gutterdesk-menu enable trading
gutterdesk-menu enable torrent

# Disable a module and reconfigure menu
gutterdesk-menu disable creative

# Inspect current menu configuration status
gutterdesk-menu status
```

---

## 4. Status Bar & Native Executors (Tint2)

### Panel Architecture (`tint2rc`):
* **Placement:** Bottom edge, full width across all connected display heads.
* **Layout:** `LTSCBE` (Launcher -> Taskbar -> Systray -> Clock -> Battery -> Executor).
* **Taskbar:** Displays running windows per desktop with Midnight Forest active tab highlights (`#1f3d2b` focused, `#0b140e` inactive).

### Zero-Overhead Telemetry Executors:
1. **Wi-Fi Telemetry (`tint2-network`):**
   * Executes at 15-second intervals.
   * Directly queries the `iwd` D-Bus interface via `iwctl station <wlan> show`.
   * Maps current signal RSSI (dBm) to appropriate Papirus-Dark signal icons (`network-wireless-signal-excellent`, `good`, `ok`, `weak`, `none`).
   * Avoids heavy background notification daemons or memory-hogging applets.
2. **Tactile Calendar (`gsimplecal`):**
   * Clicking the Tint2 clock widget triggers `gsimplecal`.
   * A lightweight, borderless calendar pops up anchored directly above the clock and dismisses automatically on click-out.
