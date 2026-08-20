#!/bin/bash
set -euo pipefail

echo "==> 05-cleanup: nettoyage avant export"

export DEBIAN_FRONTEND=noninteractive

# Purge cache apt et paquets non nécessaires à l'exécution
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

# Logs de build — inutiles dans l'image distribuée, et potentiellement
# verbeux (sorties complètes de uv/ansible/terraform pendant le
# provisioning)
find /var/log -type f -exec truncate -s 0 {} \;
rm -rf /tmp/* /var/tmp/*

# machine-id — DOIT être régénéré au premier démarrage réel, sinon
# toutes les VMs importées à partir de cette même OVA partagent le même
# ID et ça casse potentiellement DHCP/systemd-networkd côté utilisateurs
# finaux qui importent l'image plusieurs fois.
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Clés d'hôte SSH — à régénérer au premier démarrage, jamais distribuées
# figées dans une image publique (risque de sécurité direct : n'importe
# qui pourrait déchiffrer/usurper une session SSH vers n'importe quelle
# instance de cette image).
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

# Historique shell et identifiants de build — l'utilisateur "packer" et
# son mot de passe faible (défini dans le preseed) ne doivent pas
# survivre dans l'image distribuée.
rm -f /home/packer/.bash_history /root/.bash_history
passwd -l packer   # verrouille le mot de passe, le compte reste utilisable en clé SSH uniquement si besoin futur

echo "==> 05-cleanup: terminé"
