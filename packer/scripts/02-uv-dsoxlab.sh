#!/bin/bash
set -euo pipefail

echo "==> 02-uv-dsoxlab: installation de uv et dsoxlab"

# Installé pour l'utilisateur packer, pas root — cohérent avec l'usage
# réel : l'utilisateur final de l'appliance ne travaillera pas en root.
sudo -u packer bash <<'EOF'
set -euo pipefail
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

uv tool install dsoxlab

# Sanity check immédiat — échoue le build tout de suite si l'installation
# a silencieusement mal tourné, plutôt que de le découvrir en Phase de
# validation.
"$HOME/.local/bin/dsoxlab" --version
EOF

# S'assurer que $HOME/.local/bin est dans le PATH par défaut pour toutes
# les sessions, pas seulement celle du provisioning.
cat >> /etc/profile.d/local-bin-path.sh <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
chmod +x /etc/profile.d/local-bin-path.sh

echo "==> 02-uv-dsoxlab: terminé"
