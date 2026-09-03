#!/bin/bash
set -euo pipefail

echo "==> 02-uv-dsoxlab: installation de uv et dsoxlab (emplacement système)"

# Emplacement système partagé, pas le HOME de packer (retiré en fin de build)
# System-wide location, not packer's HOME (removed at the end of the build)
export UV_INSTALL_DIR=/opt/dsoxlab-appliance/bin
export UV_TOOL_DIR=/opt/dsoxlab-appliance/uv-tools
export UV_TOOL_BIN_DIR=/opt/dsoxlab-appliance/bin

mkdir -p "$UV_INSTALL_DIR" "$UV_TOOL_DIR"

# Installation de uv, puis de dsoxlab via uv
# Install uv, then install dsoxlab through uv
curl -LsSf https://astral.sh/uv/install.sh | sh

"$UV_INSTALL_DIR/uv" tool install dsoxlab
"$UV_INSTALL_DIR/dsoxlab" --version

# Rend l'installation lisible par l'utilisateur final créé au premier démarrage
# Make the install readable by the end-user account created on first boot
chmod -R a+rX /opt/dsoxlab-appliance

echo "==> 02-uv-dsoxlab: terminé"
