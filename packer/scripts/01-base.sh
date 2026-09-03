#!/bin/bash
set -euo pipefail

echo "==> 01-base: mise à jour système et paquets essentiels"

# NOPASSWD pour packer, dès maintenant — 05-cleanup.sh verrouille ce
# compte en toute fin de provisioning (sécurité), mais Packer a encore
# besoin d'élever ses privilèges après ça (shutdown_command final).
# Sans NOPASSWD, ce verrouillage casse systématiquement la dernière
# étape du build.
echo "packer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/packer-nopasswd
chmod 0440 /etc/sudoers.d/packer-nopasswd

export DEBIAN_FRONTEND=noninteractive

# Mise à jour du système et installation des paquets de base
# Update the system and install base packages
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
