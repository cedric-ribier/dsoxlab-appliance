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

# --- Compte utilisateur final ---
# "packer" n'a servi qu'à la construction de l'image (UID de build,
# mot de passe faible connu publiquement via ce dépôt) — ce ne doit
# jamais être le compte de connexion de l'appliance distribuée. Un
# compte générique "user" est créé et "packer" est entièrement
# supprimé, MAIS uniquement au premier démarrage réel — jamais pendant
# le build : Packer reste connecté en SSH sous "packer" jusqu'à son
# propre shutdown_command final, le supprimer maintenant casserait le
# build (même classe de bug que le verrouillage de mot de passe
# rencontré plus tôt ce soir).
cat > /usr/local/sbin/dsoxlab-first-boot-setup.sh <<'SETUP'
#!/bin/bash
set -euo pipefail

useradd -m -s /bin/bash user
echo "user:MotDePasse" | chpasswd
chage -d 0 user

usermod -aG sudo user
getent group libvirt      >/dev/null 2>&1 && usermod -aG libvirt user || true
getent group kvm          >/dev/null 2>&1 && usermod -aG kvm user || true
getent group incus-admin  >/dev/null 2>&1 && usermod -aG incus-admin user || true

rm -f /etc/sudoers.d/packer-nopasswd
userdel -r packer 2>/dev/null || true

systemctl disable dsoxlab-first-boot-setup.service
SETUP
chmod +x /usr/local/sbin/dsoxlab-first-boot-setup.sh

cat > /etc/systemd/system/dsoxlab-first-boot-setup.service <<'EOF'
[Unit]
Description=Crée le compte utilisateur final et retire les accès de build (premier démarrage uniquement)
Before=multi-user.target
ConditionPathExists=/etc/sudoers.d/packer-nopasswd

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dsoxlab-first-boot-setup.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable dsoxlab-first-boot-setup.service

# --- Providers vm en installation différée (piste "premier démarrage",
# voir PLAN.md §5) — copié par le file provisioner vers /tmp, déplacé
# ici vers son emplacement final. Dépend explicitement du compte "user"
# déjà créé (After=), sinon l'ordre entre deux services oneshot n'est
# pas garanti et usermod échouerait si "user" n'existe pas encore.
mv /tmp/first-boot-provider-setup.sh /usr/local/sbin/dsoxlab-provider-setup.sh
chmod +x /usr/local/sbin/dsoxlab-provider-setup.sh

cat > /etc/systemd/system/dsoxlab-provider-setup.service <<'EOF'
[Unit]
Description=Installe les providers vm (KVM/libvirt, Incus) si la virtualisation imbriquée est disponible
After=dsoxlab-first-boot-setup.service
Requires=dsoxlab-first-boot-setup.service
ConditionPathExists=/usr/local/sbin/dsoxlab-provider-setup.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dsoxlab-provider-setup.sh
ExecStartPost=/bin/systemctl disable dsoxlab-provider-setup.service

[Install]
WantedBy=multi-user.target
EOF
systemctl enable dsoxlab-provider-setup.service

echo "==> 05-cleanup: terminé"
