#!/usr/bin/env bash
# ==============================================================================
# Title:           module-torrent.sh
# Purpose:         Provisions Transmission BitTorrent Client & UFW Firewall Hardening
# Why This Design: When running background torrent acquisition, the host must be
#                  isolated from unauthorized inbound network probes while preserving
#                  LAN communication, Tailscale mesh connectivity, and SSH management.
#                  Also registers the Torrent entry in the modular Openbox menu.
# Privilege:       Dual (Requires sudo for apt-get & ufw; runs menu as target user)
# Subsystems:      APT, UFW firewall, Openbox modular menu (gutterdesk-menu)
# Idempotency:     UFW rules use explicit comments and idempotently update;
#                  gutterdesk-menu enables the snippet without duplicate entries.
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

echo "=== [Torrent Machine] Installing Transmission & Configuring Firewall ==="

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

sudo apt-get update

PACKAGE_LIST="$SCRIPT_DIR/packages/torrent.list"
if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found at $PACKAGE_LIST" >&2
    exit 1
fi

PACKAGES=($(grep -v '^[[:space:]]*#' "$PACKAGE_LIST" | grep -v '^[[:space:]]*$'))
if [ "${#PACKAGES[@]}" -gt 0 ]; then
    sudo apt-get install -y "${PACKAGES[@]}"
fi

echo "Configuring UFW firewall rules for secure torrenting..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh comment 'Allow SSH'
sudo ufw allow in on tailscale0 comment 'Allow Tailscale mesh traffic' 2>/dev/null || true
sudo ufw allow from 192.168.0.0/16 comment 'Allow private LAN communication' 2>/dev/null || true
sudo ufw allow from 10.0.0.0/8 comment 'Allow private LAN communication' 2>/dev/null || true
sudo ufw allow from 172.16.0.0/12 comment 'Allow private LAN communication' 2>/dev/null || true
sudo ufw allow 18813:18814/udp comment 'Allow Banyan Telemetry and Discovery' 2>/dev/null || true
sudo ufw allow 18812/tcp comment 'Allow Banyan Bridge RPyC' 2>/dev/null || true
sudo ufw --force enable

echo "✓ Transmission and UFW firewall configured successfully."

# Enable modular Openbox menu entry
MENU_BIN=""
for candidate in \
    "/usr/local/bin/gutterdesk-menu" \
    "$SCRIPT_DIR/bin/gutterdesk-menu"; do
    if [ -x "$candidate" ]; then
        MENU_BIN="$candidate"
        break
    fi
done

if [ -n "$MENU_BIN" ]; then
    echo "Activating Torrent launcher in Openbox root menu..."
    run_as_target "$MENU_BIN" enable torrent
fi

echo "=== Torrent Machine Provisioning Complete ==="
