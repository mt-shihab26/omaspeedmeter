#!/bin/bash
# Formats every file in this repo: qmlformat for QML, Prettier for
# everything else (JS/JSON/YAML/Markdown). Run from anywhere; paths
# are resolved relative to this script.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

# qmlformat only reads settings from a .qmlformat.ini file, so it's
# written here on the fly rather than kept as a separate tracked file.
trap 'rm -f .qmlformat.ini' EXIT
cat >.qmlformat.ini <<'EOF'
[General]
UseTabs=false
IndentWidth=4
EOF

qmlformat -i BarWidget.qml

prettier --write \
    --no-config \
    --tab-width 4 \
    --arrow-parens avoid \
    "*.md" \
    "*.json" \
    "*.js"

prettier --write \
    --no-config \
    --tab-width 2 \
    ".github/**/*.yml"
