#!/bin/bash
set -euo pipefail

echo "==> 03-terraform-ansible: installation via mise + ansible-runner (emplacement système)"

sudo apt-get install -y extrepo
sudo extrepo enable mise
sudo apt-get update
sudo apt-get install -y mise

export MISE_DATA_DIR=/opt/dsoxlab-appliance/mise
mkdir -p "$MISE_DATA_DIR"

export PATH="/opt/dsoxlab-appliance/bin:$PATH"

mkdir -p /etc/mise
cat > /etc/mise/config.toml <<'EOF'
[tools]
terraform = "1.14.8"
EOF

mise install
"$MISE_DATA_DIR/shims/terraform" version




uv tool install ansible-core
uv tool install ansible-runner

"$UV_TOOL_BIN_DIR/ansible" --version
"$UV_TOOL_BIN_DIR/ansible-runner" --version

chmod -R a+rX /opt/dsoxlab-appliance

cat > /etc/profile.d/dsoxlab-appliance-path.sh <<'EOF'
export PATH="/opt/dsoxlab-appliance/bin:/opt/dsoxlab-appliance/mise/shims:$PATH"
export UV_TOOL_DIR=/opt/dsoxlab-appliance/uv-tools
export UV_TOOL_BIN_DIR=/opt/dsoxlab-appliance/bin
EOF
chmod +x /etc/profile.d/dsoxlab-appliance-path.sh

echo "==> 03-terraform-ansible: terminé"
