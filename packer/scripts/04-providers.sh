#!/bin/bash
set -euo pipefail

echo "==> 04-providers: installation KVM/libvirt/Incus"
echo "    (installation et activation au démarrage uniquement —"
echo "     PAS de test /dev/kvm ni de démarrage de service ici, voir"
echo "     PLAN.md §1.2 : le poste de build peut ne pas avoir la"
echo "     virtualisation imbriquée disponible)"

export DEBIAN_FRONTEND=noninteractive

# --- KVM / libvirt ---
apt-get install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  bridge-utils \
  virtinst \
  ovmf

usermod -aG libvirt,kvm packer

systemctl enable libvirtd

# --- Incus (dépôt officiel Zabbly — extrepo ne référence pas Incus,
# contrairement à ce qu'on avait supposé initialement) ---
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

usermod -aG incus-admin packer
systemctl enable incus

# Abstraction AppArmor pour les backing-files partagés — correctif
# identifié empiriquement sur ce même type d'usage (labs vm avec image
# de base partagée), appliqué ici en préventif directement dans l'image
# plutôt qu'en post-provisioning manuel.
echo "  /var/lib/libvirt/images/** rwk," >> /etc/apparmor.d/local/abstractions/libvirt-qemu

echo "==> 04-providers: terminé (non testé — validation requise sur hôte nested-virt, voir PLAN.md §1.2)"
