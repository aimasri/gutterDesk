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
   * Hostname: choose your machine name (e.g. `aim-stream`, `gutterdesk-laptop`).
   * **Domain Name:** **Leave completely blank** (prevents DNS conflicts on roaming Wi-Fi).
3. **User Account:**
   * Enter your name and pick your standard username (e.g. `ahmed`).
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

## 3. Post-Boot: Sudo Configuration & Base Bootstrap

Once rebooted into the text TTY console (`login:`):

### Step A: Configure Sudo Permissions
Debian minimal does not add normal users to `sudoers` if a root password was created. Run this one-time fix:

```bash
su -
# (Enter your root password)

apt install -y sudo git
echo "ahmed ALL=(ALL:ALL) ALL" > /etc/sudoers.d/ahmed
chmod 0440 /etc/sudoers.d/ahmed
exit
```

### Step B: Run Universal Base Bootstrap
Log in as your normal user (`ahmed`) and run:

```bash
git clone https://github.com/aimasri/gutterDesk.git ~/projects/gutterDesk
cd ~/projects/gutterDesk
./bootstrap.sh
```

#### What `bootstrap.sh` does automatically:
1. Injects official GPG keys and APT repos for Google Chrome and Antigravity IDE.
2. Installs Universal Base packages (X11, Openbox, Tint2, PCManFM, Geany, Guake, Scrot, Viewnior, Atril, LightDM, Plymouth, build toolchain).
3. Deploys custom **Midnight Forest** and **gutterDesk** dotfiles into `$HOME` via GNU Stow.
4. Deploys multi-monitor wallpapers, brand icons, and system-wide GTK themes.
5. Installs and activates the **gutterDesk Plymouth boot splash** theme (centered vector emblem + rotating neon spinner on `#080c0e` obsidian).
6. Configures GRUB bootloader parameters (`quiet splash`) and rebuilds initramfs.
7. Configures the matching **gutterDesk LightDM GTK greeter** login screen (centered obsidian login card, Papirus-Dark icons, custom GTK styling).
8. Clones and compiles **`gutterDeck`** and **`gutterTab`** from GitHub into `~/.local/bin/`.

Once completed, reboot:
```bash
sudo reboot
```

---

## 4. Modular Checkbox Installer (`install.sh`)

Once logged into your graphical desktop, open a terminal or press `F12` (Guake) and run:

```bash
cd ~/projects/gutterDesk
./install.sh
```

An interactive checkbox menu lets you provision specialized environments on demand:
* **[ ] 1. Creative Suite** (GIMP, Krita, Inkscape, Blender, Kdenlive)
* **[ ] 2. Banyan Trading Engine** (Wine64, Python venv, MT5 daemon)
* **[ ] 3. Banyan Trading Dashboard** (C++ monitoring UI)
* **[ ] 4. Jellyfin & Tailscale** (Media streaming + remote mesh node)
* **[ ] 5. Web Development Stack** (Apache2, Postgres, Redis, dnsmasq, vhosts)
* **[ ] 6. Torrent Machine** (Transmission-gtk & UFW)

Press `Space` to select modules and `Enter` to install.

---

## 5. Restoring Private Profiles & Identity Keys

To restore personal notes, dock profiles, and multi-account SSH keys from your private backup archive:

```bash
# 1. Extract archive to ~/projects/
tar -xzf /path/to/gutterdesk-private-backup.tar.gz -C ~/projects/

# 2. Run the automated restore script
cd ~/projects/gutterdesk-private-backup
./restore-private-profile.sh
```

### What is Restored:
* **SSH Keys:** Restores `id_ed25519`, `github_fussybaby`, `github_urbansugar`, `id_ed25519_vps`, and sets `600`/`700` permissions.
* **gutterDeck:** Restores all personal dock launcher profiles (`default`, `creative`, `entertainment`, etc.).
* **gutterTab:** Restores SQLite `notes.db` with personal notes, bookmarks, and drawer settings.
* **Wallpapers:** Restores personal wallpaper library to `~/images/wallpapers/`.

---

## 6. Multi-Machine Maintenance & Dotfile Synchronization

All configurations (`~/.config/openbox`, `~/.config/tint2`, `~/.config/pcmanfm`) are live symlinks to `~/projects/gutterDesk/dotfiles/`.

* **To push a configuration change from any machine:**
  ```bash
  cd ~/projects/gutterDesk
  git commit -am "Updated keybindings or panel" && git push
  ```

* **To apply updates on another machine on your network:**
  ```bash
  cd ~/projects/gutterDesk && git pull
  openbox --reconfigure
  pkill -SIGUSR1 tint2
  ```
