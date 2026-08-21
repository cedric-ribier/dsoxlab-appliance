#!/bin/bash
set -euo pipefail

echo "==> 03-terraform-ansible: installation via mise + ansible-runner (emplacement système)"

sudo apt-get install -y extrepo
sudo extrepo enable mise
sudo apt-get update
sudo apt-get install -y mise

export MISE_DATA_DIR=/opt/dsoxlab-runtime/mise
mkdir -p "$MISE_DATA_DIR"

export PATH="/opt/dsoxlab-runtime/bin:$PATH"
mise use --global terraform@1.14.8
mise install
"$MISE_DATA_DIR/shims/terraform" version

export UV_TOOL_DIR=/opt/dsoxlab-runtime/uv-tools
export UV_TOOL_BIN_DIR=/opt/dsoxlab-runtime/bin

uv tool install ansible-core
uv tool install ansible-runner

"$UV_TOOL_BIN_DIR/ansible" --version
"$UV_TOOL_BIN_DIR/ansible-runner" --version

chmod -R a+rX /opt/dsoxlab-runtime

cat > /etc/profile.d/dsoxlab-runtime-path.sh <<'EOF'
export PATH="/opt/dsoxlab-runtime/bin:/opt/dsoxlab-runtime/mise/shims:$PATH"
EOF
chmod +x /etc/profile.d/dsoxlab-runtime-path.sh

echo "==> 03-terraform-ansible: terminé"
