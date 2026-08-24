#!/bin/bash
set -euo pipefail

echo "==> 06-verify: vérification finale avant export"

if ! grep -q '^XKBLAYOUT="fr"' /etc/default/keyboard; then
  echo " [INFO] Correction de la configuration clavier vers FR"

  sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="fr"/' /etc/default/keyboard

  if ! grep -q '^XKBLAYOUT=' /etc/default/keyboard; then
    echo 'XKBLAYOUT="fr"' >> /etc/default/keyboard
  fi
fi

PROVIDERS="${DSOXLAB_PROVIDERS:-all}"
export PATH="/opt/dsoxlab-runtime/bin:/opt/dsoxlab-runtime/mise/shims:$PATH"

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

check "dsoxlab installé"        dsoxlab --version
check "terraform installé"      terraform version
check "ansible installé"        ansible --version
check "ansible-runner installé" ansible-runner --version
check "clavier FR configuré" grep -q '^XKBLAYOUT="fr"' /etc/default/keyboard

if [ "$PROVIDERS" = "all" ] || [ "$PROVIDERS" = "kvm" ]; then
  check "libvirtd activé (boot)"  systemctl is-enabled libvirtd
fi
if [ "$PROVIDERS" = "all" ] || [ "$PROVIDERS" = "incus" ]; then
  check "incus activé (boot)"     systemctl is-enabled incus
fi

check "aucun catalogue embarqué (~ vide de dépôts git)" bash -c '[ -z "$(find /home/packer -maxdepth 2 -iname ".git" 2>/dev/null)" ]'

if [ "$FAIL" -ne 0 ]; then
  echo "==> 06-verify: ÉCHEC — build interrompu, voir détails ci-dessus"
  exit 1
fi

echo "==> 06-verify: tous les contrôles passent (scope: ${PROVIDERS})"
