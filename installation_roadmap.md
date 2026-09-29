# gutterDesk Complete Installation & Deployment Guide

This document is the definitive end-to-end guide for installing and configuring **gutterDesk** on any target laptop, desktop, or workstation.

---

## 1. Pre-Installation: BIOS / UEFI Firmware Setup

Before booting the USB installer on a target machine (especially modern laptops like ASUS, Lenovo, HP, Dell):

1. **Enter BIOS Setup:**
   * **ASUS:** Tap `F2` or `Delete` upon power on (or `Esc` for boot menu).
   * **Lenovo:** Tap `F12` or `Fn + F2` (or press the side Novo button).
   * **Dell:** Tap `F12`.
   * **HP:** Tap `Esc` repeatedly, then press `F10` for BIOS (`F9` for Boot Menu).
2. **Key Firmware Settings:**
   * **Secure Boot:** Set to **`Disabled`** (or in ASUS: *Security* -> *Key Management* -> *Delete Platform Key (PK)*).
   * **Fast Boot:** Set to **`Disabled`**.
   * **Boot Mode:** Set to **`UEFI`** (never Legacy/CSM).
   * **Storage Controller (Intel Laptops):** If Intel VMD is present under *Advanced* -> *VMD Setup Menu*, set **Enable VMD Controller** to **`Disabled`** (native AHCI).
3. **Save and Exit:** Press `F10`.

---

## 2. Base Debian 13 Net-Install (USB)

### Flash the USB Drive
* Download the minimal **Debian 13 (Trixie) Net-inst ISO** (`amd64`).
* Flash with Ventoy (recommended) or `dd`:
  ```bash
  sudo dd if=debian-13.x-amd64-netinst.iso of=/dev/sdX bs=4M status=progress conv=fsync
  ```

### Installer Walkthrough
1. **Boot:** Press your machine's boot menu key (ASUS: `F8` or `Esc`; Lenovo/Dell: `F12`; HP: `F9`) and select the **UEFI USB Drive**.
2. **Network & Domain:**
   * Hostname: choose your machine name (e.g. `aim-stream`, `aim-book`).
   * **Domain Name:** **Leave completely blank** (prevents DNS conflicts on roaming Wi-Fi).
3. **User Account & Root Password:**
   * **Root Password:** **Leave completely blank / empty** (Debian will disable the root account and automatically grant full `sudo` privileges to your user).
   * **Username:** Enter your name and choose your standard username (e.g. `ahmed`).
4. **Partitioning:**
   * Select: **"Guided - use entire disk"**.
   * Select: **"All files in one partition"** (pools root `/`, Docker, Postgres, and `/home` dynamically into one storage pool).
   * Select: **"Finish partitioning and write changes to disk"** -> **Yes**.
5. **Software Selection (`tasksel`):**
   * `[ ] Debian desktop environment` **<-- UNCHECK**
   * `[ ] ... (all other desktops GNOME, XFCE, KDE)` **<-- UNCHECK**
   * `[ ] choose a debian blend` **<-- UNCHECK**
   * `[*] SSH server` **<-- CHECK**
   * `[*] standard system utilities` **<-- CHECK**
6. **GRUB Bootloader:**
   * If prompted: *"Force GRUB installation to the EFI removable media path?"* -> Select **`<Yes>`**.
7. **Reboot:** When it displays *"Installation complete"*, unplug the USB and reboot.

---

## 3. Post-Boot: Universal Base Bootstrap

> [!NOTE]
> During the Debian installer, leave the root password **blank / empty**. Debian will automatically disable root and grant full `sudo` privileges to your user account.

Once rebooted into the text console (`login:`), log in as your regular user and bootstrap the desktop:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/aimasri/gutterDesk.git ~/gutterDesk
cd ~/gutterDesk
sudo ./bootstrap.sh
```

#### What `bootstrap.sh` does automatically:
1. Injects official GPG keys and APT repos for Google Chrome and Antigravity IDE.
2. Installs Universal Base packages (X11, Openbox, Tint2, PCManFM, Geany, Guake, Scrot, Viewnior, Atril, LightDM, Plymouth, openssh-server, build toolchain).
3. Migrates netinst Wi-Fi credentials into `iwd` profiles (`/var/lib/iwd/`), enables `iwd`, and disables bloated legacy network services.
4. Deploys custom **Midnight Forest** dotfiles into `$HOME` via direct atomic symlinks (`ln -sf`).
5. Deploys multi-monitor wallpapers, brand icons, and system-wide GTK themes.
6. Installs and activates the **gutterDesk Plymouth boot splash** theme (centered vector emblem + rotating neon spinner on `#080c0e` obsidian).
7. Configures GRUB bootloader parameters (`quiet splash`) and rebuilds initramfs.
8. Configures the matching **gutterDesk LightDM GTK greeter** login screen (centered obsidian login card, Papirus-Dark icons, custom GTK styling).
9. Configures `light-locker` with `--lock-on-suspend --lock-on-lid --no-late-locking` for unified login and lock screens without `xscreensaver`.
10. Clones and compiles **`gutterDeck`** and **`gutterTab`** from GitHub into `/usr/local/bin/` and `~/.local/bin/`.
11. Configures the native Tint2 network executor (`~/.local/bin/tint2-network.sh`) with dynamic Papirus Wi-Fi signal icons.
12. Heals `$HOME` permissions recursively to prevent `.Xauthority` or config permission locks.

