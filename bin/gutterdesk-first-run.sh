#!/usr/bin/env bash
# ==============================================================================
# Title:           gutterdesk-first-run.sh
# Purpose:         First-Boot Desktop Setup Prompt & Capability Assistant
# Why This Design: After initial Debian bootstrap and first graphical login, users
#                  need a clear, non-intrusive prompt to either restore private
#                  credentials (backup/connect.sh) or launch the interactive modular
#                  capability installer (install.sh). Once run or dismissed, a state
#                  marker (~/.config/gutterdesk/.first_boot_done) prevents re-triggering.
# Privilege:       Target User (X11 desktop session context)
# Subsystems:      Guake terminal, whiptail, Openbox session autostart
# Idempotency:     Guarded by marker file; exits immediately (0) on subsequent boots.
# ==============================================================================

set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
[ -z "$TARGET_HOME" ] && TARGET_HOME="$HOME"

MARKER="$TARGET_HOME/.config/gutterdesk/.first_boot_done"
mkdir -p "$TARGET_HOME/.config/gutterdesk"

# Only run if first-boot marker does not exist
if [ -f "$MARKER" ]; then
    exit 0
fi

# Locate the installation repository
REPO_DIR="$TARGET_HOME/gutterDesk"
if [ ! -d "$REPO_DIR" ]; then
    FOUND=$(find "$TARGET_HOME" -maxdepth 3 -type f -name "install.sh" 2>/dev/null | head -n 1 || echo "")
    [ -n "$FOUND" ] && REPO_DIR=$(dirname "$FOUND")
fi

# If invoked inside Guake terminal, display interactive whiptail prompt
if [ "${1:-}" = "--prompt-in-terminal" ]; then
    if command -v whiptail >/dev/null 2>&1 && whiptail --title "gutterDesk Setup" \
        --yes-button "Launch Installer" \
        --no-button "Later" \
        --yesno "Welcome to gutterDesk!\n\n[BEFORE INSTALLING MODULES]\n• If you previously made a private backup:\n    Extract it and run './connect.sh' in ~/gutterDesk/backup\n    to restore your identity, SSH keys, and custom profiles.\n\n• If this is a fresh machine without a previous backup:\n    You can proceed directly, or authenticate GitHub ('gh auth login')\n    and sign into Google Chrome.\n\nWould you like to run the Modular System Installer now?" 18 78; then
        touch "$MARKER"
        cd "$REPO_DIR" && ./install.sh
    else
        echo ""
        echo "Setup postponed. You can launch './install.sh' at any time in $REPO_DIR."
        sleep 2
        command -v guake >/dev/null 2>&1 && guake --hide || true
    fi
    exit 0
fi

# Wait for desktop session, panel, and guake daemon to initialize
sleep 3

# Drop down Guake and trigger interactive setup prompt
if command -v guake >/dev/null 2>&1; then
    if ! pgrep -x guake >/dev/null 2>&1; then
        guake &
        sleep 2
    fi
    guake --show
    sleep 0.5
    guake -e "\"/usr/local/bin/gutterdesk-first-run.sh\" --prompt-in-terminal"
elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e "bash -c '\"/usr/local/bin/gutterdesk-first-run.sh\" --prompt-in-terminal; exec bash'" &
fi
