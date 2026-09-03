#!/bin/bash
set -euo pipefail

echo "==> 03-terraform-ansible: installation via mise + ansible-runner (emplacement système)"

# Ajout du dépôt mise via extrepo, puis installation du paquet mise
# Add the mise repo via extrepo, then install the mise package
sudo apt-get install -y extrepo
sudo extrepo enable mise
sudo apt-get update
sudo apt-get install -y mise

export MISE_DATA_DIR=/opt/dsoxlab-appliance/mise
mkdir -p "$MISE_DATA_DIR"

export PATH="/opt/dsoxlab-appliance/bin:$PATH"

# Épingle la version de Terraform installée par mise
# Pin the Terraform version installed by mise
mkdir -p /etc/mise
cat > /etc/mise/config.toml <<'EOF'
[tools]
terraform = "1.14.8"
EOF

mise install
"$MISE_DATA_DIR/shims/terraform" version

export UV_TOOL_DIR=/opt/dsoxlab-appliance/uv-tools
export UV_TOOL_BIN_DIR=/opt/dsoxlab-appliance/bin

# Installation d'Ansible via uv
# Install Ansible through uv
uv tool install ansible-core
uv tool install ansible-runner

"$UV_TOOL_BIN_DIR/ansible" --version
"$UV_TOOL_BIN_DIR/ansible-runner" --version

# Rend l'installation lisible par l'utilisateur final créé au premier démarrage
# Make the install readable by the end-user account created on first boot
chmod -R a+rX /opt/dsoxlab-appliance

# Expose les outils dans le PATH de tous les shells de connexion
# Expose the tools in the PATH of every login shell
cat > /etc/profile.d/dsoxlab-appliance-path.sh <<'EOF'
export PATH="/opt/dsoxlab-appliance/bin:/opt/dsoxlab-appliance/mise/shims:$PATH"
export UV_TOOL_DIR=/opt/dsoxlab-appliance/uv-tools
export UV_TOOL_BIN_DIR=/opt/dsoxlab-appliance/bin
EOF
chmod +x /etc/profile.d/dsoxlab-appliance-path.sh

echo "==> 03-terraform-ansible: terminé"
