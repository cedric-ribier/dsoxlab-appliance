# Procédure de release

*[English version](RELEASE.md)*

Procédure manuelle — aucun runner CI n'est encore configuré (voir
`PLAN.md`, questions ouvertes). À suivre intégralement pour tout
nouveau build ; sauter la validation double-hyperviseur (étape 4) est
exactement ce qui a laissé passer plusieurs bugs lors du développement,
invisibles avec un seul hyperviseur testé.

## Versions validées

La procédure a été validée avec :

| Composant | Debian netinst | VirtualBox | Packer | Git | VMware Fusion | VMware Workstation |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Version(s) | 12.15.0 | 7.2.14 - 7.2.16 | 1.15.4 - 1.16 | 2.50.1 - 2.51.0 | 13.6.2 | 26.0.0 (25388281) |

D'autres versions peuvent fonctionner mais n'ont pas été vérifiées.

## 1. Prérequis

Prérequis matériels

Configuration minimale recommandée :

| Configuration | CPU | RAM | DISQUE | Internet |
|:--:|:--:|:--:|:--:|:--:|
|minimal|4 coeurs|8 Go|50 Go|✅|
|recommandée|8 coeurs|16 Go|100 Go|✅|

### macOS

```bash
brew install git
brew install hashicorp/tap/packer
brew install --cask virtualbox
```

macOS bloquera probablement l'extension kernel de VirtualBox à la
première installation — autoriser une fois via *Réglages Système →
Confidentialité et sécurité*.

### Linux (Debian/Ubuntu)

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y packer virtualbox git
```

Aucun conflit d'hyperviseur connu sur Linux — le module kernel de
VirtualBox (`vboxdrv`) cohabite normalement avec KVM si les deux sont
installés, tant qu'ils ne tentent pas de faire tourner une VM
exactement au même moment sur le même CPU.

Ajouter son utilisateur au groupe Virtualbox :

```bash
sudo usermod -aG vboxusers $USER
```

### Windows

> **Conflit Hyper-V/WSL2 — à lire avant d'installer quoi que ce soit.**
> VirtualBox et la virtualisation basée sur Hyper-V (qui inclut WSL2,
> et souvent la sécurité basée sur la virtualisation / l'intégrité de
> la mémoire de Windows 11, parfois activée par défaut) se disputent
> l'accès exclusif à VT-x. Faire tourner les deux sur la même machine
> fait retomber VirtualBox dans un mode de compatibilité lent et
> instable (la communauté rapporte des plantages fréquents même sur
> des versions récentes de VirtualBox) — pas un cas limite rare, un
> vrai conflit d'architecture.
>
> **Avant de builder sous Windows** : désactiver Hyper-V, WSL2, et la
> sécurité basée sur la virtualisation (*Activer ou désactiver des
> fonctionnalités Windows* → décocher *Hyper-V*, *Plateforme de
> machine virtuelle*, *Sous-système Windows pour Linux* ; vérifier
> aussi *Sécurité Windows → Sécurité de l'appareil → Isolation du
> noyau* et désactiver *Intégrité de la mémoire* si présent), puis
> redémarrer.

Installer [Git for Windows](https://git-scm.com/download/win) (fournit
**Git Bash** — un vrai shell bash sans dépendance à Hyper-V,
contrairement à WSL2) et exécuter le reste de cette procédure depuis
Git Bash, pour que les mêmes commandes que macOS/Linux s'appliquent
tout du long dans ce document.

```bash
# Dans Git Bash, après avoir installé Git for Windows :
winget install HashiCorp.Packer
winget install Oracle.VirtualBox
```

(ou télécharger les deux installeurs manuellement depuis
[developer.hashicorp.com/packer](https://developer.hashicorp.com/packer/install)
et [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) si
`winget` n'est pas disponible.)

## 2. Clonage du dépôt

```bash
git clone https://github.com/cedric-ribier/dsoxlab-appliance.git
```

## 3. Build

```bash
cd dsoxlab-appliance/packer
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

Temps observé :

