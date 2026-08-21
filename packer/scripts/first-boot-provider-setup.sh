#!/bin/bash
# Installation différée des providers de virtualisation (KVM/libvirt,
# Incus), déclenchée au premier démarrage réel de l'appliance — pas
# figée dans l'image, voir PLAN.md §5.
#
# Détection provisoire : flag kernel nested-virt en dur. À remplacer
# par un appel à `dsoxlab doctor` une fois disponible (#78) — proposer
# alors une commande séparée en lecture seule (`doctor --check
# nested-virt`) plutôt que de faire agir doctor lui-même, pour ne pas
# transformer un outil de diagnostic en outil d'installation. Voir
# PLAN.md §5 pour la discussion complète.

set -euo pipefail

LOG_TAG="dsoxlab-provider-setup"
log() { logger -t "$LOG_TAG" "$1"; echo "[$LOG_TAG] $1"; }

detect_nested_virt() {
  local flag_intel="/sys/module/kvm_intel/parameters/nested"
  local flag_amd="/sys/module/kvm_amd/parameters/nested"

  if [ -r "$flag_intel" ] && grep -qi '^[y1]' "$flag_intel"; then
    return 0
  fi
  if [ -r "$flag_amd" ] && grep -qi '^[y1]' "$flag_amd"; then
    return 0
  fi
  return 1
}

if ! detect_nested_virt; then
  log "Virtualisation imbriquée non détectée — providers vm non installés. Labs shell disponibles normalement."
  exit 0
fi

log "Virtualisation imbriquée détectée — installation des providers vm..."

export DEBIAN_FRONTEND=noninteractive

# --- KVM / libvirt ---
apt-get update
apt-get install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virtinst \
  ovmf

usermod -aG libvirt,kvm user
systemctl enable --now libvirtd

echo "  /var/lib/libvirt/images/** rwk," >> /etc/apparmor.d/local/abstractions/libvirt-qemu

# --- Incus (dépôt Zabbly) ---
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc
tee /etc/apt/sources.list.d/zabbly-incus-stable.sources >/dev/null <<EOF
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: $(. /etc/os-release && echo ${VERSION_CODENAME})
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF

apt-get update
apt-get install -y incus incus-client

usermod -aG incus-admin user
systemctl enable --now incus

log "Providers vm installés avec succès."

systemctl disable dsoxlab-provider-setup.service 2>/dev/null || true
