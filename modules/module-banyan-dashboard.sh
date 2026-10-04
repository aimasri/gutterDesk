#!/usr/bin/env bash
# ==============================================================================
# Title:           module-banyan-dashboard.sh
# Purpose:         Builds & Provisions Banyan Algorithmic Trading C++/Qt6 Dashboard
# Why This Design: The Banyan Trading Dashboard requires high-speed native XCB/Qt6
#                  event polling for live telemetry and system tray monitoring.
#                  This module compiles the native C++ binary, registers user systemd
#                  units, and links desktop entry launchers.
# Privilege:       Dual (Requires sudo for build packages; compiles/deploys as target user)
# Subsystems:      Qt6, CMake, systemd (user session), Openbox modular menu
# Idempotency:     Validates source checkout, builds incrementally via CMake, and
#                  updates systemd user units idempotently.
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

echo "=== [Banyan Dashboard] Building Banyan Desktop Dashboard ==="

BANYAN_CONF="$TARGET_HOME/.config/gutterdesk/banyan.conf"
[ -f "$BANYAN_CONF" ] && source "$BANYAN_CONF"

BANYAN_REPO_URL="${BANYAN_REPO_URL:-git@github.com:aimasri/Banyan.git}"

if [ ! -d "$TARGET_HOME/projects/Banyan/.git" ]; then
    echo "Cloning Banyan repository for dashboard source code..."
    run_as_target mkdir -p "$TARGET_HOME/projects"
    if [ -f "$TARGET_HOME/.ssh/id_ed25519" ]; then
        run_as_target git clone "$BANYAN_REPO_URL" "$TARGET_HOME/projects/Banyan" 2>/dev/null || true
    fi
    if [ ! -d "$TARGET_HOME/projects/Banyan/.git" ]; then
        run_as_target git clone "https://github.com/aimasri/Banyan.git" "$TARGET_HOME/projects/Banyan" 2>/dev/null || true
    fi
    if [ ! -d "$TARGET_HOME/projects/Banyan/.git" ]; then
        echo "Error: Failed to clone Banyan repository." >&2
        echo "The Banyan repository is private. Please ensure your GitHub SSH key" >&2
        echo "(~/.ssh/id_ed25519) is connected (via ./connect.sh in private backup)" >&2
        echo "or authenticate via 'gh auth login' before installing the dashboard." >&2
        exit 1
    fi
fi

if [ ! -d "$TARGET_HOME/projects/Banyan/desktop" ]; then
    echo "Error: Banyan desktop directory not found at $TARGET_HOME/projects/Banyan/desktop." >&2
    echo "Please ensure the Banyan repository was cloned properly." >&2
    exit 1
fi

if ! command -v cmake >/dev/null 2>&1 || ! pkg-config --exists Qt6Core 2>/dev/null; then
    echo "=== Installing Banyan Dashboard Build Dependencies ==="
    sudo apt-get update
    PACKAGE_LIST="$SCRIPT_DIR/packages/banyan-dashboard.list"
    PACKAGES=($(grep -v '^[[:space:]]*#' "$PACKAGE_LIST" | grep -v '^[[:space:]]*$'))
    sudo apt-get install -y "${PACKAGES[@]}"
else
    echo "✓ Build toolchain and Qt6 dependencies already installed."
fi

echo "=== Compiling Banyan Desktop UI & Tray Daemon ==="
run_as_target mkdir -p "$TARGET_HOME/projects/Banyan/desktop/build"
run_as_target bash -c "cd '$TARGET_HOME/projects/Banyan/desktop/build' && cmake .. -DCMAKE_BUILD_TYPE=Release && make -j\$(nproc)"

run_as_target mkdir -p "$TARGET_HOME/.local/bin"
BUILD_DIR="$TARGET_HOME/projects/Banyan/desktop/build"

if [ -f "$BUILD_DIR/banyan_daemon" ]; then
    run_as_target install -m 755 "$BUILD_DIR/banyan_daemon" "$TARGET_HOME/.local/bin/banyan_daemon"
    sudo install -m 755 "$BUILD_DIR/banyan_daemon" /usr/local/bin/banyan_daemon 2>/dev/null || true
fi

if [ -f "$BUILD_DIR/banyan_dashboard" ]; then
    run_as_target install -m 755 "$BUILD_DIR/banyan_dashboard" "$TARGET_HOME/.local/bin/banyan_dashboard"
    sudo install -m 755 "$BUILD_DIR/banyan_dashboard" /usr/local/bin/banyan_dashboard 2>/dev/null || true
fi

echo "Banyan Dashboard compiled and installed to $TARGET_HOME/.local/bin/banyan_daemon"

echo "=== Installing Banyan Desktop Systemd Service ==="
SYSTEMD_USER_DIR="$TARGET_HOME/.config/systemd/user"
run_as_target mkdir -p "$SYSTEMD_USER_DIR"

cat << 'EOF' | run_as_target tee "$SYSTEMD_USER_DIR/banyan-desktop.service" >/dev/null
[Unit]
Description=Banyan Desktop Command Center & System Tray Daemon
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/banyan_daemon
WorkingDirectory=%h
Restart=on-failure
RestartSec=3
Environment=DISPLAY=:0
Environment=XAUTHORITY=%h/.Xauthority

[Install]
WantedBy=default.target
EOF

echo "=== Installing Desktop Integration & Application Icons ==="
run_as_target mkdir -p "$TARGET_HOME/.local/share/applications" "$TARGET_HOME/.local/share/icons/hicolor/256x256/apps"

ICON_SRC="$TARGET_HOME/projects/Banyan/assets/icon.png"
if [ -f "$ICON_SRC" ]; then
    run_as_target cp "$ICON_SRC" "$TARGET_HOME/.local/share/icons/hicolor/256x256/apps/banyan.png"
    sudo cp "$ICON_SRC" /usr/share/pixmaps/banyan.png 2>/dev/null || true
    sudo cp "$ICON_SRC" /usr/share/icons/hicolor/256x256/apps/banyan.png 2>/dev/null || true
    which gtk-update-icon-cache >/dev/null 2>&1 && sudo gtk-update-icon-cache -f -q /usr/share/icons/hicolor 2>/dev/null || true
fi

cat << 'EOF' | run_as_target tee "$TARGET_HOME/.local/share/applications/banyan.desktop" >/dev/null
[Desktop Entry]
Name=Banyan
GenericName=Algorithmic Trading Dashboard
Comment=Real-time algorithmic trading command center & system tray monitor
Exec=banyan_daemon --show
Icon=banyan
Terminal=false
Type=Application
Categories=Office;Finance;Network;
StartupWMClass=banyan_daemon
EOF

sudo cp "$TARGET_HOME/.local/share/applications/banyan.desktop" /usr/share/applications/banyan.desktop 2>/dev/null || true
which update-desktop-database >/dev/null 2>&1 && sudo update-desktop-database /usr/share/applications 2>/dev/null || true

echo "Reloading systemd user daemon..."
run_as_target systemctl --user daemon-reload 2>/dev/null || true

if [ -n "${DISPLAY:-}" ]; then
    echo "Starting banyan-desktop.service in current graphical session..."
    run_as_target systemctl --user restart banyan-desktop.service 2>/dev/null || true
fi

# Enable Openbox Trading menu
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
    run_as_target "$MENU_BIN" enable trading
fi

echo "=== Banyan Desktop Dashboard Provisioning Complete ==="
