#!/bin/bash
# Syncs this project into Omarchy's plugin directory and reloads it.
#
# The Omarchy shell's plugin file-watcher (and `omarchy plugin validate`)
# doesn't reliably work through a symlinked plugin directory, so this copies
# real files instead of symlinking ~/projects/omarchy-sysmon directly.
# Re-run this after every edit here during development.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/.config/omarchy/plugins/shihab.sysmon"

mkdir -p "$DEST_DIR"
rsync -a --delete --exclude='.git' "$SRC_DIR/" "$DEST_DIR/"
chmod +x "$DEST_DIR/bin/omarchy-sysmon-stats"

omarchy-shell shell rescanPlugins >/dev/null
echo "Synced to $DEST_DIR and reloaded."
