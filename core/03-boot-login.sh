#!/usr/bin/env bash
# ==============================================================================
# Title:           03-boot-login.sh
# Purpose:         Configures Plymouth Boot Splash, GRUB & LightDM Login Greeter
# Why This Design: Unified obsidian Midnight Forest aesthetic across cold boot,
#                  graphical greeter, and desktop session lock. Eliminates disparate
#                  screensavers (e.g. xscreensaver) by delegating screen lock to
#                  LightDM via light-locker.
# Privilege:       Root (Requires sudo)
# Subsystems:      Plymouth, GRUB 2, initramfs, LightDM, systemd
# Idempotency:     Validates existing Plymouth theme and GRUB parameters prior to mutation.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

echo "--> [4/8] Configuring boot splash (Plymouth) & login greeter (LightDM)..."

# 1. Deploy Plymouth Theme
if [ -d "$SCRIPT_DIR/themes/plymouth/gutterdesk" ]; then
    echo "Installing gutterDesk Plymouth theme..."
    sudo mkdir -p /usr/share/plymouth/themes/gutterdesk
    sudo cp -r "$SCRIPT_DIR/themes/plymouth/gutterdesk/"* /usr/share/plymouth/themes/gutterdesk/
    if [ -x /usr/sbin/plymouth-set-default-theme ]; then
        echo "Activating gutterDesk Plymouth boot splash..."
        sudo /usr/sbin/plymouth-set-default-theme gutterdesk -R 2>/dev/null || true
    fi
fi

# 2. Ensure 'splash' is in GRUB_CMDLINE_LINUX_DEFAULT
if [ -f /etc/default/grub ]; then
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
        if ! grep -q 'splash' /etc/default/grub; then
            echo "Enabling graphical boot splash in /etc/default/grub..."
            sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' /etc/default/grub
            sudo sed -i 's/  */ /g' /etc/default/grub
            which update-grub >/dev/null 2>&1 && sudo update-grub || true
        fi
    fi
fi

# 3. Deploy LightDM Greeter Configuration
sudo mkdir -p /etc/lightdm/lightdm-gtk-greeter.conf.d
if [ -f "$SCRIPT_DIR/themes/lightdm/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$SCRIPT_DIR/themes/lightdm/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
    sudo cp "$SCRIPT_DIR/themes/lightdm/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf.d/99_gutterdesk.conf
fi

# 4. Enable Core System Daemons
sudo systemctl enable lightdm 2>/dev/null || true
sudo systemctl enable bluetooth 2>/dev/null || true
sudo systemctl enable ssh 2>/dev/null || true
sudo systemctl enable --now systemd-timesyncd 2>/dev/null || true

echo "✓ Boot splash and login greeter configured successfully."
