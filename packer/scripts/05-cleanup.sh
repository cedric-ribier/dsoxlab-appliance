#!/bin/bash
set -euo pipefail

echo "==> 05-cleanup: nettoyage avant export"

export DEBIAN_FRONTEND=noninteractive

# Purge du cache et des listes apt
# Purge the apt cache and package lists
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

# Dépose le script de providers pour son exécution au premier démarrage réel
# Stage the provider script for execution on the real first boot
mv /tmp/first-boot-provider-setup.sh /usr/local/sbin/dsoxlab-provider-setup.sh
chmod +x /usr/local/sbin/dsoxlab-provider-setup.sh

# Purge des logs et fichiers temporaires du build
# Purge build-time logs and temp files
journalctl --rotate || true
journalctl --vacuum-time=1s || true
find /var/log -type f ! -path '/var/log/journal/*' -exec truncate -s 0 {} +
find /tmp -mindepth 1 -delete
find /var/tmp -mindepth 1 -delete

# Réinitialise l'identifiant machine (unique par VM déployée)
# Reset the machine ID (unique per deployed VM)
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Régénère les clés d'hôte SSH au premier démarrage plutôt que de les partager
# Regenerate SSH host keys on first boot instead of sharing them
rm -f /etc/ssh/ssh_host_*
cat > /etc/systemd/system/regenerate-ssh-host-keys.service <<'EOF'
[Unit]
Description=Régénère les clés d'hôte SSH au premier démarrage
Before=ssh.service
ConditionPathExists=!/etc/ssh/ssh_host_rsa_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
ExecStartPost=/usr/bin/systemctl stop ssh.service
ExecStartPost=/usr/bin/systemctl start ssh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable regenerate-ssh-host-keys.service

# Efface l'historique shell du build
# Clear the build's shell history
rm -f /home/packer/.bash_history /root/.bash_history

# Script exécuté au premier démarrage réel : crée le compte utilisateur
# final et retire les accès de build
# Runs on the real first boot: creates the final user account and
# removes build access
cat > /usr/local/sbin/dsoxlab-first-boot-setup.sh <<'SETUP'
#!/bin/bash
set -euo pipefail

# --- Réseau portable entre hyperviseurs ---
# Adaptation automatique de l'interface réseau
IFACE=$(ip -o link show \
  | awk -F': ' '$2 != "lo" {print $2}' \
  | grep '^en' \
  | head -n1)

if [ -n "$IFACE" ]; then
  cat >/etc/network/interfaces <<EOF
# Interface détectée automatiquement au premier démarrage
# DSOXLab Runtime
# Configuration générée automatiquement au premier démarrage
# afin d'adapter la VM à l'hyperviseur utilisé.

auto lo
iface lo inet loopback

allow-hotplug $IFACE
iface $IFACE inet dhcp
EOF

  systemctl restart networking || true
fi
# Crée le compte utilisateur final, mot de passe à changer à la première connexion
# Create the final user account, password must be changed on first login
if ! id user >/dev/null 2>&1; then
  useradd -m -s /bin/bash user
  echo "user:MotDePasse" | chpasswd
  chage -d 0 user
fi

# Rejoint les groupes sudo/virtualisation déjà présents sur l'image
# Join the sudo/virtualization groups already present on the image
usermod -aG sudo user
getent group libvirt      >/dev/null 2>&1 && usermod -aG libvirt user || true
getent group kvm          >/dev/null 2>&1 && usermod -aG kvm user || true
getent group incus         >/dev/null 2>&1 && usermod -aG incus user || true
getent group incus-admin  >/dev/null 2>&1 && usermod -aG incus-admin user || true

chown -R user:user /opt/dsoxlab-appliance

# Retire le compte et les privilèges de build
# Remove the build account and its privileges
rm -f /etc/sudoers.d/packer-nopasswd
userdel -r packer 2>/dev/null || true

systemctl disable dsoxlab-first-boot-setup.service
SETUP
chmod +x /usr/local/sbin/dsoxlab-first-boot-setup.sh

# Unité qui déclenche la création du compte final au premier démarrage
# Unit that triggers final-account creation on first boot
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

# Unité qui déclenche l'installation différée des providers vm
# Unit that triggers the deferred vm-providers install
cat > /etc/systemd/system/dsoxlab-provider-setup.service <<'EOF'
[Unit]
Description=Installe les providers vm (KVM/libvirt, Incus) si la virtualisation imbriquée est disponible
After=dsoxlab-first-boot-setup.service
Wants=dsoxlab-first-boot-setup.service
ConditionPathExists=/usr/local/sbin/dsoxlab-provider-setup.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dsoxlab-provider-setup.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable dsoxlab-provider-setup.service

# Remplit puis efface un fichier pour mettre à zéro l'espace libre — réduit
# la taille de l'export une fois compressé
# Fill then delete a file to zero out free space — shrinks the export
# once compressed
echo "==> Mise à zéro de l'espace libre avant export (peut prendre plusieurs minutes)"
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo "==> 05-cleanup: terminé"
