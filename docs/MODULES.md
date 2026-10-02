# Capability Modules Specification: gutterDesk

## 1. Modular Architecture Overview

**gutterDesk** adheres to the "Checkbox Distro" principle. Rather than bloating the Universal Base OS with specialized development stacks, capabilities are packaged as modular shell provisioning scripts in `modules/`.

Each module is responsible for:
1. Installing declarative packages from its matching `packages/<module>.list` manifest.
2. Configuring necessary background systemd services, firewall rules, or runtime virtual environments.
3. Enabling corresponding modular Openbox menu items via `gutterdesk-menu enable <module>`.
4. Maintaining strict idempotency so re-running the module updates configurations without duplicating data.

---

## 2. Module Catalog

### Module 1: Creative Suite (`module-creative.sh`)
* **Purpose:** High-performance digital illustration, vector graphics, 3D computer graphics, and non-linear video editing.
* **Package Manifest:** `packages/creative.list`
* **Installed Toolchains:**
  * Vector & Raster: `inkscape`, `gimp`, `krita`, `darktable`, `digikam`
  * 3D & CAD: `blender`, `freecad`
  * Audio & Music: `ardour`, `lmms`
  * Video Production: `kdenlive`, `shotcut`, `handbrake`
* **Desktop Integration:** Registers the "Creative Suite" submenu in Openbox (`menu.d/creative.xml`).
* **Privilege:** Dual (Requires `sudo` for package installation; registers menu as `$TARGET_USER`).

---

### Module 2: Banyan Algorithmic Trading Engine (`module-banyan-engine.sh`)
* **Purpose:** Quantitative trading execution backend, bridging Linux analytical models with Windows MetaTrader 5 execution terminals.
* **Package Manifest:** `packages/banyan-engine.list` (Wine 64-bit, `xvfb`, `libnotify-bin`, `unzip`)
* **Architecture:**
  * **Wine Prefix:** Dedicated 64-bit Wine prefix (`~/.wine_banyan`).
  * **MetaTrader 5 Terminal:** Automated headless download and installation of official MetaTrader 5 (`terminal64.exe`).
  * **Windows Python Runtime:** Windows Python 3.11 embeddable package deployed directly into the Wine prefix with native `MetaTrader5` and `rpyc` RPC libraries.
  * **RPyC Bridge:** Exposes an authenticated RPC server on `127.0.0.1:18812`.
  * **Host Linux Virtualenv:** Python virtual environment at `~/projects/Banyan/.venv` with client RPyC bindings.
  * **Headless Background Service:** Systemd user unit (`~/.config/systemd/user/banyan-engine-headless.service`) running under `xvfb-run` for 24/7 autonomous trading operations.
* **Desktop Integration:** Registers the "Banyan Trading" submenu in Openbox (`menu.d/trading.xml`).

---

### Module 3: Banyan Trading Dashboard (`module-banyan-dashboard.sh`)
* **Purpose:** C++/Qt6 desktop network telemetry dashboard for monitoring algorithmic execution, latency, and positions.
* **Package Manifest:** `packages/banyan-dashboard.list` (Qt6 Core, Gui, Widgets, Network, CMake, build-essential)
* **Architecture:**
  * Clones and builds the native C++ Qt6 dashboard binary (`banyan_daemon`).
  * Deploys desktop entry to `~/.local/share/applications/banyan-dashboard.desktop`.

---

### Module 4: Jellyfin Media Server & Tailscale Mesh (`module-media-tailscale.sh`)
* **Purpose:** Hardware-accelerated media streaming and encrypted WireGuard mesh networking.
* **Package Manifest:** `packages/media-tailscale.list` (`jellyfin`, `jellyfin-ffmpeg6`, `tailscale`)
* **Architecture:**
  * **GPU Hardware Transcoding:** Adds `jellyfin` service account to `video` and `render` groups to grant access to `/dev/dri/renderD128` Intel QuickSync / VA-API endpoints.
  * **Network Ports:** Binds HTTP port `8096` for media streaming.
  * **Tailscale Mesh:** Enables `tailscaled.service` and executes `tailscale up` to join the node to the private mesh network.

---

### Module 5: Web Development Stack (`module-webstack.sh`)
* **Purpose:** Full-stack local web hosting, reverse proxying, and database services.
* **Package Manifest:** `packages/webstack.list` (`apache2`, `postgresql`, `redis-server`, `php`, `composer`)
* **Architecture:**
  * **Apache Modules:** Enables `mod_rewrite`, `mod_ssl`, `mod_proxy`, and `mod_proxy_http`.
  * **Repository Hydration:** Reads `~/.config/gutterdesk/webstack_repos.conf` and automates cloning of core web repositories into `~/projects/`.
  * **Virtual Hosts:** Deploys developer vhosts from `~/.config/gutterdesk/vhosts/*.conf` into `/etc/apache2/sites-available/`.

---

### Module 6: Torrent Machine (`module-torrent.sh`)
* **Purpose:** Dedicated, firewalled background file acquisition node.
* **Package Manifest:** `packages/torrent.list` (`transmission-gtk`, `ufw`)
* **Architecture:**
  * **UFW Firewall Hardening:** Enables `ufw` with a default `deny incoming` policy.
  * **Security Exceptions:** Automatically adds pass-through rules for OpenSSH (Port 22), local LAN subnets, and the Tailscale mesh interface (`tailscale0`).
* **Desktop Integration:** Registers "Torrent" launcher in Openbox (`menu.d/torrent.xml`).

---

### Module 7: NFSv4 Server (`module-nfs-server.sh`)
* **Purpose:** Exports central project repositories (`/home/<user>/projects`) from `aim-stream` to LAN and Tailscale mesh nodes.
* **Package Manifest:** `nfs-kernel-server`
* **Architecture:**
  * **Protocol Hardening:** Configured in `/etc/default/nfs-kernel-server` for **NFSv4-only** (TCP port 2049). NFSv2/v3, UDP, and `rpcbind` dependencies are completely disabled.
  * **Pseudo-Root Scoping:** Exports the target directory with `fsid=0` (pseudo-root). Clients mounting `<server>:/` see only project repositories, isolating `~/.ssh`, `~/.gemini`, and dotfiles.
  * **Allowed Subnets:** Restricts exports strictly to local LAN (`192.168.1.0/24`) and Tailscale mesh (`100.64.0.0/10`).
  * **Firewall Rules:** Injects UFW rules allowing TCP port 2049 from LAN and Tailscale subnets.

---

### Module 8: NFSv4 Client Automount (`module-nfs-client.sh`)
* **Purpose:** Configures resilient, zero-overhead on-demand network storage mounting on client workstations (`AiM-Home`, `aim-book`).
* **Package Manifest:** `nfs-common`
* **Architecture:**
  * **Systemd Automount (`/etc/fstab`):**
    ```fstab
    <server>:/ /home/<user>/<server> nfs4 proto=tcp,port=2049,noauto,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.device-timeout=5,soft,timeo=30,retrans=2,_netdev 0 0
    ```
  * **Zero Idle Overhead:** Connects on demand when `~/<server>` is accessed; automatically unmounts after 60s of inactivity.
  * **Failure Isolation:** Uses `soft` mount with 3-second timeout (`timeo=30,retrans=2`). If the server goes down or the client roams outside Wi-Fi range, access fails immediately with `EIO` rather than hanging the desktop or file manager.
  * **PCManFM Integration:** Adds `~/<server>` to GTK 3 bookmarks (`~/.config/gtk-3.0/bookmarks`) for one-click access in the file manager sidebar.
