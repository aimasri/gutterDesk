#!/bin/bash
set -e
echo "=== Building Banyan Desktop Dashboard ==="

[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    echo "Banyan repository not found. Running Banyan Engine setup first..."
    "$SCRIPT_DIR/modules/module-banyan-engine.sh"
fi

mkdir -p "$HOME/projects/Banyan/desktop/build"
cd "$HOME/projects/Banyan/desktop/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"

mkdir -p "$HOME/.local/bin"
cp banyan_daemon "$HOME/.local/bin/banyan_daemon"
sudo install -m 755 banyan_daemon /usr/local/bin/banyan_daemon 2>/dev/null || true
echo "Banyan Dashboard compiled and installed to $HOME/.local/bin/banyan_daemon"
