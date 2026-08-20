#!/bin/bash
set -euo pipefail

echo "==> 03-terraform-ansible: installation via mise + ansible-runner"

sudo -u packer bash <<'EOF'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
EOF

# mise, installé au niveau système pour que Terraform soit disponible
# sans dépendre d'une session utilisateur spécifique — cohérent avec le
# guide d'installation référencé pour ce projet
# (blog.stephane-robert.info/.../installer-terraform/)
sudo apt-get install -y extrepo
sudo extrepo enable mise
sudo apt-get update
sudo apt-get install -y mise

sudo -u packer bash <<'EOF'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"
mise use --global terraform@1.14.8
mise install
terraform version
EOF

# ansible-core (déjà partiellement couvert par dsoxlab, installé ici en
# garantie explicite — cf. constat de l'audit #40 sur cette dépendance
# manquante) + ansible-runner, requis par dsoxlab pour jouer les
# setup.yaml des labs.
sudo -u packer bash <<'EOF'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
uv tool install ansible-core
uv tool install ansible-runner

"$HOME/.local/bin/ansible" --version
"$HOME/.local/bin/ansible-runner" --version
EOF

echo "==> 03-terraform-ansible: terminé"
