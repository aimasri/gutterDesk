#!/usr/bin/env bash
# ==============================================================================
# Title:           module-webstack.sh
# Purpose:         Provisions Full-Stack Web Development (Apache2, Postgres, Redis, PHP)
# Why This Design: Centralizes local multi-domain web hosting, reverse proxying,
#                  and database backends. Clones active development repositories
#                  via manifest (~/.config/gutterdesk/webstack_repos.conf) and mounts
#                  custom virtual hosts into Apache2 automatically.
# Privilege:       Dual (Requires sudo for system packages & Apache; runs user tasks as target)
# Subsystems:      Apache2, PostgreSQL, Redis, UFW firewall, Git
# Idempotency:     Validates vhost symlinks, hosts entries, and git clones prior to execution.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

run_as_target() {
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$TARGET_USER" != "root" ]; then
        sudo -u "$TARGET_USER" -H "$@"
    else
        "$@"
    fi
}

echo "=== [Web Stack] Installing Apache2, PostgreSQL, Redis & PHP Toolchains ==="

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

sudo apt-get update

PACKAGE_LIST="$SCRIPT_DIR/packages/webstack.list"
if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found at $PACKAGE_LIST" >&2
    exit 1
fi

PACKAGES=($(grep -v '^[[:space:]]*#' "$PACKAGE_LIST" | grep -v '^[[:space:]]*$'))
if [ "${#PACKAGES[@]}" -gt 0 ]; then
    sudo apt-get install -y "${PACKAGES[@]}"
fi

# Enable Apache core modules
echo "Enabling Apache modules (rewrite, ssl, headers, proxy, proxy_http)..."
sudo a2enmod rewrite ssl headers proxy proxy_http 2>/dev/null || true

# Start and enable databases
echo "Starting database daemons..."
sudo systemctl enable --now postgresql
sudo systemctl enable --now redis-server

run_as_target mkdir -p "$TARGET_HOME/projects" "$TARGET_HOME/.config/gutterdesk"

# Clone web repositories if configured in ~/.config/gutterdesk/webstack_repos.conf
REPO_CONF="$TARGET_HOME/.config/gutterdesk/webstack_repos.conf"
if [ -f "$REPO_CONF" ]; then
    echo "Found repository manifest at $REPO_CONF. Cloning projects..."
    grep -v '^[[:space:]]*#' "$REPO_CONF" | grep -v '^[[:space:]]*$' | while IFS=':' read -r NAME URL; do
        if [ -n "$NAME" ] && [ -n "$URL" ]; then
            TARGET="$TARGET_HOME/projects/$NAME"
            if [ ! -d "$TARGET/.git" ]; then
                echo "Cloning $NAME..."
                run_as_target git clone "$URL" "$TARGET" || echo "Notice: Could not clone $NAME (verify SSH keys for $URL)"
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
chmod o+x "$TARGET_HOME"

# Sync custom local domain mappings from ~/.config/gutterdesk/hosts if present
HOSTS_CONF="$TARGET_HOME/.config/gutterdesk/hosts"
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
VHOST_DIR="$TARGET_HOME/.config/gutterdesk/vhosts"
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
    sudo ufw allow 80/tcp comment 'Allow HTTP' 2>/dev/null || true
    sudo ufw allow 443/tcp comment 'Allow HTTPS' 2>/dev/null || true
fi

echo "=== Web Development Stack Provisioning Complete ==="
