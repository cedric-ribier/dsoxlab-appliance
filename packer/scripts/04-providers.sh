#!/bin/bash
set -euo pipefail

echo "==> 04-providers: installation providers de virtualisation"
echo "    (installation et activation au démarrage uniquement —"
echo "     PAS de test /dev/kvm ni de démarrage de service ici, voir"
echo "     PLAN.md §1.2 : le poste de build peut ne pas avoir la"
echo "     virtualisation imbriquée disponible)"

PROVIDERS="${DSOXLAB_PROVIDERS:-all}"
echo "    Scope demandé : ${PROVIDERS}"

export DEBIAN_FRONTEND=noninteractive

# Installation de KVM/libvirt si le scope le demande
# Install KVM/libvirt if the scope requests it
if [ "$PROVIDERS" = "all" ] || [ "$PROVIDERS" = "kvm" ]; then
  echo "==> Installation KVM/libvirt"
  apt-get install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virtinst \
    ovmf

  usermod -aG libvirt,kvm packer
  systemctl enable libvirtd

  echo "  /var/lib/libvirt/images/** rwk," >> /etc/apparmor.d/local/abstractions/libvirt-qemu
else
  echo "==> KVM/libvirt exclu du scope (DSOXLAB_PROVIDERS=$PROVIDERS)"
fi

# Installation d'Incus si le scope le demande (dépôt Zabbly)
# Install Incus if the scope requests it (Zabbly repo)
if [ "$PROVIDERS" = "all" ] || [ "$PROVIDERS" = "incus" ]; then
  echo "==> Installation Incus"
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
else
  echo "==> Incus exclu du scope (DSOXLAB_PROVIDERS=$PROVIDERS)"
fi

echo "==> 04-providers: terminé (non testé — validation requise sur hôte nested-virt, voir PLAN.md §1.2)"
