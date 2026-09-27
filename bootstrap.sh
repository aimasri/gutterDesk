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

# Remove redundant google-chrome.list if the package created google-chrome.sources (avoids duplicate warnings)
if [ -f /etc/apt/sources.list.d/google-chrome.sources ] && [ -f /etc/apt/sources.list.d/google-chrome.list ]; then
    sudo rm -f /etc/apt/sources.list.d/google-chrome.list
fi

# 4. Deploy Wallpapers & Brand Icons (User & System-wide)
echo "[3/8] Deploying wallpaper, branding & system themes..."
sudo mkdir -p "$TARGET_HOME/.local/share/backgrounds" "$TARGET_HOME/.local/share/icons"
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.local" 2>/dev/null || true
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
sudo systemctl enable ssh 2>/dev/null || true


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

# Migrate existing netinst Wi-Fi credentials into iwd profile
echo "Scanning for netinst Wi-Fi credentials to migrate..."
python3 - << 'PYEOF'
import os, re

files = ['/etc/network/interfaces', '/etc/network/interfaces.bak']
ssid, psk = None, None

for path in files:
    if os.path.exists(path):
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                # Matches wpa-ssid even if commented out (# wpa-ssid "MySSID")
                m_ssid = re.search(r'wpa-ssid\s+["\']?([^"\'\r\n]+)', content)
                # Matches wpa-psk or wpa-passphrase even if commented out
                m_psk = re.search(r'wpa-(?:psk|passphrase)\s+["\']?([^"\'\r\n]+)', content)
                if m_ssid and m_psk:
                    s = m_ssid.group(1).strip().strip('"').strip("'")
                    p = m_psk.group(1).strip().strip('"').strip("'")
                    if s and p:
                        ssid, psk = s, p
                        break
        except Exception:
            pass

if ssid and psk:
    os.makedirs('/var/lib/iwd', exist_ok=True)
    is_hex = len(psk) == 64 and all(c in '0123456789abcdefABCDEF' for c in psk)
    sec_key = 'PreSharedKey' if is_hex else 'Passphrase'
    target_file = f'/var/lib/iwd/{ssid}.psk'
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(f'[Security]\n{sec_key}={psk}\n')
    os.chmod(target_file, 0o600)
    print(f"✓ Migrated Wi-Fi credentials for '{ssid}' ({sec_key}) into {target_file}")
else:
    print("Notice: No saved Wi-Fi credentials found in /etc/network/interfaces.")
PYEOF

# Comment out only wireless interfaces in /etc/network/interfaces so iwd has exclusive control
if [ -f /etc/network/interfaces ]; then
    if [ ! -f /etc/network/interfaces.bak ]; then
        sudo cp /etc/network/interfaces /etc/network/interfaces.bak
    fi
    sudo sed -i -E 's/^[[:space:]]*(iface|allow-hotplug|auto)[[:space:]]+(wlan|wlp).*/# &/g' /etc/network/interfaces
    sudo sed -i -E 's/^[[:space:]]*wpa-.*/# &/g' /etc/network/interfaces
fi

# Stop and disable bloated/conflicting networking services
sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true
sudo systemctl disable NetworkManager wpa_supplicant 2>/dev/null || true
sudo systemctl stop networking 2>/dev/null || true

# Enable and start iwd
sudo systemctl unmask iwd 2>/dev/null || true
sudo systemctl enable iwd 2>/dev/null || true
sudo systemctl restart iwd 2>/dev/null || true

# Wait briefly for iwd to associate and acquire DHCP lease
echo "Awaiting wireless network association..."
for i in $(seq 1 12); do
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        echo "✓ Network connection established."
        break
    fi
    sleep 1
done

# 6. Deploy Dotfiles via Direct Atomic Symlinking
echo "[5/8] Deploying dotfiles into $TARGET_HOME..."
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

