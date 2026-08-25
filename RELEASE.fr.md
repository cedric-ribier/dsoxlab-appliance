# Procédure de release

*[English version](RELEASE.md)*

Procédure manuelle — aucun runner CI n'est encore configuré (voir
`PLAN.md`, questions ouvertes). À suivre intégralement pour tout
nouveau build ; sauter la validation double-hyperviseur (étape 4) est
exactement ce qui a laissé passer plusieurs bugs lors du développement,
invisibles avec un seul hyperviseur testé.

## 1. Prérequis

```bash
brew install hashicorp/tap/packer
brew install --cask virtualbox
```

macOS bloquera probablement l'extension kernel de VirtualBox à la
première installation — autoriser une fois via *Réglages Système →
Confidentialité et sécurité*.

## 2. Build

```bash
cd appliance/packer
packer init .
packer validate -var "image_version=X.Y.Z" -var "providers=none" .
packer build -force -on-error=ask -var "image_version=X.Y.Z" -var "providers=none" . 2>&1 | tee build-X.Y.Z.log
```

`providers=none` est le défaut recommandé (base shell seul, les
providers s'installent eux-mêmes au premier démarrage si l'hôte
supporte la virtualisation imbriquée — voir `PLAN.md` §1).
`providers=all` fige KVM/libvirt/Incus au moment du build, utile pour
tester isolément ce chemin de code mais pas le défaut de release.

Compter 15-25 minutes. Le build télécharge l'ISO netinst Debian au
premier lancement (mis en cache ensuite) et exécute toute la chaîne de
provisioning.

## 3. Vérifier l'artefact avant de l'importer où que ce soit

```bash
ls -la output/dsoxlab-appliance-X.Y.Z/*.ova
sha256sum -c output/dsoxlab-appliance-X.Y.Z/SHA256SUMS
```

Confirmer que la taille est sous 2 Gio (`2147483648` octets) — limite
stricte par fichier des Releases GitHub.

## 4. Valider sur les deux hyperviseurs — n'en sauter aucun

C'est l'étape qui attrape réellement les bugs spécifiques à un
hyperviseur (nommage d'interface réseau, détection nested-virt) qu'un
test sur une seule cible ne révèle pas.

### VirtualBox
```bash
VBoxManage import output/dsoxlab-appliance-X.Y.Z/dsoxlab-appliance-X.Y.Z.ova --vsys 0 --vmname dsoxlab-appliance-test
VBoxManage startvm dsoxlab-appliance-test --type gui
```
Connexion en `user` / `MotDePasse` au premier démarrage — changement de
mot de passe forcé immédiatement. Confirmer :
```bash
cat /etc/default/keyboard        # XKBLAYOUT="fr" (ou la locale preseedée)
ip a                             # l'interface doit avoir une vraie adresse DHCP
dsoxlab --version
dsoxlab doctor
```

### VMware Fusion
Transférer la même `.ova` (pas de build séparé). Avant le premier
démarrage, dans les réglages de la VM (VM éteinte) : activer *"Enable
hypervisor applications in this virtual machine"* si on teste le
chemin providers en virtualisation imbriquée — étape manuelle que
VMware Fusion ne fait pas par défaut à l'import, et le script
d'installation différée ne fait correctement rien sans ça (retente à
chaque démarrage suivant si activé plus tard, pas besoin de rebuild).

Mêmes vérifications que ci-dessus, plus, si la virtualisation imbriquée
est activée :
```bash
sudo journalctl -u dsoxlab-provider-setup.service --no-pager
dpkg -l | grep -E "incus|qemu-kvm|libvirt"
```

## 5. Tag et publication

```bash
git add .
git commit -m "..."
git tag vX.Y.Z
git push origin main --tags
```

Publication manuelle (pas de runner CI configuré pour l'instant) :
```bash
gh release create vX.Y.Z \
  output/dsoxlab-appliance-X.Y.Z/dsoxlab-appliance-X.Y.Z.ova \
  output/dsoxlab-appliance-X.Y.Z/SHA256SUMS \
  --title "vX.Y.Z" \
  --notes "..."
```

## 6. Vérification post-publication

```bash
gh release download vX.Y.Z -p "SHA256SUMS"
gh release download vX.Y.Z -p "*.ova"
sha256sum -c SHA256SUMS
```

## Limites connues à ce stade

- Aucun build indépendant n'a encore été réalisé par quelqu'un d'autre
  que l'auteur du dépôt.
- Aucune attestation de provenance de build n'est encore attachée
  (prévue une fois la CI en place —
  `actions/attest-build-provenance` nécessite GitHub Actions, ce qui
  nécessite de trancher d'abord la question du runner).
