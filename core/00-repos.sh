#!/usr/bin/env bash
# ==============================================================================
# Title:           00-repos.sh
# Purpose:         Configures Debian 13 (Trixie) Online Mirrors & Official GPG Keyrings
# Why This Design: Netinst installations often leave CD-ROM / USB media entries in
#                  sources.list, causing offline apt errors. This stage disables
#                  removable media entries, configures official deb.debian.org
#                  and security.debian.org mirrors, and installs third-party GPG
#                  keys (Google Chrome) into /usr/share/keyrings.
# Privilege:       Root (Requires sudo)
# Subsystems:      APT, dpkg, GPG keyrings
# Idempotency:     Validates active mirror entries and skips duplicate key injection.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

echo "--> [1/8] Configuring system repositories and online mirrors..."
sudo mkdir -p /etc/apt/keyrings /usr/share/keyrings

# Disable CD-ROM / USB netinst sources that block online package fetching
if [ -f /etc/apt/sources.list ]; then
    sudo sed -i 's/^[[:space:]]*deb cdrom:/# deb cdrom:/g' /etc/apt/sources.list
fi
if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    sudo sed -i 's/URIs:[[:space:]]*cdrom:/Enabled: no\n# URIs: cdrom:/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
fi

# Ensure official Debian online mirrors are configured
CODENAME=$(grep -oP '^VERSION_CODENAME=\K\w+' /etc/os-release 2>/dev/null || echo "trixie")
HAS_ONLINE_MIRROR=$(grep -rhE '(deb\s+http(s)?://deb\.debian\.org|URIs:\s*http(s)?://deb\.debian\.org)' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || true)

if [ -z "$HAS_ONLINE_MIRROR" ]; then
    echo "No active deb.debian.org mirror detected. Configuring official $CODENAME repositories in /etc/apt/sources.list.d/debian.sources..."
    [ -f /etc/apt/sources.list.d/debian.sources ] && sudo cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak 2>/dev/null || true
    sudo tee /etc/apt/sources.list.d/debian.sources >/dev/null << EOF
Types: deb
URIs: http://deb.debian.org/debian/
Suites: $CODENAME $CODENAME-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security/
Suites: $CODENAME-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
fi

# Remove obsolete/abandoned antigravity APT list if present
sudo rm -f /etc/apt/sources.list.d/antigravity.list

if [ -f "$SCRIPT_DIR/keys/google-chrome.gpg" ]; then
    sudo install -m 0644 "$SCRIPT_DIR/keys/google-chrome.gpg" /usr/share/keyrings/google-chrome.gpg
    echo "deb [signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome-stable/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
fi

echo "✓ System repositories configured successfully."
