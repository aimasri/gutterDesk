#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Setting up Banyan Trading Engine ==="
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/banyan-engine.list" | tr '\n' ' ')

mkdir -p "$HOME/projects" "$HOME/.config/gutterdesk"
[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    if [ -n "$BANYAN_REPO_URL" ]; then
        echo "Cloning Banyan repository from $BANYAN_REPO_URL..."
        git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan"
    else
        echo "Notice: Banyan repository not found at $HOME/projects/Banyan."
        echo "Set BANYAN_REPO_URL or specify in ~/.config/gutterdesk/banyan.conf to auto-clone."
        exit 0
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
