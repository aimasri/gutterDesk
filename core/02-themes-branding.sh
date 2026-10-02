#!/usr/bin/env bash
# ==============================================================================
# Title:           02-themes-branding.sh
# Purpose:         Deploys Wallpapers, System Themes, Brand Icons & Desktop Entries
# Why This Design: Establishes visual continuity across user and system levels
#                  (boot splash, login greeter, Openbox, and Tint2). Distributes
#                  Papirus-compatible icons to /usr/share/icons/hicolor/ and
#                  orientation-matched wallpapers to /usr/share/backgrounds/.
# Privilege:       Dual (Requires sudo for /usr/share/; deploys user assets as target user)
# Subsystems:      GTK 2/3, XDG Icon Specification, XDG Desktop Entries
# Idempotency:     Overwrites assets in place; runs gtk-update-icon-cache and
#                  update-desktop-database safely.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

run_as_target() {
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$TARGET_USER" != "root" ]; then
        sudo -u "$TARGET_USER" -H "$@"
    else
        "$@"
    fi
}

echo "--> [3/8] Deploying wallpapers, branding & system themes..."

# 1. User-space assets
sudo mkdir -p "$TARGET_HOME/.local/share/backgrounds" "$TARGET_HOME/.local/share/icons"
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local" 2>/dev/null || true
run_as_target cp "$SCRIPT_DIR/wallpapers/"*.png "$TARGET_HOME/.local/share/backgrounds/" 2>/dev/null || true
run_as_target cp -r "$SCRIPT_DIR/assets/icons/"* "$TARGET_HOME/.local/share/icons/" 2>/dev/null || true

# 2. System-wide assets
sudo mkdir -p /usr/share/backgrounds/gutterdesk /usr/share/icons/gutterdesk /usr/share/themes/gutterdesk
sudo cp "$SCRIPT_DIR/wallpapers/"*.png /usr/share/backgrounds/gutterdesk/ 2>/dev/null || true
sudo cp -r "$SCRIPT_DIR/assets/icons/"* /usr/share/icons/gutterdesk/ 2>/dev/null || true

if [ -d "$SCRIPT_DIR/dotfiles/themes/.themes/gutterdesk" ]; then
    sudo cp -r "$SCRIPT_DIR/dotfiles/themes/.themes/gutterdesk"/* /usr/share/themes/gutterdesk/ 2>/dev/null || true
fi

# 3. Deploy system icons to /usr/share/pixmaps/ and /usr/share/icons/hicolor/
echo "Deploying system-wide icons..."
sudo mkdir -p /usr/share/pixmaps
for app in gutterdesk gutterdeck guttertab; do
    if [ -f "$SCRIPT_DIR/assets/icons/${app}.svg" ]; then
        sudo cp "$SCRIPT_DIR/assets/icons/${app}.svg" /usr/share/pixmaps/
        sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
        sudo cp "$SCRIPT_DIR/assets/icons/${app}.svg" "/usr/share/icons/hicolor/scalable/apps/${app}.svg"
    fi
    for sz in 16 24 32 48 64 128 256 512; do
        if [ -f "$SCRIPT_DIR/assets/icons/${app}_${sz}.png" ]; then
            sudo mkdir -p "/usr/share/icons/hicolor/${sz}x${sz}/apps"
            sudo cp "$SCRIPT_DIR/assets/icons/${app}_${sz}.png" "/usr/share/icons/hicolor/${sz}x${sz}/apps/${app}.png"
            if [ "$sz" -eq 48 ]; then
                sudo cp "$SCRIPT_DIR/assets/icons/${app}_48.png" "/usr/share/pixmaps/${app}.png"
            fi
        fi
    done
done
which gtk-update-icon-cache >/dev/null 2>&1 && sudo gtk-update-icon-cache -f -q /usr/share/icons/hicolor 2>/dev/null || true

# 4. Copy desktop entries to /usr/share/applications/
echo "Deploying system desktop entries..."
sudo mkdir -p /usr/share/applications
sudo cp "$SCRIPT_DIR/dotfiles/gutterdeck/.local/share/applications/gutterdeck.desktop" /usr/share/applications/ 2>/dev/null || true
sudo cp "$SCRIPT_DIR/dotfiles/guttertab/.local/share/applications/guttertab.desktop" /usr/share/applications/ 2>/dev/null || true
which update-desktop-database >/dev/null 2>&1 && sudo update-desktop-database /usr/share/applications 2>/dev/null || true

echo "✓ Themes, wallpapers, and brand icons deployed successfully."
