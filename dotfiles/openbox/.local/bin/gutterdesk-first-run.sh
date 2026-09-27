#!/bin/bash
# gutterDesk: First Startup Setup Prompt
# ======================================

MARKER="$HOME/.config/gutterdesk/.first_boot_done"
mkdir -p "$HOME/.config/gutterdesk"

# Only run if first-boot marker does not exist
if [ -f "$MARKER" ]; then
    exit 0
fi

# Locate the installation repository
REPO_DIR="$HOME/projects/gutterDesk"
if [ ! -d "$REPO_DIR" ]; then
    FOUND=$(find "$HOME" -maxdepth 3 -type f -name "install.sh" 2>/dev/null | head -n 1)
    [ -n "$FOUND" ] && REPO_DIR=$(dirname "$FOUND")
fi

# If invoked inside Guake terminal, display interactive whiptail prompt
if [ "$1" = "--prompt-in-terminal" ]; then
    if whiptail --title "gutterDesk Setup" \
        --yes-button "Launch Installer" \
        --no-button "Later" \
        --yesno "Welcome to gutterDesk!\n\nWould you like to run the Modular System Installer now to configure system capabilities (Banyan, Jellyfin, Web Stack, Torrents)?" 12 65; then
        touch "$MARKER"
        cd "$REPO_DIR" && ./install.sh
    else
        echo ""
        echo "Setup postponed. You can launch './install.sh' at any time in $REPO_DIR."
        sleep 2
        command -v guake >/dev/null 2>&1 && guake --hide
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
    guake -e "\"$HOME/.local/bin/gutterdesk-first-run.sh\" --prompt-in-terminal"
elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e "bash -c '\"$HOME/.local/bin/gutterdesk-first-run.sh\" --prompt-in-terminal; exec bash'" &
fi
