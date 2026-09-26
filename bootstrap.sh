#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "    gutterDesk: Universal Base Bootstrap (Debian 13)       "
echo "=========================================================="

# 1. Require sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

# 2. Install repository keys & sources
echo "[1/7] Configuring third-party repositories..."
sudo mkdir -p /etc/apt/keyrings /usr/share/keyrings

if [ -f "$SCRIPT_DIR/keys/antigravity-repo-key.gpg" ]; then
    sudo install -m 0644 "$SCRIPT_DIR/keys/antigravity-repo-key.gpg" /etc/apt/keyrings/antigravity-repo-key.gpg
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
fi

if [ -f "$SCRIPT_DIR/keys/google-chrome.gpg" ]; then
    sudo install -m 0644 "$SCRIPT_DIR/keys/google-chrome.gpg" /usr/share/keyrings/google-chrome.gpg
    echo "deb [signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome-stable/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
fi

# 3. Update APT and install Universal Base packages
echo "[2/7] Installing Universal Base packages..."
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/base.list" | tr '\n' ' ')

# 4. Deploy Wallpapers & Brand Icons (User & System-wide)
echo "[3/8] Deploying wallpaper, branding & system themes..."
mkdir -p "$HOME/.local/share/backgrounds" "$HOME/.local/share/icons"
cp "$SCRIPT_DIR/wallpapers/"*.png "$HOME/.local/share/backgrounds/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/assets/icons/"* "$HOME/.local/share/icons/" 2>/dev/null || true

# System-wide assets for display manager and boot splash
sudo mkdir -p /usr/share/backgrounds/gutterdesk /usr/share/icons/gutterdesk /usr/share/themes/gutterdesk
sudo cp "$SCRIPT_DIR/wallpapers/"*.png /usr/share/backgrounds/gutterdesk/ 2>/dev/null || true
sudo cp -r "$SCRIPT_DIR/assets/icons/"* /usr/share/icons/gutterdesk/ 2>/dev/null || true
sudo cp -r "$SCRIPT_DIR/dotfiles/themes/.themes/gutterdesk"/* /usr/share/themes/gutterdesk/ 2>/dev/null || true

# 5. Configure Boot Splash (Plymouth) & Login Greeter (LightDM)
echo "[4/8] Configuring boot splash (Plymouth) & login greeter (LightDM)..."

# Deploy Plymouth Theme
if [ -d "$SCRIPT_DIR/themes/plymouth/gutterdesk" ]; then
    echo "Installing gutterDesk Plymouth theme..."
    sudo mkdir -p /usr/share/plymouth/themes/gutterdesk
    sudo cp -r "$SCRIPT_DIR/themes/plymouth/gutterdesk/"* /usr/share/plymouth/themes/gutterdesk/
    if [ -x /usr/sbin/plymouth-set-default-theme ]; then
        echo "Activating gutterDesk Plymouth boot splash..."
        sudo /usr/sbin/plymouth-set-default-theme gutterdesk -R 2>/dev/null || true
    fi
fi

# Ensure 'splash' is in GRUB_CMDLINE_LINUX_DEFAULT
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

# Deploy LightDM Greeter Configuration
sudo mkdir -p /etc/lightdm/lightdm-gtk-greeter.conf.d
if [ -f "$SCRIPT_DIR/themes/lightdm/lightdm-gtk-greeter.conf" ]; then
    sudo cp "$SCRIPT_DIR/themes/lightdm/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf
    sudo cp "$SCRIPT_DIR/themes/lightdm/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf.d/99_gutterdesk.conf
fi
sudo systemctl enable lightdm 2>/dev/null || true

# 6. Deploy Dotfiles via GNU Stow
echo "[5/8] Symlinking dotfiles into $HOME..."
cd "$SCRIPT_DIR/dotfiles"
stow -R -t "$HOME" openbox tint2 pcmanfm themes ssh antigravity gemini gutterdeck guttertab

# Ensure helper scripts have execute permissions
chmod +x "$HOME/.local/bin/auto-wallpaper.sh" 2>/dev/null || true
chmod +x "$HOME/.config/openbox/autostart" 2>/dev/null || true

# 7. Set Default Applications
echo "[6/8] Configuring default desktop associations..."
xdg-mime default pcmanfm.desktop inode/directory 2>/dev/null || true

# 8. Build gutterDeck and gutterTab
echo "[7/8] Building and installing desktop utilities..."
mkdir -p "$HOME/projects" "$HOME/.local/bin"

build_tool() {
    local name="$1"
    local repo="$2"
    local dir="$HOME/projects/$name"
    
    if [ ! -d "$dir/.git" ]; then
        echo "Attempting to clone $name..."
        git clone "$repo" "$dir" || {
            echo "Notice: Could not clone $name automatically. Ensure internet connectivity."
            return 0
        }
    fi
    
    if [ -f "$dir/CMakeLists.txt" ]; then
        echo "Building $name..."
        mkdir -p "$dir/build"
        cd "$dir/build"
        cmake .. -DCMAKE_BUILD_TYPE=Release
        make -j"$(nproc)"
        if [ -f "$dir/build/$name" ]; then
            cp "$dir/build/$name" "$HOME/.local/bin/"
        elif [ -f "$dir/build/$(echo "$name" | tr '[:upper:]' '[:lower:]')" ]; then
            cp "$dir/build/$(echo "$name" | tr '[:upper:]' '[:lower:]')" "$HOME/.local/bin/"
        fi
    fi
}

# Public HTTPS clones for universal accessibility
build_tool "gutterDeck" "https://github.com/aimasri/gutterDeck.git"
build_tool "gutterTab" "https://github.com/aimasri/gutterTab.git"

# 9. GitHub Authentication Status Check
echo "[8/8] Checking GitHub SSH authentication status..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✓ GitHub SSH authentication verified."
else
    echo "----------------------------------------------------------"
    echo "! Action Required: GitHub SSH keys are not yet configured."
    echo "  1. Copy your private keys to ~/.ssh/ (e.g. id_ed25519)"
    echo "  2. Ensure permissions: chmod 600 ~/.ssh/* && chmod 700 ~/.ssh"
    echo "  3. Or run 'gh auth login' to authenticate via browser/token."
    echo "----------------------------------------------------------"
fi

echo "=========================================================="
echo "    gutterDesk Base Bootstrap Completed Successfully!     "
echo "=========================================================="
