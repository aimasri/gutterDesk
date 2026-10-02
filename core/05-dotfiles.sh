#!/usr/bin/env bash
# ==============================================================================
# Title:           05-dotfiles.sh
# Purpose:         Deploys Pure Declarative Dotfiles via Direct Atomic Symlinks
# Why This Design: Eliminates third-party package manager overhead (Chezmoi, GNU Stow)
#                  while preventing configuration drift. Any modification in
#                  $HOME/.config is immediately tracked by git in the repository.
# Privilege:       Dual (Ensures user ownership of all created links in $TARGET_HOME)
# Subsystems:      Openbox, Tint2, PCManFM, GTK, Guake, Volumeicon, Gsimplecal
# Idempotency:     Atomic symlinking (`ln -sf`) safely overwrites existing links.
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

echo "--> [6/8] Deploying declarative dotfiles into $TARGET_HOME..."

DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
STOW_PKGS="openbox tint2 pcmanfm themes ssh antigravity gemini gutterdeck guttertab guake gtk volumeicon gsimplecal iwgtk"

# Ensure target home base directories exist with proper user ownership
sudo mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/applications" "$TARGET_HOME/.local/bin" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh"
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh" 2>/dev/null || true

for pkg in $STOW_PKGS; do
    pkg_dir="$DOTFILES_DIR/$pkg"
    if [ -d "$pkg_dir" ]; then
        (
            cd "$pkg_dir"
            find . -type f -o -type l | while read -r f; do
                rel="${f#./}"
                src="$pkg_dir/$rel"
                dst="$TARGET_HOME/$rel"
                
                mkdir -p "$(dirname "$dst")"
                [ -d "$dst" ] && [ ! -L "$dst" ] && rm -rf "$dst"
                ln -sf "$src" "$dst"
            done
        )
    fi
done

# Clean up leftover legacy .bak files
find "$TARGET_HOME/.config" "$TARGET_HOME/.local" -name "*.bak" -delete 2>/dev/null || true

# Restore Guake terminal styling & Twilight palette
if [ -f "$TARGET_HOME/.config/guake/guake-preferences.ini" ]; then
    echo "Restoring Guake terminal styling & Twilight palette..."
    which dconf >/dev/null 2>&1 && run_as_target dconf load /org/guake/ < "$TARGET_HOME/.config/guake/guake-preferences.ini" 2>/dev/null || true
fi

# Set default application associations
echo "Configuring default desktop associations..."
run_as_target xdg-mime default pcmanfm.desktop inode/directory 2>/dev/null || true

# Ensure all deployed dotfiles are owned by TARGET_USER
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME" 2>/dev/null || true

echo "✓ Dotfiles deployed successfully via atomic symlinks."
