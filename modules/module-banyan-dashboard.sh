#!/bin/bash
set -e
echo "=== Building Banyan Desktop Dashboard ==="

[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

BANYAN_REPO_URL="${BANYAN_REPO_URL:-git@github.com:aimasri/Banyan.git}"

if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    echo "Cloning Banyan repository from $BANYAN_REPO_URL..."
    if ! git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan"; then
        echo "Error: Failed to clone Banyan repository."
        echo "Ensure your GitHub SSH key (~/.ssh/id_ed25519) is installed on this machine."
        exit 1
    fi
fi

mkdir -p "$HOME/projects/Banyan/desktop/build"
cd "$HOME/projects/Banyan/desktop/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"

mkdir -p "$HOME/.local/bin"
cp banyan_daemon "$HOME/.local/bin/banyan_daemon"
sudo install -m 755 banyan_daemon /usr/local/bin/banyan_daemon 2>/dev/null || true
echo "Banyan Dashboard compiled and installed to $HOME/.local/bin/banyan_daemon"
