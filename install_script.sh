#!/usr/bin/env bash
set -e

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Created: $TMP_DIR"
cd "$TMP_DIR"

git clone https://github.com/rohanvashisht1234/zigp --depth=1
cd zigp

echo "Installing zigp..."
zig build -Doptimize=ReleaseFast install --prefix "$HOME/.local"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.bashrc 2>/dev/null || true
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>~/.zshrc 2>/dev/null || true
    echo "Added ~/.local/bin to your PATH (will apply on next shell start)"
fi

cd ~
echo "Done!"

echo "Please star ⭐️ zigp repo: https://github.com/zigistry/zigp"