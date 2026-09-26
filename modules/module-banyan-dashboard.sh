#!/bin/bash
set -e
echo "=== Building Banyan Desktop Dashboard ==="

[ -f "$HOME/.config/gutterdesk/banyan.conf" ] && source "$HOME/.config/gutterdesk/banyan.conf"

if [ ! -d "$HOME/projects/Banyan/.git" ]; then
    if [ -n "$BANYAN_REPO_URL" ]; then
        echo "Cloning Banyan repository..."
        mkdir -p "$HOME/projects"
        git clone "$BANYAN_REPO_URL" "$HOME/projects/Banyan"
    else
        echo "Notice: Banyan source tree not found at $HOME/projects/Banyan. Skipping build."
        exit 0
    fi
fi

mkdir -p "$HOME/projects/Banyan/desktop/build"
cd "$HOME/projects/Banyan/desktop/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"

mkdir -p "$HOME/.local/bin"
cp banyan_daemon "$HOME/.local/bin/banyan_daemon"
echo "Banyan Dashboard compiled and installed to $HOME/.local/bin/banyan_daemon"
