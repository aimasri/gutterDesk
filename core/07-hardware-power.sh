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

# 2. Configure 80% battery charging threshold if supported by hardware.
#    The sysfs node can exist while the firmware rejects writes (EIO), so support
#    is proven by an actual write rather than by file presence.
BAT_THRESHOLD_FILE=$(ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n 1 || echo "")
BAT_SUPPORTED=0
if [ -n "$BAT_THRESHOLD_FILE" ] && echo 80 | sudo tee "$BAT_THRESHOLD_FILE" >/dev/null 2>&1; then
    BAT_SUPPORTED=1
fi

if [ "$BAT_SUPPORTED" -eq 1 ]; then
    echo "Hardware battery charge control verified ($BAT_THRESHOLD_FILE). Threshold set to 80%."
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
else
    if [ -n "$BAT_THRESHOLD_FILE" ]; then
        echo "Notice: $BAT_THRESHOLD_FILE exists but the firmware rejects writes; skipping charge threshold."
    fi
    if [ -f /etc/systemd/system/battery-charge-threshold.service ]; then
        sudo systemctl disable battery-charge-threshold.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/battery-charge-threshold.service
        sudo systemctl daemon-reload
        sudo systemctl reset-failed battery-charge-threshold.service 2>/dev/null || true
        echo "Removed unsupported battery-charge-threshold.service."
    fi
fi

# 3. Final home directory permissions heal (targeted only to managed dotfiles, never traversing network mounts)
if [ "$EUID" -eq 0 ]; then
    for scan_dir in "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/.themes" "$TARGET_HOME/.ssh" "$TARGET_HOME/.gemini"; do
        [ -d "$scan_dir" ] && chown -R "$TARGET_USER:$TARGET_USER" "$scan_dir" 2>/dev/null || true
    done
    find "$TARGET_HOME" -maxdepth 1 -lname "$SCRIPT_DIR/*" -exec chown -h "$TARGET_USER:$TARGET_USER" {} + 2>/dev/null || true
fi

echo "✓ Power management, battery threshold, and permissions configured successfully."
