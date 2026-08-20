#!/bin/bash
set -euo pipefail

echo "==> 01-base: mise à jour système et paquets essentiels"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y
apt-get install -y \
  curl \
  wget \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  openssh-server \
  qemu-guest-agent \
  htop \
  vim

# qemu-guest-agent : utile pour l'intégration VMware/VirtualBox (heartbeat,
# infos IP visibles depuis l'hyperviseur hôte)
systemctl enable qemu-guest-agent

echo "==> 01-base: terminé"
