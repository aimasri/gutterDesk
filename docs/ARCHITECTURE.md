# gutterDesk Architecture Specification

## 1. Operating System Foundation

**gutterDesk** is a minimalist, tactile, and modular desktop Linux distribution built on **Debian 13 (Trixie)**. It serves as the foundational operating system for the **gutter** productivity ecosystem (alongside **gutterDeck** and **gutterTab**).

The architecture is driven by three core tenets:
1. **The Universal Base Core:** Every machine (whether a central headless development host, a dual-monitor workstation, or a mobile laptop) boots an identical, ultra-lightweight base environment consuming **<400 MB idle RAM** with 0% idle CPU overhead.
2. **On-Demand Capability Modules:** Additional functional stacks (Creative, Algorithmic Trading, Web Services, Media Streaming) are provisioned modularly via an interactive checkbox engine (`./install.sh`) rather than baked into bloated monolithic system images.
3. **Two-Tier Development Topology:** All active development codebases and runtime databases reside on a central headless server (`<server-hostname>`). Client workstations mount project trees on demand via resilient, zero-overhead NFSv4 automounts and execute code remotely via the native Google Antigravity SSH Remote engine.

---

## 2. Subsystem Architecture

```
+-----------------------------------------------------------------------------------+
|                                gutterDesk Desktop                                 |
|  +--------------------+  +----------------------+  +---------------------------+  |
|  |     gutterDeck     |  |       gutterTab      |  |         Openbox 3         |  |
|  |   Accordion Dock   |  |   Edge Note Drawer   |  |  Midnight Forest Manager  |  |
|  +--------------------+  +----------------------+  +---------------------------+  |
+-----------------------------------------------------------------------------------+
|                                 Tactile Layer                                     |
|  +--------------------+  +----------------------+  +---------------------------+  |
|  |       Tint2        |  |        Picom         |  |      Guake (Twilight)     |  |
|  | Multi-Head Panel   |  |   X11 Compositor     |  |   Dropdown Terminal (F12) |  |
|  +--------------------+  +----------------------+  +---------------------------+  |
+-----------------------------------------------------------------------------------+
|                             Core Linux Services                                   |
|  +--------------------+  +----------------------+  +---------------------------+  |
|  |    iwd + iwgtk     |  |      systemd-logind  |  |     NFSv4 Automount       |  |
|  |   Wireless Stack   |  |  Lid & Battery Mgmt  |  |   Kernel Network FS       |  |
|  +--------------------+  +----------------------+  +---------------------------+  |
+-----------------------------------------------------------------------------------+
|                        Debian 13 (Trixie) Linux Kernel                            |
+-----------------------------------------------------------------------------------+
```

### A. Window Management & Display
* **Display Server:** X11 (`xserver-xorg`). Chosen over Wayland for strict compatibility with Openbox, Guake dropdown geometry, custom edge-docked X11 overlay windows (`gutterDeck`, `gutterTab`), and seamless multi-monitor display orientation scripting.
* **Window Manager:** Openbox 3. Ultra-minimal, keyboard-navigable, with window border decors styled in the bespoke **Midnight Forest** palette (`#060d08` obsidian base, `#629e79` sage border accents).
* **Compositor:** Picom. Provides subtle shadows and opacity transitions without adding GPU rendering latency or input lag.
* **Status Panel:** Tint2. Configured for multi-monitor desktop display with dynamic desktop taskbars, systray integration, and native zero-overhead background executors (e.g. `tint2-network`).

### B. Wireless & Network Stack
* **Engine:** Intel Wireless Daemon (`iwd`). Replaces legacy `wpa_supplicant` and heavy NetworkManager daemons.
* **Control UI:** `iwgtk` configured in a dark obsidian theme. Provides quick Wi-Fi scanning and connection without a persistent background tray daemon.
* **Signal Telemetry:** Native Tint2 executor script (`tint2-network`) that queries `iwctl station <wlan> show` at 15-second intervals, formatting RSSI signal strength directly into Papirus-Dark iconography with zero memory footprint.

### C. Display Manager & Boot Splash
* **Boot Splash:** Plymouth custom `gutterdesk` theme. Features a centered vector brand emblem on `#080c0e` dark obsidian background, paired with a custom neon sage progress spinner (`spinner-00.png` through `spinner-29.png`).
* **Display Manager:** LightDM with `lightdm-gtk-greeter`. Styled to mirror the Plymouth boot splash and desktop lock screen, providing visual continuity from initial power-on through desktop session entry.
* **Screen Locker:** `light-locker` configured with `--lock-on-suspend --lock-on-lid --no-late-locking`. Avoids disparate lockscreens (e.g. `xscreensaver`) by reusing the LightDM obsidian greeter card.

---

## 3. Remote Development & Network Storage Topology

To eliminate configuration drift, file duplication, and background synchronization overhead across physical machines, gutterDesk enforces a strict two-tier development topology:

