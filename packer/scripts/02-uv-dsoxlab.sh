#!/bin/bash
set -euo pipefail

echo "==> 02-uv-dsoxlab: installation de uv et dsoxlab (emplacement système)"

export UV_INSTALL_DIR=/opt/dsoxlab-runtime/bin
export UV_TOOL_DIR=/opt/dsoxlab-runtime/uv-tools
export UV_TOOL_BIN_DIR=/opt/dsoxlab-runtime/bin

mkdir -p "$UV_INSTALL_DIR" "$UV_TOOL_DIR"

curl -LsSf https://astral.sh/uv/install.sh | sh

"$UV_INSTALL_DIR/uv" tool install dsoxlab
"$UV_INSTALL_DIR/dsoxlab" --version

chmod -R a+rX /opt/dsoxlab-runtime

echo "==> 02-uv-dsoxlab: terminé"
