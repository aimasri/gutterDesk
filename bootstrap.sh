#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "    gutterDesk: Universal Base Bootstrap (Debian 13)       "
echo "=========================================================="

# 1. Require sudo privileges & resolve target user
if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

echo "Target user: $TARGET_USER ($TARGET_HOME)"

run_as_target() {
    if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ] && [ "$TARGET_USER" != "root" ]; then
        sudo -u "$TARGET_USER" -H "$@"
    else
        "$@"
    fi
}

# 2. Install repository keys & sources
echo "[1/8] Configuring third-party repositories..."
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
echo "[2/8] Installing Universal Base packages..."
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/base.list" | tr '\n' ' ')

# 4. Deploy Wallpapers & Brand Icons (User & System-wide)
echo "[3/8] Deploying wallpaper, branding & system themes..."
run_as_target mkdir -p "$TARGET_HOME/.local/share/backgrounds" "$TARGET_HOME/.local/share/icons"
run_as_target cp "$SCRIPT_DIR/wallpapers/"*.png "$TARGET_HOME/.local/share/backgrounds/" 2>/dev/null || true
run_as_target cp -r "$SCRIPT_DIR/assets/icons/"* "$TARGET_HOME/.local/share/icons/" 2>/dev/null || true

# System-wide assets for display manager, boot splash and desktop environments
sudo mkdir -p /usr/share/backgrounds/gutterdesk /usr/share/icons/gutterdesk /usr/share/themes/gutterdesk
sudo cp "$SCRIPT_DIR/wallpapers/"*.png /usr/share/backgrounds/gutterdesk/ 2>/dev/null || true
sudo cp -r "$SCRIPT_DIR/assets/icons/"* /usr/share/icons/gutterdesk/ 2>/dev/null || true
sudo cp -r "$SCRIPT_DIR/dotfiles/themes/.themes/gutterdesk"/* /usr/share/themes/gutterdesk/ 2>/dev/null || true

# Install icons to /usr/share/pixmaps/ and /usr/share/icons/hicolor/
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

# Copy desktop entries to /usr/share/applications/
echo "Deploying system desktop entries..."
sudo mkdir -p /usr/share/applications
sudo cp "$SCRIPT_DIR/dotfiles/gutterdeck/.local/share/applications/gutterdeck.desktop" /usr/share/applications/ 2>/dev/null || true
sudo cp "$SCRIPT_DIR/dotfiles/guttertab/.local/share/applications/guttertab.desktop" /usr/share/applications/ 2>/dev/null || true
which update-desktop-database >/dev/null 2>&1 && sudo update-desktop-database /usr/share/applications 2>/dev/null || true

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
sudo systemctl enable bluetooth 2>/dev/null || true

# Stop and disable bloated/conflicting networking services
sudo systemctl stop NetworkManager wpa_supplicant networking 2>/dev/null || true
sudo systemctl disable NetworkManager wpa_supplicant networking 2>/dev/null || true

# Configure modern lightweight wireless stack (iwd)
echo "Configuring iwd (Intel Wireless Daemon)..."
sudo mkdir -p /etc/iwd /var/lib/iwd
cat << 'EOF' | sudo tee /etc/iwd/main.conf >/dev/null
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=resolvconf
EOF

# Deploy system-wide iwgtk configuration
if [ -f "$SCRIPT_DIR/dotfiles/iwgtk/.config/iwgtk.conf" ]; then
    sudo cp "$SCRIPT_DIR/dotfiles/iwgtk/.config/iwgtk.conf" /etc/iwgtk.conf
fi

# Unblock Wi-Fi hardware/software switches
which rfkill >/dev/null 2>&1 && sudo rfkill unblock wifi 2>/dev/null || true

# Add target user to netdev group for unprivileged network control
sudo usermod -a -G netdev "$TARGET_USER" 2>/dev/null || true

# Migrate any existing netinst Wi-Fi credentials into iwd profile
if [ -f /etc/network/interfaces ]; then
    WIFI_SSID=$(grep -E '^[[:space:]]*wpa-ssid[[:space:]]+' /etc/network/interfaces | head -n1 | awk '{$1=""; print $0}' | sed 's/^[ \t]*//' | tr -d '"')
    WIFI_PSK=$(grep -E '^[[:space:]]*wpa-psk[[:space:]]+' /etc/network/interfaces | head -n1 | awk '{$1=""; print $0}' | sed 's/^[ \t]*//' | tr -d '"')

    if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PSK" ]; then
        echo "Migrating netinst Wi-Fi profile for '$WIFI_SSID' to iwd..."
        cat << EOF | sudo tee "/var/lib/iwd/${WIFI_SSID}.psk" >/dev/null
