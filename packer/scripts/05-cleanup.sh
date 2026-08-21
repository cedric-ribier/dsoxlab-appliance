#!/bin/bash
set -euo pipefail

echo "==> 05-cleanup: nettoyage avant export"

export DEBIAN_FRONTEND=noninteractive

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

find /var/log -type f -exec truncate -s 0 {} \;
rm -rf /tmp/* /var/tmp/*

truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

rm -f /etc/ssh/ssh_host_*
cat > /etc/systemd/system/regenerate-ssh-host-keys.service <<'EOF'
[Unit]
Description=Régénère les clés d'hôte SSH au premier démarrage
Before=ssh.service
ConditionPathExists=!/etc/ssh/ssh_host_rsa_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
ExecStartPost=/usr/bin/systemctl restart ssh.service

[Install]
WantedBy=multi-user.target
EOF
systemctl enable regenerate-ssh-host-keys.service

rm -f /home/packer/.bash_history /root/.bash_history
passwd -l packer

cat > /etc/systemd/system/harden-sudo-first-boot.service <<'EOF'
[Unit]
Description=Retire le sudo NOPASSWD de build au premier démarrage réel
Before=multi-user.target
ConditionPathExists=/etc/sudoers.d/packer-nopasswd

[Service]
Type=oneshot
ExecStart=/usr/bin/rm -f /etc/sudoers.d/packer-nopasswd

[Install]
WantedBy=multi-user.target
EOF
systemctl enable harden-sudo-first-boot.service

echo "==> 05-cleanup: terminé"
