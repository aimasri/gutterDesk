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

# 4. Deploy Wallpapers & Brand Icons
echo "[3/7] Deploying wallpaper and branding assets..."
mkdir -p "$HOME/.local/share/backgrounds" "$HOME/.local/share/icons"
cp "$SCRIPT_DIR/wallpapers/"*.png "$HOME/.local/share/backgrounds/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/assets/icons/"* "$HOME/.local/share/icons/" 2>/dev/null || true

# 5. Deploy Dotfiles via GNU Stow
echo "[4/7] Symlinking dotfiles into $HOME..."
cd "$SCRIPT_DIR/dotfiles"
stow -R -t "$HOME" openbox tint2 pcmanfm themes ssh antigravity gemini gutterdeck guttertab

# Ensure helper scripts have execute permissions
chmod +x "$HOME/.local/bin/auto-wallpaper.sh" 2>/dev/null || true
chmod +x "$HOME/.config/openbox/autostart" 2>/dev/null || true

# 6. Set Default Applications
echo "[5/7] Configuring default desktop associations..."
xdg-mime default pcmanfm.desktop inode/directory 2>/dev/null || true

# 7. Build gutterDeck and gutterTab
echo "[6/7] Building and installing desktop utilities..."
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

# 8. GitHub Authentication Status Check
echo "[7/7] Checking GitHub SSH authentication status..."
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