Once completed, reboot:
```bash
sudo reboot
```

---

## 4. Modular Checkbox Installer (`install.sh`)

Once logged into your graphical desktop, open a terminal or press `F12` (Guake) and run:

```bash
cd ~/gutterDesk
./install.sh
```

An interactive checkbox menu lets you provision specialized environments on demand:
* **[ ] 1. Creative Suite** (GIMP, Krita, Inkscape, Blender, Kdenlive)
* **[ ] 2. Banyan Trading Engine** (Wine64, Python venv, MT5 daemon)
* **[ ] 3. Banyan Trading Dashboard** (C++ monitoring UI)
* **[ ] 4. Jellyfin & Tailscale** (Media streaming + remote mesh node)
* **[ ] 5. Web Development Stack** (Apache2, Postgres, Redis, vhosts)
* **[ ] 6. Torrent Machine** (Transmission-gtk & UFW firewall configured for Tailscale/SSH)
* **[ ] 7. NFSv4 Server** (Hardened NFSv4-only export of `/home/ahmed/projects` on `aim-stream`)
* **[ ] 8. NFSv4 Client Automount** (Resilient systemd on-demand automount for client workstations)

Press `Space` to select modules and `Enter` to install.

---

## 5. Restoring Private Profiles & Identity Keys

To restore personal notes, dock profiles, multi-account SSH keys, and project environments:

```bash
# 1. Extract archive to ~/gutterDesk/backup/
mkdir -p ~/gutterDesk/backup
tar -xzf /path/to/gutterdesk-private-backup.tar.gz -C ~/gutterDesk/backup/ --strip-components=1
cd ~/gutterDesk/backup

# 2. Stage 1: Connect machine identity, SSH keys, Antigravity, and profiles (Run before cloning/mounting)
./connect.sh

# 3. Stage 2: Sync project .env credentials (Run after cloning or mounting your projects)
./sync.sh

# (Or run ./restore.sh to execute both stages sequentially)
```

### What is Restored:
* **Stage 1 (Identity & System):**
  * **SSH Keys:** Restores `id_ed25519`, `github_fussybaby`, `github_urbansugar`, `id_ed25519_vps`, with secure `600`/`700` permissions.
  * **Webstack Configuration:** Restores `~/.config/gutterdesk/hosts`, `~/.config/gutterdesk/vhosts/*.conf`, and repository manifest (`webstack_repos.conf`).
  * **Banyan Engine Profiles:** Restores `~/.config/banyan/engines.json` with clean symmetric LAN discovery profiles.
  * **Antigravity Profile:** Restores custom skills, learned knowledge, directives, and MCP tools.
  * **gutterDeck & gutterTab:** Restores dock profiles and SQLite `notes.db` personal notes.
  * **MetaTrader 5 Config:** Restores saved broker servers, demo/live accounts, and terminal settings.
  * **Wallpapers:** Restores personal wallpaper library to `~/images/wallpapers/`.
* **Stage 2 (Project Environments):**
  * **Environment Secrets:** Injects `.env` and `infrastructure.env` files into cloned repositories (`Urban Sugar`, `FussyBaby`, `BeautyVault`, `Magma`). Fully idempotent.
  * **Apache Vhost Sync:** Activates and reloads custom Apache virtual hosts for cloned web projects.
  * **Banyan Service Reload:** Automatically restarts active Banyan trading engine service to apply injected credentials.

---

## 6. Multi-Machine Maintenance & Dotfile Synchronization

All configurations (`~/.config/openbox`, `~/.config/tint2`, `~/.config/pcmanfm`) are live symlinks to `~/gutterDesk/dotfiles/`.

* **To push a configuration change from any machine:**
  ```bash
  cd ~/gutterDesk
  git commit -am "Updated keybindings or panel" && git push
  ```

* **To apply updates on another machine on your network:**
  ```bash
  cd ~/gutterDesk && git pull
  openbox --reconfigure
  pkill -SIGUSR1 tint2
  ```
