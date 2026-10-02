#!/bin/bash
set -e
echo "=== Building Banyan Desktop Dashboard ==="

[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    echo "Banyan repository not found. Running Banyan Engine setup first..."
    "$SCRIPT_DIR/modules/module-banyan-engine.sh"
fi

if [ ! -d "$HOME/projects/Banyan/desktop" ]; then
    echo "Error: Banyan desktop directory not found at $HOME/projects/Banyan/desktop."
    echo "Please ensure the Banyan repository was cloned properly."
    exit 1
fi

if ! command -v cmake >/dev/null 2>&1 || ! pkg-config --exists Qt6Core 2>/dev/null; then
    echo "=== Installing Banyan Dashboard Build Dependencies ==="
    sudo apt-get update
    sudo apt-get install -y $(grep -v '^#' "$SCRIPT_DIR/packages/banyan-dashboard.list" | tr '\n' ' ')
else
    echo "✓ Build toolchain and Qt6 dependencies already installed."
fi


echo "=== Compiling Banyan Desktop UI & Tray Daemon ==="
mkdir -p "$HOME/projects/Banyan/desktop/build"
cd "$HOME/projects/Banyan/desktop/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"

mkdir -p "$HOME/.local/bin"
install -m 755 banyan_daemon "$HOME/.local/bin/banyan_daemon"
[ -f banyan_dashboard ] && install -m 755 banyan_dashboard "$HOME/.local/bin/banyan_dashboard"
sudo install -m 755 banyan_daemon /usr/local/bin/banyan_daemon 2>/dev/null || true
[ -f banyan_dashboard ] && sudo install -m 755 banyan_dashboard /usr/local/bin/banyan_dashboard 2>/dev/null || true
echo "Banyan Dashboard compiled and installed to $HOME/.local/bin/banyan_daemon"

echo "=== Installing Banyan Desktop Systemd Service ==="
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cat << 'EOF' > "$SYSTEMD_USER_DIR/banyan-desktop.service"
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
mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"

if [ -f "$HOME/projects/Banyan/assets/icon.png" ]; then
    cp "$HOME/projects/Banyan/assets/icon.png" "$HOME/.local/share/icons/hicolor/256x256/apps/banyan.png"
    sudo cp "$HOME/projects/Banyan/assets/icon.png" /usr/share/pixmaps/banyan.png 2>/dev/null || true
    sudo cp "$HOME/projects/Banyan/assets/icon.png" /usr/share/icons/hicolor/256x256/apps/banyan.png 2>/dev/null || true
    sudo gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
fi

cat << 'EOF' > "$HOME/.local/share/applications/banyan.desktop"
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

sudo cp "$HOME/.local/share/applications/banyan.desktop" /usr/share/applications/banyan.desktop 2>/dev/null || true
sudo update-desktop-database 2>/dev/null || true

echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

# Start the desktop daemon if inside an active X11 display session
if [ -n "$DISPLAY" ]; then
    echo "Starting banyan-desktop.service in current graphical session..."
    systemctl --user restart banyan-desktop.service
fi

# Enable Openbox Trading menu
if command -v gutterdesk-menu >/dev/null 2>&1; then
    gutterdesk-menu enable trading
elif [ -x "$HOME/.local/bin/gutterdesk-menu" ]; then
    "$HOME/.local/bin/gutterdesk-menu" enable trading
fi

echo ""
echo "=========================================================="
echo "  Banyan Desktop Dashboard installation complete!         "
echo "=========================================================="
echo "The system tray daemon is wired to autostart with Openbox"
echo "(via ~/.config/openbox/autostart -> banyan-desktop.service)."
echo "You can also launch the command center from the Openbox menu"
echo "or by running: banyan_daemon --show"
echo "=========================================================="


