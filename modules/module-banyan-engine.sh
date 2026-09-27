#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Setting up Banyan Trading Engine ==="
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/banyan-engine.list" | tr '\n' ' ')

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

# Ensure run_engine.sh is executable
if [ -f "$HOME/projects/Banyan/run_engine.sh" ]; then
    chmod +x "$HOME/projects/Banyan/run_engine.sh"
fi

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

