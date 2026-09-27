#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Fixing home and SSH directory permissions..."
chmod 755 "$HOME"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

KEY_FILE="$SCRIPT_DIR/keys/workstation.pub"
if [ -f "$KEY_FILE" ]; then
    KEY_CONTENT=$(cat "$KEY_FILE")
    touch "$HOME/.ssh/authorized_keys"
    if ! grep -Fq "$KEY_CONTENT" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
        echo "$KEY_CONTENT" >> "$HOME/.ssh/authorized_keys"
        echo "✓ Added workstation key to authorized_keys."
    else
        echo "✓ Workstation key already present in authorized_keys."
    fi
fi

chmod 600 "$HOME/.ssh/authorized_keys"
sudo systemctl restart ssh 2>/dev/null || true

echo ""
echo "=========================================================="
echo " SSH authorization complete! Workstation can now connect. "
echo "=========================================================="
