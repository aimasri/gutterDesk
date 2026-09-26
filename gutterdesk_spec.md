# gutterDesk Specification

**gutterDesk** is a reproducible, tactile, modular Linux workspace distribution built on Debian 13 (Trixie). Designed as the foundational desktop operating system for the **gutter** productivity ecosystem (alongside **gutterDeck** and **gutterTab**), it combines ultra-lightweight performance, edge-docked utility workflows, and declarative modular system deployment.

---

## 1. Architectural Philosophy: The "Checkbox" Distro
* **Base System:** Debian 13 (Trixie) Net-install.
* **Goal:** A single Universal Base OS. Rather than maintaining disparate OS images for laptops, workstations, and servers, every machine receives an identical, rock-solid base environment. Additional functional capabilities are provisioned on-demand via an interactive **Modular Checkbox System** (`./install.sh`).

---

## 2. The Universal Foundation (gutterDesk Core)
*Every installation provisions this lightweight core:*
* **Kernel:** Debian kernel (Linux 6.12+)
* **Init System:** systemd
* **Package Manager:** apt / dpkg
* **Window Management:** Openbox 3 + Picom (X11 Compositor) + Tint2 (Multi-desktop tactile status bar) + LightDM
* **Theme & Palette:** **Midnight Forest** (Obsidian dark base `#060d08` with deep pine accents and sage text highlights `#629e79`)
* **Core Utilities:** Guake (`F12` dropdown terminal), PCManFM (`F3` dual-pane & tabs file manager), gmrun (Application launcher)
* **Viewers & Media:** Viewnior (Images), Atril (Documents/PDFs), VLC (Audio/Video), Scrot (Full & region screenshots)
* **Browsers:** Google Chrome (Multi-profile daily driver) and Chromium (Profile-free testing)
* **AI & Code:** Antigravity IDE (Configured with agent rules and IDE preferences)
* **Productivity Suite:** 
  * `gutterDeck`: Edge-anchored compositor accordion application dock
  * `gutterTab`: Pull-out note drawer and workspace prompt daemon
* **Wireless & Network:** Intel Wireless Daemon (`iwd`) + `iwgtk` + native zero-overhead Tint2 network executor (`tint2-network.sh`)
* **Remote Access:** OpenSSH Server (`openssh-server`, systemd enabled by default)
* **Configuration Deployment:** Direct atomic symlinks (`ln -sf`), eliminating configuration drift with zero package overhead
* **Wallpaper Engine:** Dynamic orientation detection via `auto-wallpaper.sh` (applies landscape or portrait wallpapers automatically per connected monitor)

---

## 3. Modular Capability Architecture (The Checkboxes)
Activate only the modules required for the target machine:

* **[ ] Module 1: Creative Suite (`modules/module-creative.sh`)**
  * *Purpose:* Digital illustration, vector graphics, 3D modeling, and video production.
  * *Includes:* Inkscape, Krita, GIMP, Darktable, DigiKam, Blender, FreeCAD, Ardour, LMMS, Kdenlive, Shotcut, Handbrake.

* **[ ] Module 2: Banyan Trading Engine (`modules/module-banyan-engine.sh`)**
  * *Purpose:* Quantitative algorithmic trading backend.
  * *Includes:* Wine64, Python 3 virtual environment, pandas, numpy, pytz, mt5linux. Configurable repository URL via `~/.config/gutterdesk/banyan.conf`.

* **[ ] Module 3: Banyan Trading Dashboard (`modules/module-banyan-dashboard.sh`)**
  * *Purpose:* C++/Qt6 desktop network telemetry dashboard.
  * *Includes:* Qt6 Core/Gui/Widgets/Network, XCB window management, compiled `banyan_daemon` binary.

* **[ ] Module 4: Jellyfin Media Server & Tailscale (`modules/module-media-tailscale.sh`)**
  * *Purpose:* Encrypted remote access and hardware-accelerated media streaming.
  * *Includes:* Tailscale WireGuard mesh node, Jellyfin server with `/dev/dri` GPU hardware transcoding permissions.

* **[ ] Module 5: Web Development Stack (`modules/module-webstack.sh`)**
  * *Purpose:* Multi-domain web hosting, reverse proxying, and local development.
  * *Includes:* Apache2 (with rewrite/ssl/proxy modules), PostgreSQL, Redis, dnsmasq. Repositories cloned via manifest (`~/.config/gutterdesk/webstack_repos.conf`).

* **[ ] Module 6: Torrent Machine (`modules/module-torrent.sh`)**
  * *Purpose:* Isolated background file acquisition.
  * *Includes:* Transmission-gtk and UFW firewall rules.

---

## 4. Design Exclusions (Global Bloat Removed)
*Explicitly omitted from the Universal Base to preserve minimal resource usage (<400MB idle RAM):*
* Desktop environments (GNOME, KDE, XFCE)
* Heavy file managers (Thunar, Nautilus) -> Replaced with PCManFM
* Conky (Removed to eliminate background X11 rendering overhead)
* `snapd` & `flatpak` (Unless explicitly enabled by a user module)
* ModemManager & CUPS (Disabled by default)
* Default Debian desktop tasks (Games, LibreOffice, generic metapackages)
