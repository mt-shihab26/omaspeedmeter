#!/bin/bash
# Symlinks ~/.config/omarchy/plugins/omaspeedmeter to this repo, so Omarchy
# picks up the plugin directly from the working tree during development.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
repo_dir="$(pwd)"
plugins_dir="$HOME/.config/omarchy/plugins"
target="$plugins_dir/omaspeedmeter"

mkdir -p "$plugins_dir"

if [ -L "$target" ]; then
    rm "$target"
elif [ -e "$target" ]; then
    echo "error: $target already exists and is not a symlink" >&2
    exit 1
fi

ln -s "$repo_dir" "$target"
echo "linked $target -> $repo_dir"
