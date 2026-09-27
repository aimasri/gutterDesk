#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v xvfb-run >/dev/null 2>&1 || ! command -v notify-send >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    echo "=== Installing Banyan Engine Host Dependencies ==="
    sudo apt-get update
    sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/banyan-engine.list" | tr '\n' ' ')
else
    echo "✓ Banyan engine host packages (xvfb, libnotify, unzip) already installed."
fi


mkdir -p "$HOME/projects" "$HOME/.config/gutterdesk"
[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

BANYAN_REPO_URL="${BANYAN_REPO_URL:-git@github.com:aimasri/Banyan.git}"

check_and_configure_github_ssh() {
    local target_account="aimasri"
    echo "Checking GitHub SSH authentication for '$target_account'..."

    while true; do
        local gh_msg
        gh_msg=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
        local auth_user
        auth_user=$(echo "$gh_msg" | grep -oP 'Hi \K[^!]+' || true)

        if [ "$auth_user" = "$target_account" ]; then
            echo "✓ GitHub SSH verified (authenticated as $auth_user)."
            return 0
        fi

        echo ""
        echo "=========================================================="
        if [ -n "$auth_user" ]; then
            echo "  Warning: Authenticated as '$auth_user', expected '$target_account'!"
        else
            echo "  GitHub SSH key not recognized or not configured.         "
        fi
        echo "=========================================================="
        echo ""
        echo "The Banyan repository is private and requires '$target_account' access."
        echo ""
        echo "1) Display / generate local SSH key to add to GitHub"
        echo "2) Authenticate via GitHub CLI (gh auth login)"
        echo "3) Enter a GitHub Personal Access Token (PAT)"
        echo "4) Retry SSH check"
        echo "5) Skip clone (repository must be cloned manually)"
        echo ""
        read -p "Select option [1-5]: " auth_choice

        case "$auth_choice" in
            1)
                mkdir -p "$HOME/.ssh"
                chmod 700 "$HOME/.ssh"
                local key_file="$HOME/.ssh/id_ed25519"
                if [ ! -f "$key_file" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
                    echo "Generating new Ed25519 SSH key..."
                    ssh-keygen -t ed25519 -f "$key_file" -N "" -C "$target_account@gutterdesk"
                fi
                local pubkey
                pubkey=$(ls -1 "$HOME/.ssh/"*.pub 2>/dev/null | head -n 1)
                echo ""
                echo "----------------------------------------------------------"
                echo "Public Key ($pubkey):"
                echo "----------------------------------------------------------"
                cat "$pubkey"
                echo "----------------------------------------------------------"
                echo "1. Go to: https://github.com/settings/keys"
                echo "2. Click 'New SSH key', paste the above key, and save."
                echo "----------------------------------------------------------"
                read -p "Press Enter once you have added the key to GitHub to verify..."
                ;;
            2)
                if command -v gh >/dev/null 2>&1; then
                    gh auth login
                else
                    echo "gh CLI not found."
                fi
                ;;
            3)
                read -sp "Enter GitHub PAT: " GH_PAT
                echo ""
                if [ -n "$GH_PAT" ]; then
                    BANYAN_REPO_URL="https://${GH_PAT}@github.com/${target_account}/Banyan.git"
                    return 0
                fi
                ;;
            4)
                echo "Retrying SSH connection..."
                ;;
            5)
                echo "Skipping repository clone."
                return 1
                ;;
            *)
                echo "Invalid selection. Please choose 1, 2, 3, 4, or 5."
                ;;
        esac
    done
}

if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    if check_and_configure_github_ssh; then
        echo "Cloning Banyan repository from $BANYAN_REPO_URL..."
        git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan"
    else
        echo "Warning: Banyan repository was not cloned. Please clone manually into $HOME/projects/Banyan."
    fi
else
    echo "Banyan repository already present at $HOME/projects/Banyan"
fi

