# Hardware, Power & Display Subsystems: gutterDesk

## 1. Always-On Server Posture (Lid Switch Handling)

When operating laptops as portable workstations or always-on development servers (e.g. `aim-stream` or `aim-book`), closing the physical clamshell lid must not suspend the operating system or interrupt background compilation, network transfers, or SSH sessions.

### Implementation:
gutterDesk overrides default systemd logind behavior via `/etc/systemd/logind.conf.d/gutterdesk-lid.conf`:

```ini
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

### Architectural Guarantees:
* Laptops continue running full-speed headless operations when closed.
* Display backlights are turned off by the X11 DPMS power management subsystem or kernel display driver without invoking system suspend.
* External display monitors plugged into HDMI/Type-C remain primary without session interruption.

---

## 2. Battery Health & Charge Threshold Daemon

Modern lithium-ion laptop batteries degrade rapidly when held continuously at 100% state-of-charge under AC power. gutterDesk enforces an automated **80% maximum charge threshold** on supported hardware.

### Hardware Detection & Systemd Service:
During bootstrap (`core/06-hardware-power.sh`), the system checks for standard Linux sysfs charge control endpoints:
`/sys/class/power_supply/BAT*/charge_control_end_threshold` (standard across ASUS, Lenovo ThinkPad, Framework, and Dell hardware).

If detected, a persistent systemd oneshot service is provisioned:

```ini
[Unit]
Description=Set Battery Charge Threshold to 80% (Battery Health)
After=multi-user.target
ConditionPathExists=/sys/class/power_supply/BAT0/charge_control_end_threshold

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

### Panel Visibility Guarantee (`tint2rc`):
Under standard desktop environments, power managers hide the battery tray icon once charging stops, causing confusion when capped at 80%.
gutterDesk explicitly overrides this in `dotfiles/tint2/.config/tint2/tint2rc`:
```ini
battery_hide = 101
```
Setting `battery_hide = 101` guarantees that the battery icon, current charging status, and live percentage remain permanently visible in the Tint2 panel at all times.

---

## 3. Dynamic Display Orientation & Wallpaper Engine (`auto-wallpaper`)

gutterDesk workstations often run asymmetric multi-monitor setups (e.g. `AiM-Home` with `DP-0` in 2560x1440 Landscape and `HDMI-0` in 1080x1920 Portrait).

Rather than stretching a single wallpaper across disjoint aspect ratios, the `auto-wallpaper` engine queries the X11 display server and applies orientation-matched wallpapers independently per monitor head.

### Workflow:
```
                      +-----------------------------+
                      |   auto-wallpaper triggered  |
                      |  (at login or post-xrandr)  |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      | Query xrandr --listmonitors |
                      +--------------+--------------+
                                     |
                   +-----------------+-----------------+
                   |                                   |
         Height > Width (Portrait)           Width >= Height (Landscape)
                   |                                   |
                   v                                   v
+------------------------------------+  +------------------------------------+
| Apply portrait.png via nitrogen    |  | Apply landscape.png via nitrogen   |
| head: --head=$idx --set-zoom-fill  |  | head: --head=$idx --set-zoom-fill  |
+------------------------------------+  +------------------------------------+
```

### Script Logic:
```bash
xrandr --listmonitors | awk 'NR>1 {
    idx = substr($1, 1, length($1)-1);
    split($3, geom, "+");
    split(geom[1], dims, "x");
    split(dims[1], w, "/");
    split(dims[2], h, "/");
    print idx, w[1], h[1];
}' | while read -r idx width height; do
    if [ "$height" -gt "$width" ]; then
        nitrogen --head="$idx" --set-zoom-fill "$PORTRAIT" --save
    else
        nitrogen --head="$idx" --set-zoom-fill "$LANDSCAPE" --save
    fi
done
nitrogen --restore
```

---

## 4. Convertible Sensor & Touchscreen Rotation Engine (`gutterdesk-rotator`)

For 2-in-1 laptops and convertible tablets, gutterDesk includes a native screen and input rotation daemon: `gutterdesk-rotator`.

### Sensor Integration:
* Interfaces with `iio-sensor-proxy` over system D-Bus.
* Listens for orientation signals (`normal`, `bottom-up`, `left-up`, `right-up`).

### Input Coordinate Transformation Matrices (CTM):
When a screen rotates, the X11 coordinate space of the display changes, but hardware digitizers and touchscreens report raw physical coordinates unless their Coordinate Transformation Matrix is updated.

`gutterdesk-rotator` queries `xinput` for connected touchscreens, touchpads, and Wacom styluses, applying the mathematical affine transform matrix corresponding to the active rotation:

| Orientation | X11 Rotation | Coordinate Transformation Matrix (CTM) |
| :--- | :--- | :--- |
| **Normal** (Landscape) | `normal` | `1 0 0 0 1 0 0 0 1` (Identity) |
| **Inverted** (Upside Down)| `inverted` | `-1 0 1 0 -1 1 0 0 1` |
| **Left** (Portrait) | `left` | `0 -1 1 1 0 0 0 0 1` |
| **Right** (Portrait) | `right` | `0 1 0 -1 0 1 0 0 1` |

Upon applying the matrix via `xinput set-prop <device> "Coordinate Transformation Matrix" <matrix>`, the daemon immediately calls `auto-wallpaper` to swap the desktop background to the matching aspect ratio.