# Clean up any leftover legacy .bak files from previous bootstrap iterations
find "$TARGET_HOME/.config" "$TARGET_HOME/.local" -name "*.bak" -delete 2>/dev/null || true

# Ensure all scripts in .local/bin are executable
chmod +x "$TARGET_HOME/.local/bin/"* 2>/dev/null || true

# Ensure all deployed dotfiles and home directory (including .Xauthority) are owned by TARGET_USER
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME" 2>/dev/null || true

# Restore Guake terminal styling & palette
if [ -f "$TARGET_HOME/.config/guake/guake-preferences.ini" ]; then
    echo "Restoring Guake terminal styling & Twilight palette..."
    which dconf >/dev/null 2>&1 && run_as_target dconf load /org/guake/ < "$TARGET_HOME/.config/guake/guake-preferences.ini" 2>/dev/null || true
fi

# Ensure helper scripts have execute permissions
chmod +x "$TARGET_HOME/.local/bin/auto-wallpaper.sh" 2>/dev/null || true
chmod +x "$TARGET_HOME/.local/bin/gutterdesk-first-run.sh" 2>/dev/null || true
chmod +x "$TARGET_HOME/.config/openbox/autostart" 2>/dev/null || true

# 7. Set Default Applications
echo "[6/8] Configuring default desktop associations..."
run_as_target xdg-mime default pcmanfm.desktop inode/directory 2>/dev/null || true

# 8. Build gutterDeck and gutterTab
echo "[7/8] Building and installing desktop utilities..."
sudo mkdir -p "$TARGET_HOME/projects" "$TARGET_HOME/.local/bin" /usr/local/bin
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/projects" "$TARGET_HOME/.local" 2>/dev/null || true

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

# Guake as default x-terminal-emulator
sudo tee /usr/local/bin/x-terminal-emulator >/dev/null << 'EOF'
#!/bin/bash
if [ -n "$1" ]; then
    guake "$@"
else
    guake-toggle
fi
EOF
sudo chmod 755 /usr/local/bin/x-terminal-emulator
run_as_target ln -sf /usr/local/bin/x-terminal-emulator "$TARGET_HOME/.local/bin/x-terminal-emulator"


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
export GTK_USE_PORTAL=0
EOF
sudo chmod 644 /etc/profile.d/gutterdesk.sh

# 9. Power, Lid & Battery Management (Always-On Laptop/Server Support)
echo "[8/9] Configuring power, lid switch, and battery health..."

# A. Ignore laptop lid switch so closing the screen does not suspend server operations
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/gutterdesk-lid.conf >/dev/null << 'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

# B. Configure 80% battery charging threshold if supported by hardware (e.g. ASUS / ThinkPad)
BAT_THRESHOLD_FILE=$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1)
if [ -n "$BAT_THRESHOLD_FILE" ]; then
    echo "Hardware battery charge control detected ($BAT_THRESHOLD_FILE). Setting 80% threshold..."
    echo 80 | sudo tee "$BAT_THRESHOLD_FILE" >/dev/null || true
    
    sudo tee /etc/systemd/system/battery-charge-threshold.service >/dev/null << EOF
[Unit]
Description=Set Battery Charge Threshold to 80% (Battery Health)
After=multi-user.target
ConditionPathExists=$BAT_THRESHOLD_FILE

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo 80 > $BAT_THRESHOLD_FILE'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable battery-charge-threshold.service 2>/dev/null || true
fi

# 10. GitHub Authentication Status Check
echo "[9/9] Checking GitHub SSH authentication status..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✓ GitHub SSH authentication verified."
else
    echo "----------------------------------------------------------"
    echo "Notice: GitHub SSH authentication is not yet configured."
    echo "To authenticate your GitHub account on this machine, run:"
    echo "  gh auth login"
    echo "----------------------------------------------------------"
fi

sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME" 2>/dev/null || true

echo "=========================================================="
echo "    gutterDesk Base Bootstrap Completed Successfully!     "
echo "=========================================================="
