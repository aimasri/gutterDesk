#!/bin/bash
# Unmount remote projects directory
MOUNT_POINT="$HOME/aim-stream"

if mountpoint -q "$MOUNT_POINT"; then
    fusermount -u "$MOUNT_POINT" 2>/dev/null || umount -l "$MOUNT_POINT"
    echo "✓ Unmounted $MOUNT_POINT"
else
    echo "Notice: $MOUNT_POINT is not mounted."
fi
