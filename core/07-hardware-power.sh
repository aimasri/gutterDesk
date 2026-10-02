#!/usr/bin/env bash
# ==============================================================================
# Title:           07-hardware-power.sh
# Purpose:         Configures Lid Switch Behavior, Battery Health Threshold & Permissions
# Why This Design: Always-on laptop server posture requires ignoring clamshell lid
#                  closures. Battery longevity under 24/7 AC power requires capping
#                  charge at 80% via sysfs charge_control_end_threshold. Finally,
#                  heals home directory ownership so root-owned files never lock the user.
# Privilege:       Dual (Requires sudo for logind & systemd; verifies GitHub as user)
# Subsystems:      systemd-logind, Linux sysfs power_supply, systemd services
# Idempotency:     Validates battery sysfs paths before provisioning systemd units.
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

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

echo "--> [8/8] Configuring power, lid switch, battery health & permissions..."

# 1. Ignore laptop lid switch (Always-on laptop/server posture)
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/gutterdesk-lid.conf >/dev/null << 'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

# 2. Configure 80% battery charging threshold if supported by hardware
BAT_THRESHOLD_FILE=$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1 || echo "")
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

# 3. Check GitHub SSH Authentication Status
echo "Checking GitHub SSH authentication status for $TARGET_USER..."
GH_AUTH=$(run_as_target ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
GH_USER=$(echo "$GH_AUTH" | grep -oP 'Hi \K[^!]+' || true)

if [ "$GH_USER" = "aimasri" ]; then
    echo "✓ GitHub SSH authentication verified for aimasri."
elif [ -n "$GH_USER" ]; then
    echo "Notice: GitHub authenticated as '$GH_USER', expected 'aimasri'."
else
    echo "Notice: GitHub SSH authentication is not yet configured for $TARGET_USER."
fi

# 4. Final home directory permissions heal
sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME" 2>/dev/null || true

echo "✓ Power management, battery threshold, and permissions configured successfully."
