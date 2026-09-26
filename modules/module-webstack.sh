#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Installing Web Development Stack (Apache2, PostgreSQL, Redis) ==="
sudo apt-get update
sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/webstack.list" | tr '\n' ' ')

# Enable Apache core modules
sudo a2enmod rewrite ssl headers proxy proxy_http || true

# Start and enable databases
sudo systemctl enable --now postgresql
sudo systemctl enable --now redis-server

mkdir -p "$HOME/projects" "$HOME/.config/gutterdesk"

# Clone web repositories if configured in ~/.config/gutterdesk/webstack_repos.conf
REPO_CONF="$HOME/.config/gutterdesk/webstack_repos.conf"
if [ -f "$REPO_CONF" ]; then
    echo "Found repository manifest at $REPO_CONF. Cloning projects..."
    grep -v '^[[:space:]]*#' "$REPO_CONF" | grep -v '^[[:space:]]*$' | while IFS=':' read -r NAME URL; do
        if [ -n "$NAME" ] && [ -n "$URL" ]; then
            TARGET="$HOME/projects/$NAME"
            if [ ! -d "$TARGET/.git" ]; then
                echo "Cloning $NAME..."
                git clone "$URL" "$TARGET" || echo "Note: Could not clone $NAME (verify SSH keys for $URL)"
            fi
        fi
    done
else
    echo "------------------------------------------------------------------"
    echo "Optional: To automatically clone your web repositories on install,"
    echo "create ~/.config/gutterdesk/webstack_repos.conf with lines formatted as:"
    echo "  ProjectName:git@github.com:username/repository.git"
    echo "------------------------------------------------------------------"
fi

echo "Web development stack installation complete."
