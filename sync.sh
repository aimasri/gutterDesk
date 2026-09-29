#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/backup"

if [ -f "$BACKUP_DIR/sync.sh" ]; then
    exec "$BACKUP_DIR/sync.sh" "$@"
else
    echo "Error: Private backup not found at $BACKUP_DIR." >&2
    echo "Please extract your private backup into ~/gutterDesk/backup/ first." >&2
    exit 1
fi
