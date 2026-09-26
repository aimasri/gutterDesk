# gutterDesk Deployment Roadmap & Quickstart Guide

This guide details how to install and deploy **gutterDesk** on any target laptop, desktop, or workstation.

---

## Step 1: Base Debian 13 Net-Install (USB)
1. Download the minimal **Debian 13 (Trixie) Net-inst ISO**:
   * Choose standard 64-bit PC (`amd64`).
   * Flash to a USB drive using `dd`, Ventoy, or Rufus.
2. Boot the target machine from the USB drive.
3. During Debian installation:
   * Choose your hostname (e.g. `gutterdesk-laptop`, `workhorse`).
   * **Software Selection screen:** Uncheck all desktop environments (GNOME, XFCE, etc.). Check **only**:
     * `SSH server`
     * `Standard system utilities`
4. Complete the installation and reboot into your minimal TTY terminal prompt.

---

## Step 2: Bootstrap the Universal Base
Log into your new machine at the TTY prompt and run:

```bash
# 1. Install git and sudo if not already present
su -
apt update && apt install -y git sudo
usermod -aG sudo <your-username>
exit

# 2. Log back in as your user and clone gutterDesk
git clone https://github.com/aimasri/gutterDesk.git ~/projects/gutterDesk
cd ~/projects/gutterDesk

# 3. Run the Universal Base bootstrap
./bootstrap.sh
```

### What `bootstrap.sh` does automatically:
1. Adds bundled GPG keys and APT repositories for Google Chrome and Antigravity IDE.
2. Installs all packages in `packages/base.list` (Openbox, Tint2, PCManFM, Guake, Scrot, Viewnior, Atril, build tools).
3. Symlinks your **Midnight Forest** dotfiles into `$HOME` via GNU Stow.
4. Deploys landscape, portrait, and branding wallpapers to `~/.local/share/backgrounds/`.
5. Clones and compiles `gutterDeck` and `gutterTab` from GitHub.
6. Sets up LightDM login manager to boot directly into Openbox.

---

## Step 3: Run the Modular Checkbox Installer (`install.sh`)
Once logged into your new graphical desktop, open Guake (`F12`) or a terminal and run:

```bash
cd ~/projects/gutterDesk
./install.sh
```

A clean checkbox menu will appear on your screen:
* **[ ] 1. Creative Suite** (GIMP, Krita, Inkscape, Blender, Kdenlive, etc.)
* **[ ] 2. Banyan Trading Engine** (Wine64, Python venv, MT5 daemon)
* **[ ] 3. Banyan Trading Dashboard** (C++ monitoring UI)
* **[ ] 4. Jellyfin & Tailscale** (Media streaming + remote mesh node)
* **[ ] 5. Web Development Stack** (Apache2, Postgres, Redis, vhosts)
* **[ ] 6. Torrent Machine** (Transmission-gtk & UFW)

Simply press `Space` to check the modules you want for this machine, press `Enter`, and the installer will provision the selected software and repositories.

---

## Step 4: Restoring Private User Profiles (Optional)
If you have backed up your private profiles and personal notes using `gutterdesk-private-backup`:

```bash
# Insert your backup USB drive or copy from Google Drive
cd /path/to/gutterdesk-private-backup
./restore-private-profile.sh
```

This restores personal `gutterDeck` profiles, `gutterTab` notes databases, SSH multi-account configurations, and personal wallpapers with zero manual intervention.

---

## Step 5: Maintenance & Network-Wide Dotfile Updates
Because all configuration files (`~/.config/openbox`, `~/.config/tint2`, `~/.config/pcmanfm`) are **symlinks** pointing back to `~/projects/gutterDesk/dotfiles/`:

1. Any changes you make to keybindings, tint2 colors, or menus are tracked directly inside git.
2. Commit and push from any machine:
   ```bash
   cd ~/projects/gutterDesk
   git commit -am "Updated keybinding" && git push
   ```
3. On any other machine on your network:
   ```bash
   cd ~/projects/gutterDesk && git pull
   openbox --reconfigure
   pkill -SIGUSR1 tint2
   ```
   Both Openbox and Tint2 will update instantaneously across all screens simultaneously.