```
                      +---------------------------------------+
                      |           gutterdesk-server           |
                      |   Central Headless Development Host   |
                      |   - Hosts /home/<user>/projects       |
                      |   - NFSv4 Server (fsid=0 pseudo-root) |
                      |   - Docker, Postgres, MT5/Wine        |
                      |   - Antigravity 2.0 Remote Control    |
                      +-------------------+-------------------+
                                          |
                        Tailscale Mesh & Local LAN
                                          |
            +-----------------------------+-----------------------------+
            |                                                           |
+-----------v---------------------------+   +---------------------------v-----------+
|          workstation-client           |   |             laptop-client             |
|     Dual-Monitor Workstation Client   |   |          Laptop Mobile Client         |
| - DP-0 (Landscape) + HDMI-0 (Portrait)|   | - Single eDP-1 Display                |
| - On-demand NFSv4 Automount           |   | - On-demand NFSv4 Automount           |
| - No local ~/projects repositories    |   | - Battery Charge Limit (80%)          |
| - Antigravity IDE (Remote SSH Engine) |   | - Lid Switch Ignore (Server Posture)  |
+---------------------------------------+   +---------------------------------------+
```

### Machine Roles & Responsibilities

#### 1. Central Development Server:
* Hosts all source code repositories in `/home/<user>/projects`.
* Executes system services, runtime interpreters, build toolchains, and background database engines (PostgreSQL, Redis, Apache2, Wine/MT5).
* Exports `/home/<user>/projects` via a hardened NFSv4-only server to local LAN (`192.168.1.0/24`) and Tailscale mesh (`100.64.0.0/10`) subnets.
* **Fixed Router DHCP Reservation:** Requires a static lease on the local broadband router binding its physical MAC address to its assigned LAN IP. This guarantees deterministic NFS sockets and Banyan UDP discovery (`18814` / `18813`) without hardcoding static network profiles on the host.

#### 2. Client Workstations:
* **No Local Project Repositories:** Local `~/projects` directories are purged on client machines to prevent version divergence and configuration drift.
* Client machines contain only the operating system repository and private credentials at `~/gutterDesk`.
* Projects are browsed casually via an on-demand systemd NFSv4 automount at `~/<server-hostname>`.
* Code editing and compilation are handled by connecting Antigravity IDE directly to the central development server via Google's native `antigravity-remote-openssh` extension.

### Storage Tier: Resilient Systemd NFSv4 Automount
* **Mount Configuration (`/etc/fstab` on clients):**
  ```fstab
  <server>:/ /home/<user>/<server> nfs4 proto=tcp,port=2049,noauto,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.device-timeout=5,soft,timeo=30,retrans=2,_netdev 0 0
  ```
* **Architectural Guarantees:**
  * **Zero Idle Overhead:** Connects on demand only when accessed. Automatically unmounts after 60 seconds of inactivity (`x-systemd.idle-timeout=60`).
  * **Fault Tolerance & Roaming Safety:** If a client laptop disconnects from Wi-Fi or leaves the LAN, the `soft` mount with a 3-second timeout (`timeo=30,retrans=2`) immediately returns `EIO` to user space. It **never freezes** the Openbox desktop session, file manager, or system shutdown process.
  * **Pseudo-Root Scoping (`fsid=0`):** The server exports `~/projects` as the NFSv4 pseudo-root (`fsid=0`). Client mounts mounting `<server>:/` access exclusively project codebases while completely hiding the server's private SSH keys (`~/.ssh`), credentials (`~/.gemini`), and session files (`.Xauthority`).

### Development Domain Routing & Standby Failover Architecture (`*.test`)

To ensure seamless browser-based development without running heavy web/database servers on client laptops, gutterDesk implements a decoupled domain routing architecture:

1. **Declarative Domain Manifest (`packages/dev-domains.list`):**
   Active local domains (`urbansugar.test`, `fussybaby.test`, `legacy.fussybaby.test`, `magma.test`) are maintained declaratively.
2. **Central Server Routing:**
   * **Primary Server (`aim-stream`):** Hosts Apache, PostgreSQL, Redis, and codebases. Development domains resolve locally to `127.0.0.1`.
   * **Client Workstations (`aim-book`, `aim-home`):** Route development domains to the central development server IP (`192.168.1.10` LAN or `100.67.215.75` Tailscale).
3. **Standby Failover Workstation Model (`aim-home`):**
   * Primary workstations can install the full webstack (`module-webstack.sh`) to serve as a redundant standby server.
   * **Split-Brain Immunity:** To prevent divergent database records and stale session state, domain routing on the standby workstation points to the primary server by default.
   * **Instant Failover:** If the central server is offline, running `gutterdesk-dev-route local` on the standby machine immediately repoints domains to its local Apache/PostgreSQL instance.
4. **Roaming Mesh Mobility (`aim-book`):**
   * On home/office Wi-Fi: `gutterdesk-dev-route lan` binds domains to `192.168.1.10` for zero-latency wire speed.
   * Off-site / roaming: `gutterdesk-dev-route tailscale` binds domains to `100.67.215.75`, routing browser and API calls securely over Tailscale.

---

## 4. Dotfile Architecture & Atomic Deployment

gutterDesk rejects heavy external dotfile managers (e.g. Chezmoi, GNU Stow) in favor of direct atomic symlinking (`ln -sf`).

* **Source Directory:** `dotfiles/<category>/` in the repository root.
* **Separation of Concerns:** `dotfiles/` contains pure configuration files. Binaries and system scripts are located in `bin/` and deployed to `/usr/local/bin/` or `~/.local/bin/`.
* **Deployment Mechanism:** `core/04-dotfiles.sh` walks each category, mirrors parent directory structures in `$TARGET_HOME`, and atomically creates symlinks pointing back to the repository.
* **Configuration Drift Immunity:** Because `$TARGET_HOME/.config/...` files are direct symlinks to the git repository, any modification made in the desktop environment is immediately reflected in `git status` on the development server.
