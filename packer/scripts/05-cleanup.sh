#!/bin/bash
set -euo pipefail

echo "==> 05-cleanup: nettoyage avant export"

export DEBIAN_FRONTEND=noninteractive

apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

mv /tmp/first-boot-provider-setup.sh /usr/local/sbin/dsoxlab-provider-setup.sh
chmod +x /usr/local/sbin/dsoxlab-provider-setup.sh

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

useradd -m -s /bin/bash user
echo "user:MotDePasse" | chpasswd
chage -d 0 user

usermod -aG sudo user
getent group libvirt      >/dev/null 2>&1 && usermod -aG libvirt user || true
getent group kvm          >/dev/null 2>&1 && usermod -aG kvm user || true
getent group incus         >/dev/null 2>&1 && usermod -aG incus user || true
getent group incus-admin  >/dev/null 2>&1 && usermod -aG incus-admin user || true

chown -R user:user /opt/dsoxlab-appliance

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

cat > /etc/systemd/system/dsoxlab-provider-setup.service <<'EOF'
[Unit]
Description=Installe les providers vm (KVM/libvirt, Incus) si la virtualisation imbriquée est disponible
After=dsoxlab-first-boot-setup.service
Requires=dsoxlab-first-boot-setup.service
ConditionPathExists=/usr/local/sbin/dsoxlab-provider-setup.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dsoxlab-provider-setup.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable dsoxlab-provider-setup.service

echo "==> Mise à zéro de l'espace libre avant export (peut prendre plusieurs minutes)"
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo "==> 05-cleanup: terminé"
