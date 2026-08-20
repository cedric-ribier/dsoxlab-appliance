#!/bin/bash
set -euo pipefail

echo "==> 06-verify: vérification finale avant export"

FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  [OK] $desc"
  else
    echo "  [ÉCHEC] $desc"
    FAIL=1
  fi
}

check "dsoxlab installé"    sudo -u packer bash -c 'export PATH="$HOME/.local/bin:$PATH"; dsoxlab --version'
check "terraform installé"  sudo -u packer bash -c 'export PATH="$HOME/.local/bin:$PATH"; eval "$(mise activate bash)"; terraform version'
check "ansible installé"    sudo -u packer bash -c 'export PATH="$HOME/.local/bin:$PATH"; ansible --version'
check "ansible-runner installé" sudo -u packer bash -c 'export PATH="$HOME/.local/bin:$PATH"; ansible-runner --version'
check "libvirtd activé (boot)"  systemctl is-enabled libvirtd
check "incus activé (boot)"     systemctl is-enabled incus
check "aucun catalogue embarqué (~ vide de dépôts git)" bash -c '[ -z "$(find /home/packer -maxdepth 2 -iname ".git" 2>/dev/null)" ]'

if [ "$FAIL" -ne 0 ]; then
  echo "==> 06-verify: ÉCHEC — build interrompu, voir détails ci-dessus"
  exit 1
fi

echo "==> 06-verify: tous les contrôles passent"
