#!/bin/bash

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

qmlformat -i BarWidget.qml

prettier --write \
    "*.md" \
    "*.json" \
    "*.js" \
    ".github/**/*.yml"
