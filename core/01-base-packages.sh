#!/usr/bin/env bash
# ==============================================================================
# Title:           01-base-packages.sh
# Purpose:         Installs Universal Base OS Packages from packages/base.list
# Why This Design: The Universal Base provisions X11, Openbox 3, Tint2, Picom,
#                  PCManFM, Guake, iwd, audio, and light-locker while avoiding heavy
#                  desktop environments to maintain <400MB idle RAM.
# Privilege:       Root (Requires sudo for apt-get)
# Subsystems:      APT, X11, Openbox, Tint2, Audio (ALSA/Pulse), iwd
# Idempotency:     apt-get handles installed packages idempotently.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Requesting administrative privileges..."
    sudo -v
fi

echo "--> [2/8] Updating package lists and installing Universal Base packages..."
sudo apt-get update

PACKAGE_LIST="$SCRIPT_DIR/packages/base.list"
if [ ! -f "$PACKAGE_LIST" ]; then
    echo "Error: Base package list not found at $PACKAGE_LIST" >&2
    exit 1
fi

PACKAGES_TO_INSTALL=()
for pkg in $(grep -v '^[[:space:]]*#' "$PACKAGE_LIST" | grep -v '^[[:space:]]*$'); do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        PACKAGES_TO_INSTALL+=("$pkg")
    elif [ "$pkg" = "nitrogen" ]; then
        echo "Notice: Package 'nitrogen' not found in active repositories; falling back to 'feh'..."
        PACKAGES_TO_INSTALL+=("feh")
    else
        echo "Notice: Package '$pkg' not found in active repositories, skipping..."
    fi
done

if [ "${#PACKAGES_TO_INSTALL[@]}" -gt 0 ]; then
    sudo apt-get install -y "${PACKAGES_TO_INSTALL[@]}"
fi

# Remove redundant google-chrome.list if the package created google-chrome.sources (avoids duplicate warnings)
if [ -f /etc/apt/sources.list.d/google-chrome.sources ] && [ -f /etc/apt/sources.list.d/google-chrome.list ]; then
    sudo rm -f /etc/apt/sources.list.d/google-chrome.list
fi

echo "✓ Universal Base packages installed successfully."
