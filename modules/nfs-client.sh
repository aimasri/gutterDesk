#!/bin/bash
# ==============================================================================
# gutterDesk: Resilient NFSv4 Client Automount Module (AiM-Home & aim-book)
# ==============================================================================
# Configures a native, resilient systemd automount in /etc/fstab for
# aim-stream:/ -> /home/ahmed/aim-stream.
#
# Features:
# - Connects on demand when accessed by PCManFM, CLI, or tools.
# - Automatically unmounts after 60 seconds of inactivity.
# - Soft timeout (3s, 2 retries) prevents UI/boot hangs when offline.
# ==============================================================================

set -e

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
MOUNT_POINT="$TARGET_HOME/aim-stream"
SERVER_EXPORT="aim-stream:/"

echo "=== [NFS Client] Configuring Resilient Automount for $TARGET_USER ==="

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
if [ ! -f "$BOOKMARK_FILE" ] || ! grep -q "aim-stream" "$BOOKMARK_FILE"; then
    echo "file://$MOUNT_POINT aim-stream" >> "$BOOKMARK_FILE"
    chown "$TARGET_USER:$TARGET_USER" "$BOOKMARK_FILE"
    echo "--> Added GTK bookmark for $MOUNT_POINT"
fi

# 8. Test connectivity & automount
echo ""
echo "=== Testing Automount ==="
if ping -c 1 -W 2 aim-stream >/dev/null 2>&1; then
    echo "Host 'aim-stream' is reachable. Triggering automount..."
    if ls "$MOUNT_POINT" >/dev/null 2>&1; then
        echo "✓ Automount verified successfully! Contents:"
        ls -la "$MOUNT_POINT"
    else
        echo "Notice: Host is reachable but NFS export could not be accessed."
        echo "Ensure 'modules/nfs-server.sh' has been executed on aim-stream."
    fi
else
    echo "Notice: Host 'aim-stream' is currently offline or unreachable."
    echo "Automount unit is armed and will connect automatically once online."
fi

echo ""
echo "✓ NFS client configuration completed."
