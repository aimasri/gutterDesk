#!/usr/bin/env bash
# ==============================================================================
# Title:           module-nfs-client.sh
# Purpose:         Configures Resilient On-Demand Systemd NFSv4 Automount
# Why This Design: Client workstations do not maintain duplicate
#                  local codebases. This module adds a native systemd automount entry
#                  to /etc/fstab with soft failure semantics (timeo=30, retrans=2)
#                  and idle timeout (60s), ensuring mobile clients never hang during
#                  network handoffs or offline sessions.
# Privilege:       Root (Requires sudo for nfs-common, /etc/fstab & daemon-reload)
# Subsystems:      nfs-common, /etc/fstab, systemd automount, PCManFM bookmarks
# Idempotency:     Idempotently replaces server automount line in /etc/fstab.
# ==============================================================================

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

SERVER_HOST="${1:-aim-stream}"
SERVER_IP="${2:-}"
MOUNT_POINT="$TARGET_HOME/$SERVER_HOST"
SERVER_EXPORT="${SERVER_HOST}:/"

echo "=== [NFS Client] Configuring Resilient Automount ($SERVER_HOST) for $TARGET_USER ==="

# 0. Configure /etc/hosts mapping dynamically
if [ -n "$SERVER_IP" ]; then
    echo "--> Configuring /etc/hosts mapping: $SERVER_IP -> $SERVER_HOST..."
    if grep -qE "[[:space:]]${SERVER_HOST}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
        sudo sed -i "/[[:space:]]${SERVER_HOST}\([[:space:]]\|$\)/d" /etc/hosts
    fi
    echo "$SERVER_IP $SERVER_HOST" | sudo tee -a /etc/hosts >/dev/null
    echo "  ✓ /etc/hosts updated: $SERVER_IP $SERVER_HOST"
elif ! [[ "$SERVER_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    if ! grep -qE "[[:space:]]${SERVER_HOST}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
        if [ -t 0 ]; then
            read -p "Enter IP address for server '$SERVER_HOST' (leave empty to skip /etc/hosts): " PROMPTED_IP
            if [ -n "$PROMPTED_IP" ]; then
                sudo sed -i "/[[:space:]]${SERVER_HOST}\([[:space:]]\|$\)/d" /etc/hosts
                echo "$PROMPTED_IP $SERVER_HOST" | sudo tee -a /etc/hosts >/dev/null
                echo "  ✓ /etc/hosts updated: $PROMPTED_IP $SERVER_HOST"
            fi
        fi
    fi
fi

# 1. Install nfs-common
echo "--> Ensuring nfs-common is installed..."
sudo apt-get update
sudo apt-get install -y nfs-common

# 2. Unmount any lingering SSHFS or static mounts
if mountpoint -q "$MOUNT_POINT"; then
    echo "--> Unmounting existing mount at $MOUNT_POINT..."
    fusermount -u "$MOUNT_POINT" 2>/dev/null || sudo umount -l "$MOUNT_POINT" 2>/dev/null || true
fi

# 3. Create mount point directory
mkdir -p "$MOUNT_POINT"
chown "$TARGET_USER:$TARGET_USER" "$MOUNT_POINT"

# 4. Configure /etc/fstab
echo "--> Configuring /etc/fstab systemd automount..."
FSTAB_LINE="$SERVER_EXPORT $MOUNT_POINT nfs4 proto=tcp,port=2049,noauto,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.device-timeout=5,soft,timeo=30,retrans=2,_netdev 0 0"

[ -f /etc/fstab ] && [ ! -f /etc/fstab.gutterdesk.bak ] && sudo cp /etc/fstab /etc/fstab.gutterdesk.bak

# Idempotently update or append the entry
if grep -q "$MOUNT_POINT" /etc/fstab 2>/dev/null; then
    sudo sed -i "\|[[:space:]]$MOUNT_POINT[[:space:]]|d" /etc/fstab
fi
echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null

# 5. Reload systemd daemon to generate automount unit
echo "--> Reloading systemd daemon..."
sudo systemctl daemon-reload

# 6. Restart automount unit
UNIT_NAME=$(systemd-escape -p --suffix=automount "$MOUNT_POINT")
echo "--> Starting automount unit $UNIT_NAME..."
sudo systemctl restart "$UNIT_NAME" || true
sudo systemctl enable "$UNIT_NAME" 2>/dev/null || true

# 7. Ensure GTK bookmark for PCManFM
BOOKMARK_FILE="$TARGET_HOME/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$BOOKMARK_FILE")"
if [ ! -f "$BOOKMARK_FILE" ] || ! grep -q "$SERVER_HOST" "$BOOKMARK_FILE"; then
    echo "file://$MOUNT_POINT $SERVER_HOST" >> "$BOOKMARK_FILE"
    chown "$TARGET_USER:$TARGET_USER" "$BOOKMARK_FILE"
    echo "--> Added GTK bookmark for $MOUNT_POINT"
fi

# 8. Test connectivity & automount
echo ""
echo "=== Testing Server Connectivity & Route Resolution ==="
RESOLVED_IPS=$(getent ahosts "$SERVER_HOST" 2>/dev/null | awk '{print $1}' | sort -u || true)
if [ -n "$RESOLVED_IPS" ]; then
    echo "Resolved IP(s) for '$SERVER_HOST':"
    for rip in $RESOLVED_IPS; do
        if [[ "$rip" =~ ^100\. ]]; then
            echo "  - $rip (Tailscale WireGuard Mesh)"
        elif [[ "$rip" =~ ^192\.168\. ]] || [[ "$rip" =~ ^10\. ]] || [[ "$rip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
            echo "  - $rip (Direct Physical LAN)"
        else
            echo "  - $rip (External / WAN)"
        fi
    done
fi

if ping -c 1 -W 2 "$SERVER_HOST" >/dev/null 2>&1; then
    echo "Host '$SERVER_HOST' is reachable. Triggering automount..."
    if ls "$MOUNT_POINT" >/dev/null 2>&1; then
        echo "✓ Automount verified successfully! Contents:"
        ls -la "$MOUNT_POINT"
    else
        echo "Notice: Host is reachable but NFS export could not be accessed."
        echo "Ensure 'modules/module-nfs-server.sh' has been executed on $SERVER_HOST."
    fi
else
    echo "Notice: Host '$SERVER_HOST' is currently offline or unreachable."
    echo "Automount unit is armed and will connect automatically once online."
fi

echo ""
echo "✓ NFS client configuration completed."
