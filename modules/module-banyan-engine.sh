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
    if ! git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan" 2>/dev/null; then
        echo ""
        echo "=========================================================="
        echo "  GitHub authentication required for private Banyan repo  "
        echo "=========================================================="
        if command -v gh >/dev/null 2>&1; then
            echo "Attempting authentication via GitHub CLI..."
            gh auth login -w -s repo
            gh repo clone aimasri/Banyan "$HOME/projects/Banyan"
        else
            echo "1) Generate a new local SSH key to add to GitHub"
            echo "2) Enter a GitHub Personal Access Token (PAT)"
            read -p "Select option (1 or 2): " auth_choice
            if [ "$auth_choice" = "1" ]; then
                mkdir -p "$HOME/.ssh"
                [ ! -f "$HOME/.ssh/id_ed25519" ] && ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ""
                echo ""
                echo "Add this public key to https://github.com/settings/keys :"
                cat "$HOME/.ssh/id_ed25519.pub"
                echo ""
                read -p "Press Enter once added to GitHub to resume clone..."
                git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan"
            elif [ "$auth_choice" = "2" ]; then
                read -sp "Enter GitHub PAT: " GH_PAT
                echo ""
                git clone "https://${GH_PAT}@github.com/aimasri/Banyan.git" "$HOME/projects/Banyan"
            fi
        fi
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
