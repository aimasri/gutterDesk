#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Setting up Banyan Trading Engine ==="
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/banyan-engine.list" | tr '\n' ' ')

mkdir -p "$HOME/projects" "$HOME/.config/gutterdesk"
[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

BANYAN_REPO_URL="${BANYAN_REPO_URL:-git@github.com:aimasri/Banyan.git}"

if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    echo "Cloning Banyan repository from $BANYAN_REPO_URL..."
    if ! git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan"; then
        echo "Error: Failed to clone Banyan repository."
        echo "Ensure your GitHub SSH key (~/.ssh/id_ed25519) is installed on this machine."
        exit 1
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

echo "Banyan Engine configuration complete."
