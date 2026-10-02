#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Installing Creative Suite ==="
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/creative.list" | tr '\n' ' ')

echo "Creative Suite installed successfully!"

if command -v gutterdesk-menu >/dev/null 2>&1; then
    gutterdesk-menu enable creative
elif [ -x "$HOME/.local/bin/gutterdesk-menu" ]; then
    "$HOME/.local/bin/gutterdesk-menu" enable creative
fi