cd "$HOME/projects/Banyan"
if [ ! -d ".venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv .venv
fi

echo "Installing Python dependencies..."
.venv/bin/pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    .venv/bin/pip install -r requirements.txt
fi

setup_wine_and_mt5_runtime() {
    echo "=== Verifying Wine, Python 3.11, and MetaTrader 5 Runtime ==="
    local cache_dir="/var/cache/gutterdesk"
    if [ ! -w "$cache_dir" ]; then
        cache_dir="$HOME/.cache/gutterdesk"
    fi
    mkdir -p "$cache_dir"

    download_file() {
        local url="$1"
        local dest="$2"
        local label="$3"
        if [ -f "$dest" ] && [ -s "$dest" ]; then
            echo "✓ $label archive cached ($dest)."
            return 0
        fi
        echo "Downloading $label..."
        if command -v curl >/dev/null 2>&1; then
            curl -fL --progress-bar --retry 3 --retry-delay 2 "$url" -o "$dest.tmp"
        elif command -v wget >/dev/null 2>&1; then
            wget -q --show-progress "$url" -O "$dest.tmp"
        else
            python3 -c "import urllib.request; urllib.request.urlretrieve('$url', '$dest.tmp')"
        fi
        mv "$dest.tmp" "$dest"
        echo "✓ $label download complete."
    }

    # 1. Setup Kron4ek Wine 9.0 (amd64) if missing
    local wine_dir="$HOME/wine-9.0-amd64"
    local wine_bin="$wine_dir/bin/wine64"
    if [ ! -x "$wine_bin" ]; then
        if command -v wine64 >/dev/null 2>&1; then
            wine_bin="$(command -v wine64)"
        fi
    fi

    if [ ! -x "$wine_bin" ]; then
        echo "Wine 9.0 standalone runtime not found. Installing Kron4ek Wine 9.0 (amd64)..."
        local wine_url="https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-amd64.tar.xz"
        local wine_tar="$cache_dir/wine-9.0-amd64.tar.xz"
        download_file "$wine_url" "$wine_tar" "Kron4ek Wine 9.0"

        echo "Extracting Wine 9.0 to $HOME/wine-9.0-amd64..."
        tar -xJf "$wine_tar" -C "$HOME"
        wine_bin="$HOME/wine-9.0-amd64/bin/wine64"
    fi
    echo "✓ Wine executable: $wine_bin"

    # Ensure wine prefix exists and is initialized
    export WINEPREFIX="$HOME/.wine"
    export WINEDEBUG="-all"
    export WINEDLLOVERRIDES="mscoree,mshtml="
    if [ ! -d "$WINEPREFIX/drive_c" ]; then
        echo "Initializing WINE prefix at $WINEPREFIX..."
        "$wine_bin" wineboot -u 2>/dev/null || true
    fi

    # 2. Setup Windows Python 3.11 embeddable inside Wine
    local py311_dir="$WINEPREFIX/drive_c/Python311"
    local py311_exe="$py311_dir/python.exe"
    if [ ! -f "$py311_exe" ]; then
        echo "Windows Python 3.11 embeddable runtime not found in Wine prefix."
        echo "Installing Python 3.11.8 embeddable into $py311_dir..."
        local py_url="https://www.python.org/ftp/python/3.11.8/python-3.11.8-embed-amd64.zip"
        local py_zip="$cache_dir/python-3.11.8-embed-amd64.zip"
        download_file "$py_url" "$py_zip" "Python 3.11 Embeddable (Windows)"

        mkdir -p "$py311_dir"
        if command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$py_zip" -d "$py311_dir"
        else
            echo "Notice: unzip command not found; extracting with Python zipfile..."
            python3 -c "import zipfile; zipfile.ZipFile('$py_zip').extractall('$py311_dir')"
        fi

        # Enable site-packages in python311._pth by uncommenting 'import site'
        local pth_file="$py311_dir/python311._pth"
        if [ -f "$pth_file" ]; then
            sed -i 's/^#import site/import site/' "$pth_file"
            if ! grep -q '^import site' "$pth_file"; then
                echo "import site" >> "$pth_file"
            fi
        fi
    fi

    # 3. Bootstrap pip and packages in Wine Python if pip or MetaTrader5 missing
    if [ ! -f "$py311_dir/Scripts/pip.exe" ] && [ ! -d "$py311_dir/Lib/site-packages/pip" ]; then
        echo "Bootstrapping pip inside Wine Python..."
        local pip_url="https://bootstrap.pypa.io/get-pip.py"
        local get_pip="$cache_dir/get-pip.py"
        download_file "$pip_url" "$get_pip" "Pip Bootstrap"

        "$wine_bin" "$py311_exe" "$get_pip" --no-warn-script-location
    fi

    # Verify MetaTrader5, rpyc, and compatible numpy are installed in Wine Python
    if ! "$wine_bin" "$py311_exe" -c "import MetaTrader5, rpyc, numpy; assert int(numpy.__version__.split('.')[0]) < 2" 2>/dev/null; then
        echo "Installing MetaTrader5, rpyc, and numpy<2 inside Wine Python..."
        "$wine_bin" "$py311_exe" -m pip install --no-warn-script-location "numpy<2" MetaTrader5 rpyc
    fi

    # 4. Deploy start_server.py (RPyC Bridge) inside C:\Python311\start_server.py
    local bridge_script="$py311_dir/start_server.py"
    if [ ! -f "$bridge_script" ]; then
        echo "Deploying RPyC bridge server to $bridge_script..."
        cat << 'PYEOF' > "$bridge_script"
from rpyc.utils.server import ThreadedServer
from rpyc.core.service import SlaveService
if __name__ == "__main__":
    print("Starting RPyC server on port 18812...")
    server = ThreadedServer(SlaveService, port=18812, reuse_addr=True, protocol_config={"allow_public_attrs": True, "allow_all_attrs": True})
    server.start()
PYEOF
    fi

    # 5. Verify or Install MetaTrader 5
    local mt5_dir="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
    local mt5_exe="$mt5_dir/terminal64.exe"
    local mt5_config="$mt5_dir/Config"
    if [ ! -f "$mt5_exe" ]; then
        echo "MetaTrader 5 terminal not found at $mt5_exe."
        echo "Downloading official MetaTrader 5 setup..."
        local mt5_url="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
        local mt5_installer="$cache_dir/mt5setup.exe"
        download_file "$mt5_url" "$mt5_installer" "MetaTrader 5 Setup"

        # Backup existing config if present before installer runs
        local config_backup=""
        if [ -d "$mt5_config" ] && [ -f "$mt5_config/accounts.dat" ]; then
            config_backup="$(mktemp -d)"
            cp -a "$mt5_config/"* "$config_backup/"
        fi

        echo "Running MetaTrader 5 silent installation (this may take 1-2 minutes)..."
        "$wine_bin" "$mt5_installer" /auto 2>/dev/null &
        local installer_pid=$!

        # Wait up to 60 seconds for terminal64.exe to appear
        local count=0
        while [ ! -f "$mt5_exe" ] && [ $count -lt 30 ]; do
            sleep 2
            count=$((count + 1))
        done

        # Clean up wine installer processes
        kill "$installer_pid" 2>/dev/null || true
        "$wine_dir/bin/wineserver" -k 2>/dev/null || wineserver -k 2>/dev/null || true

        # Restore backed-up config if preserved
        if [ -n "$config_backup" ] && [ -d "$config_backup" ]; then
            echo "Restoring pre-existing MT5 broker configuration..."
            mkdir -p "$mt5_config"
            cp -a "$config_backup/"* "$mt5_config/"
            rm -rf "$config_backup"
        fi
    fi

    # Auto-hydrate broker credentials from private backup if available and missing
    if [ -f "$mt5_exe" ] && [ ! -f "$mt5_config/accounts.dat" ]; then
        if [ -d "$HOME/projects/gutterdesk-private-backup/mt5/Config" ]; then
            echo "Hydrating MetaTrader 5 broker profile from private backup..."
            mkdir -p "$mt5_config"
            cp -a "$HOME/projects/gutterdesk-private-backup/mt5/Config/"* "$mt5_config/"
        fi
    fi

    if [ -f "$mt5_exe" ]; then
        echo "✓ MetaTrader 5 terminal verified: $mt5_exe"
    else
        echo "Notice: MetaTrader 5 automated installation finished. If terminal64.exe is missing,"
        echo "run 'wine $cache_dir/mt5setup.exe' interactively or copy from backup."
    fi
}

# Run runtime setup for Wine, MT5 and Windows Python bridge
setup_wine_and_mt5_runtime

echo "=== Installing Banyan Engine Systemd User Services ==="
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

# 1. Local GUI Engine Service (for physical X11 display session)
cat << 'EOF' > "$SYSTEMD_USER_DIR/banyan-engine.service"
[Unit]
Description=Banyan Trading Engine
After=network.target
OnFailure=banyan-engine-failure-notify.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=%h/projects/Banyan/run_engine.sh
WorkingDirectory=%h/projects/Banyan
Restart=on-failure
RestartSec=5
SuccessExitStatus=0 143 SIGTERM
TimeoutStopSec=15
Environment=DISPLAY=:0
Environment=XAUTHORITY=%h/.Xauthority

[Install]
WantedBy=default.target
EOF

# 2. Headless 24/7 Engine Service (Virtual Framebuffer for boot autostart)
cat << 'EOF' > "$SYSTEMD_USER_DIR/banyan-engine-headless.service"
[Unit]
Description=Banyan Trading Engine Headless
After=network.target
OnFailure=banyan-engine-failure-notify.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/bin/xvfb-run -a %h/projects/Banyan/run_engine.sh
WorkingDirectory=%h/projects/Banyan
Restart=on-failure
RestartSec=5
SuccessExitStatus=0 143 SIGTERM
TimeoutStopSec=15

[Install]
WantedBy=default.target
EOF

# 3. Engine Crash / Failure Notification Service
cat << 'EOF' > "$SYSTEMD_USER_DIR/banyan-engine-failure-notify.service"
[Unit]
Description=Banyan Engine Failure Notification

[Service]
Type=oneshot
ExecStart=/usr/bin/notify-send -u critical "Banyan Alert" "Trading engine has failed or crashed unexpectedly!"
Environment=DISPLAY=:0
Environment=XAUTHORITY=%h/.Xauthority
EOF

# Enable lingering so systemd user services run at boot without requiring GUI login
echo "Enabling user lingering for background autostart on system boot..."
loginctl enable-linger "$USER" 2>/dev/null || sudo loginctl enable-linger "$USER" 2>/dev/null || true

# Configure UFW firewall rules if ufw is installed
if command -v ufw >/dev/null 2>&1; then
    echo "Configuring UFW rules for Banyan Trading Engine..."
    sudo ufw allow 18813:18814/udp comment 'Allow Banyan Telemetry and Discovery' || true
    sudo ufw allow 18812/tcp comment 'Allow Banyan Bridge RPyC' || true
fi

# Reload systemd user daemon and enable headless engine autostart
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload
echo "Enabling banyan-engine-headless.service for autostart..."
systemctl --user enable banyan-engine-headless.service

# Autostart the engine service if not already running
if systemctl --user is-active --quiet banyan-engine.service; then
    echo "✓ banyan-engine (GUI mode) is currently active and running."
elif systemctl --user is-active --quiet banyan-engine-headless.service; then
    echo "✓ banyan-engine-headless is already active and running."
else
    echo "Starting banyan-engine-headless.service..."
    systemctl --user start banyan-engine-headless.service
fi

echo ""
echo "=========================================================="
echo "  Banyan Trading Engine installation and autostart ready! "
echo "=========================================================="
echo "Management commands:"
echo "  • Status:  systemctl --user status banyan-engine-headless"
echo "  • Logs:    journalctl --user -u banyan-engine-headless -f"
echo "  • Stop:    systemctl --user stop banyan-engine-headless"
echo "  • Start:   systemctl --user start banyan-engine-headless"
echo "  • GUI run: systemctl --user start banyan-engine"
echo "=========================================================="

