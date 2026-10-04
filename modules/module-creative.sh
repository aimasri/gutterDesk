#!/usr/bin/env bash
# ==============================================================================
# Title:           module-creative.sh
# Purpose:         Provisions the gutterDesk Creative Suite
# Why This Design: Modular capability provisioning ensures the Universal Base OS
#                  remains ultra-light (<400MB idle RAM) while enabling professional
#                  vector illustration, 3D computer graphics, and video production
#                  on demand. Also registers the Creative submenu in Openbox.
# Privilege:       Dual (Requires sudo for apt-get; runs menu as target user)
# Subsystems:      APT package manager, Openbox modular menu (gutterdesk-menu)
# Idempotency:     Package manager handles duplicate installs; gutterdesk-menu
#                  enables the snippet and regenerates menu.xml safely.
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

echo "=== [Creative Suite] Installing Creative & Digital Media Packages ==="

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges for package installation..."
    sudo -v
fi

sudo apt-get update

PACKAGE_LIST="$SCRIPT_DIR/packages/creative.list"
if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Package list not found at $PACKAGE_LIST" >&2
    exit 1
fi

PACKAGES=($(grep -v '^[[:space:]]*#' "$PACKAGE_LIST" | grep -v '^[[:space:]]*$'))
if [ "${#PACKAGES[@]}" -gt 0 ]; then
    sudo apt-get install -y "${PACKAGES[@]}"
fi

echo "✓ Creative Suite packages installed successfully."

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
    echo "Activating Creative Suite in Openbox root menu..."
    run_as_target "$MENU_BIN" enable creative
fi

echo "=== Creative Suite Provisioning Complete ==="
