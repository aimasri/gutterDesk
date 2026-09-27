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
[ ! -d "$REPO_DIR" ] && [ -d "$HOME/projects/custom-distro" ] && REPO_DIR="$HOME/projects/custom-distro"
if [ ! -d "$REPO_DIR" ]; then
    FOUND=$(find "$HOME" -maxdepth 3 -type f -name "install.sh" 2>/dev/null | head -n 1)
    [ -n "$FOUND" ] && REPO_DIR=$(dirname "$FOUND")
fi

# Wait for desktop session, panel, and guake to initialize
sleep 3

PROMPT_TEXT="Welcome to gutterDesk!\n\nWould you like to run the Modular System Installer now to configure system capabilities (Banyan, Jellyfin, Web Stack, Torrents)?"

if command -v zenity >/dev/null 2>&1; then
    RESPONSE=$(zenity --question \
        --title="gutterDesk Setup" \
        --text="$PROMPT_TEXT" \
        --ok-label="Launch Installer" \
        --cancel-label="Later" \
        --extra-button="Don't Ask Again" \
        --width=450 \
        2>/dev/null)
    RET=$?

    if [ $RET -eq 0 ]; then
        if [ "$RESPONSE" = "Don't Ask Again" ]; then
            touch "$MARKER"
        else
            touch "$MARKER"
            CMD="cd \"$REPO_DIR\" && ./install.sh"
            if command -v guake >/dev/null 2>&1; then
                if ! pgrep -x guake >/dev/null 2>&1; then
                    guake &
                    sleep 2
                fi
                guake --show
                sleep 0.5
                guake -e "$CMD"
            elif command -v x-terminal-emulator >/dev/null 2>&1; then
                x-terminal-emulator -e "bash -c '$CMD; exec bash'" &
            fi
        fi
    fi
fi