- SSD NVMe + 8 vCPU : ~15 min
- SSD SATA + 4 vCPU : ~25 min
- HDD : non testé

## 4. Vérifier l'artefact avant de l'importer où que ce soit

```bash
ls -la output/dsoxlab-appliance-X.Y.Z/*.ova
sha256sum -c output/dsoxlab-appliance-X.Y.Z/SHA256SUMS
```
Variante windows pour le SHA256SUM

```bash
(cd /D/Documents/Github/dsoxlab-appliance/packer/output/dsoxlab-appliance-0.1.0 && sha256sum -c SHA256SUMS)
```
> Sous Windows (Git Bash), un chemin absolu explicite s'est avéré nécessaire — confirmé par un testeur externe, un simple `cd` relatif + `sha256sum -c` ne fonctionnait pas de façon fiable dans son environnement.

> Sur macOS, `sha256sum` n'est pas installé par défaut (l'userland BSD
> utilise `shasum` à la place) — soit `brew install coreutils`, soit
> remplacer `shasum -a 256 -c` à chaque `sha256sum -c` de ce document.
> Natif sous Linux et dans Git Bash sous Windows, pas de substitution
> nécessaire là.

Confirmer que la taille est sous 2 Gio (`2147483648` octets) — limite
stricte par fichier des Releases GitHub.

## 5. Valider sur les deux hyperviseurs — n'en sauter aucun

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
ping -c 4 deb.debian.org        # Connexion et résolution DNS
dsoxlab --version
dsoxlab doctor
ls /etc/ssh/ssh_host_*           # Les clés doivent avoir été régénérées.
systemctl status ssh --no-pager  # enable et running
```

### VMware Fusion/Workstation
Transférer la même `.ova` (pas de build séparé). Avant le premier
démarrage, dans les réglages de la VM (VM éteinte) : activer *"Enable
hypervisor applications in this virtual machine"* si on teste le
chemin providers en virtualisation imbriquée — étape manuelle que
VMware Fusion/Workstation ne fait pas par défaut à l'import, et le script
d'installation différée ne fait correctement rien sans ça (retente à
chaque démarrage suivant si activé plus tard, pas besoin de rebuild).

Mêmes vérifications que ci-dessus, plus, si la virtualisation imbriquée
est activée :
```bash
sudo journalctl -u dsoxlab-provider-setup.service --no-pager
dpkg -l | grep -E "incus|qemu-kvm|libvirt"
```

## 6. Tag et publication

### Vérification de l'état Git

Avant toute release :

```bash
git status
```
Le dépôt doit être propre :

```text
nothing to commit, working tree clean
``` 

Les fichiers de logs générés durant les builds doivent rester locaux et
ne jamais être versionnés.

Exemple:

```bash
git status
```
Ne doit faire apparaître:

```text
build-*.log
``` 

avant un tag de release.


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

## 7. Vérification post-publication

```bash
gh release download vX.Y.Z -p "SHA256SUMS"
gh release download vX.Y.Z -p "*.ova"
sha256sum -c SHA256SUMS
```
Importer l'OVA téléchargée une seconde fois afin de vérifier que
l'artefact publié est bien celui validé localement.

## Critères d'acceptation d'une release

Une release est considérée comme valide si :

- le build Packer se termine sans erreur ;
- les sommes SHA256 sont correctes ;
- l'OVA est importable dans VirtualBox ;
- l'OVA est importable dans VMware ;
- le clavier est configuré correctement ;
- le réseau obtient une adresse DHCP ;
- l'accès Internet fonctionne ;
- les clés SSH sont régénérées ;
- `dsoxlab doctor` ne remonte aucune anomalie bloquante.

## Limites connues à ce stade

- Aucun build indépendant n'a encore été réalisé par quelqu'un d'autre
  que l'auteur du dépôt.
- Aucune attestation de provenance de build n'est encore attachée
  (prévue une fois la CI en place —
  `actions/attest-build-provenance` nécessite GitHub Actions, ce qui
  nécessite de trancher d'abord la question du runner).