[Security]
Passphrase=${WIFI_PSK}
EOF
        sudo chmod 600 "/var/lib/iwd/${WIFI_SSID}.psk"
    fi

    sudo cp /etc/network/interfaces /etc/network/interfaces.bak
    sudo sed -i -E 's/^[[:space:]]*(iface|allow-hotplug|auto)[[:space:]]+(wlan|wlp|enp|eth).*/# &/g' /etc/network/interfaces
    sudo sed -i -E 's/^[[:space:]]*wpa-.*/# &/g' /etc/network/interfaces
fi

# Enable and start iwd
sudo systemctl unmask iwd 2>/dev/null || true
sudo systemctl enable iwd 2>/dev/null || true
sudo systemctl restart iwd 2>/dev/null || true

# 6. Deploy Dotfiles via GNU Stow
echo "[5/8] Symlinking dotfiles into $TARGET_HOME..."
cd "$SCRIPT_DIR/dotfiles"
run_as_target mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.local/share/applications" "$TARGET_HOME/.local/bin"

# Clean up pre-existing unmanaged conflicting files that prevent stow from linking
for conf in ".config/volumeicon" ".config/gsimplecal" ".config/gtk-3.0/settings.ini" ".gtkrc-2.0" ".config/xsettingsd" ".config/iwgtk.conf"; do
    target="$TARGET_HOME/$conf"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "Backing up pre-existing unmanaged $conf to $conf.bak..."
        run_as_target rm -rf "$target.bak"
        run_as_target mv "$target" "$target.bak"
    fi
done

STOW_PKGS="openbox tint2 pcmanfm themes ssh antigravity gemini gutterdeck guttertab guake gtk volumeicon gsimplecal iwgtk"

