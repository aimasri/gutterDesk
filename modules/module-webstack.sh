#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Installing Web Development Stack (Apache2, PostgreSQL, Redis, PHP) ==="
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

# Ensure traversal permissions on user home directory so Apache www-data can serve projects
chmod o+x "$HOME"

# Sync custom local domain mappings from ~/.config/gutterdesk/hosts if present
HOSTS_CONF="$HOME/.config/gutterdesk/hosts"
if [ -f "$HOSTS_CONF" ]; then
    echo "=== Syncing Local Development Domains from $HOSTS_CONF ==="
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        domain=$(echo "$line" | awk '{print $2}')
        if [ -n "$domain" ]; then
            if ! grep -qw "$domain" /etc/hosts; then
                echo "$line" | sudo tee -a /etc/hosts >/dev/null
                echo "  ✓ Added $domain to /etc/hosts"
            else
                echo "  ✓ $domain already present in /etc/hosts"
            fi
        fi
    done < "$HOSTS_CONF"
fi

# Deploy and enable custom Apache virtual hosts from ~/.config/gutterdesk/vhosts if present
VHOST_DIR="$HOME/.config/gutterdesk/vhosts"
if [ -d "$VHOST_DIR" ] && compgen -G "$VHOST_DIR/*.conf" >/dev/null; then
    echo "=== Deploying Custom Apache Virtual Hosts from $VHOST_DIR ==="
    sudo cp "$VHOST_DIR"/*.conf /etc/apache2/sites-available/
    for conf in "$VHOST_DIR"/*.conf; do
        site_name=$(basename "$conf")
        sudo a2ensite -q "$site_name"
        echo "  ✓ Enabled $site_name"
    done
    sudo systemctl reload apache2
    echo "  ✓ Apache reloaded with custom virtual hosts."
fi

# Configure UFW firewall rules for web stack if ufw is installed
if command -v ufw >/dev/null 2>&1; then
    echo "Configuring UFW rules for Web Development Stack..."
    sudo ufw allow 80/tcp comment 'Allow HTTP' || true
    sudo ufw allow 443/tcp comment 'Allow HTTPS' || true
fi

echo "Web development stack installation complete."
