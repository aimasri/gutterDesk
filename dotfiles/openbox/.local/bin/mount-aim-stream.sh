#!/bin/bash
# Mount remote projects directory from aim-stream via SSHFS
MOUNT_POINT="$HOME/aim-stream"
REMOTE_HOST="aim-stream"
REMOTE_PATH="/home/ahmed/projects"

mkdir -p "$MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT"; then
    echo "✓ $MOUNT_POINT is already mounted."
    exit 0
fi

# Ensure SSH host is reachable
if ssh -o BatchMode=yes -o ConnectTimeout=3 "$REMOTE_HOST" true >/dev/null 2>&1; then
    sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user,follow_symlinks "$REMOTE_HOST:$REMOTE_PATH" "$MOUNT_POINT"
    if mountpoint -q "$MOUNT_POINT"; then
        echo "✓ Successfully mounted $REMOTE_HOST:$REMOTE_PATH at $MOUNT_POINT"
        # Ensure GTK file dialogs have a quick bookmark
        BOOKMARK_FILE="$HOME/.config/gtk-3.0/bookmarks"
        if [ -f "$BOOKMARK_FILE" ]; then
            grep -q "aim-stream" "$BOOKMARK_FILE" || echo "file://$MOUNT_POINT aim-stream" >> "$BOOKMARK_FILE"
        else
            mkdir -p "$(dirname "$BOOKMARK_FILE")"
            echo "file://$MOUNT_POINT aim-stream" > "$BOOKMARK_FILE"
        fi
    else
        echo "✗ Failed to mount $REMOTE_HOST:$REMOTE_PATH" >&2
        exit 1
    fi
else
    echo "! Cannot reach $REMOTE_HOST over SSH. Skipping mount." >&2
    exit 1
fi