if [ "$EUID" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
    sudo -u "$TARGET_USER" -H stow -R -t "$TARGET_HOME" $STOW_PKGS
else
    stow -R -t "$TARGET_HOME" $STOW_PKGS
fi

# Restore Guake terminal styling & palette
if [ -f "$TARGET_HOME/.config/guake/guake-preferences.ini" ]; then
    echo "Restoring Guake terminal styling & Twilight palette..."
    which dconf >/dev/null 2>&1 && run_as_target dconf load /org/guake/ < "$TARGET_HOME/.config/guake/guake-preferences.ini" 2>/dev/null || true
fi

# Ensure helper scripts have execute permissions
chmod +x "$TARGET_HOME/.local/bin/auto-wallpaper.sh" 2>/dev/null || true
chmod +x "$TARGET_HOME/.config/openbox/autostart" 2>/dev/null || true

# 7. Set Default Applications
echo "[6/8] Configuring default desktop associations..."
run_as_target xdg-mime default pcmanfm.desktop inode/directory 2>/dev/null || true

# 8. Build gutterDeck and gutterTab
echo "[7/8] Building and installing desktop utilities..."
run_as_target mkdir -p "$TARGET_HOME/projects" "$TARGET_HOME/.local/bin"
sudo mkdir -p /usr/local/bin

build_tool() {
    local name="$1"
    local repo="$2"
    local dir="$TARGET_HOME/projects/$name"
    
    # Fix ownership if previously cloned by root
    if [ -d "$dir" ] && [ "$EUID" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
        sudo chown -R "$TARGET_USER:" "$dir"
    fi
    
    if [ ! -d "$dir/.git" ]; then
        echo "Attempting to clone $name into $dir as $TARGET_USER..."
        run_as_target git clone "$repo" "$dir" || {
            echo "Notice: Could not clone $name automatically. Ensure internet connectivity."
            return 0
        }
    else
        echo "Repository $dir already exists, updating..."
        run_as_target git -C "$dir" pull || true
    fi
    
    if [ -f "$dir/CMakeLists.txt" ]; then
        echo "Building $name as $TARGET_USER..."
        run_as_target mkdir -p "$dir/build"
        run_as_target bash -c "cd '$dir/build' && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j$(nproc)"
        
        local bin_source=""
        if [ -f "$dir/build/$name" ]; then
            bin_source="$dir/build/$name"
        elif [ -f "$dir/build/$(echo "$name" | tr '[:upper:]' '[:lower:]')" ]; then
            bin_source="$dir/build/$(echo "$name" | tr '[:upper:]' '[:lower:]')"
        fi
        
        if [ -n "$bin_source" ]; then
            local bin_basename="$(basename "$bin_source")"
            echo "Installing $bin_basename to /usr/local/bin and $TARGET_HOME/.local/bin..."
            sudo install -m 755 "$bin_source" "/usr/local/bin/$bin_basename"
            run_as_target install -m 755 "$bin_source" "$TARGET_HOME/.local/bin/$bin_basename"
        fi
    fi
}

# Public HTTPS clones for universal accessibility
build_tool "gutterDeck" "https://github.com/aimasri/gutterDeck.git"
build_tool "gutterTab" "https://github.com/aimasri/gutterTab.git"

# Ensure both casing variants exist in /usr/local/bin and ~/.local/bin
echo "Creating binary aliases and compatibility symlinks..."
if [ -f /usr/local/bin/gutterdeck ]; then
    sudo ln -sf /usr/local/bin/gutterdeck /usr/local/bin/gutterDeck
elif [ -f /usr/local/bin/gutterDeck ]; then
    sudo ln -sf /usr/local/bin/gutterDeck /usr/local/bin/gutterdeck
fi

if [ -f /usr/local/bin/gutterTab ]; then
    sudo ln -sf /usr/local/bin/gutterTab /usr/local/bin/guttertab
elif [ -f /usr/local/bin/guttertab ]; then
    sudo ln -sf /usr/local/bin/guttertab /usr/local/bin/gutterTab
fi

if [ -f "$TARGET_HOME/.local/bin/gutterdeck" ]; then
    run_as_target ln -sf "$TARGET_HOME/.local/bin/gutterdeck" "$TARGET_HOME/.local/bin/gutterDeck"
elif [ -f "$TARGET_HOME/.local/bin/gutterDeck" ]; then
    run_as_target ln -sf "$TARGET_HOME/.local/bin/gutterDeck" "$TARGET_HOME/.local/bin/gutterdeck"
fi

if [ -f "$TARGET_HOME/.local/bin/gutterTab" ]; then
    run_as_target ln -sf "$TARGET_HOME/.local/bin/gutterTab" "$TARGET_HOME/.local/bin/guttertab"
elif [ -f "$TARGET_HOME/.local/bin/guttertab" ]; then
    run_as_target ln -sf "$TARGET_HOME/.local/bin/guttertab" "$TARGET_HOME/.local/bin/gutterTab"
fi

# Antigravity compatibility symlink: antigravity2 -> antigravity
if [ -x /usr/bin/antigravity ]; then
    sudo ln -sf /usr/bin/antigravity /usr/local/bin/antigravity2
    run_as_target ln -sf /usr/bin/antigravity "$TARGET_HOME/.local/bin/antigravity2"
elif [ -x /usr/local/bin/antigravity ]; then
    sudo ln -sf /usr/local/bin/antigravity /usr/local/bin/antigravity2
    run_as_target ln -sf /usr/local/bin/antigravity "$TARGET_HOME/.local/bin/antigravity2"
fi

# Install /etc/profile.d/gutterdesk.sh for system-wide PATH configuration
echo "Configuring system-wide environment PATH in /etc/profile.d/gutterdesk.sh..."
sudo tee /etc/profile.d/gutterdesk.sh >/dev/null << 'EOF'
# gutterDesk system-wide PATH configuration
if [ -n "$PATH" ]; then
    case ":$PATH:" in
        *:/usr/local/bin:*) ;;
        *) export PATH="/usr/local/bin:$PATH" ;;
    esac
    case ":$PATH:" in
        *:"$HOME/.local/bin":*) ;;
        *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac
else
    export PATH="/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin"
fi
EOF
sudo chmod 644 /etc/profile.d/gutterdesk.sh

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
