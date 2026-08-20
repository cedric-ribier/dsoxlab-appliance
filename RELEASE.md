# Procédure — push initial et première release

À exécuter dans l'ordre. Ne pas sauter les étapes de validation
manuelle (4 et 5) avant la mise en place de la CI — c'est elles qui
donnent confiance dans le pipeline avant de l'automatiser.

## 1. Initialiser le dépôt

```bash
cd dsoxlab-runtime
git init
cat > .gitignore <<'EOF'
packer/output/
*.ova
crash.log
*.pkrvars.hcl
EOF

git add .
git commit -m "Initial: plan, structure Packer, CI"
```

Créer le dépôt sur GitHub (organisation `stephrobert` si intégré comme
dépôt séparé, à confirmer avec lui — voir REPO-LAYOUT.md) :

```bash
gh repo create stephrobert/dsoxlab-runtime --public --source=. --remote=origin
git push -u origin main
```

## 2. Build local — première validation avant tout push CI

```bash
cd packer
packer init .
packer validate -var "image_version=0.1.0-dev" dsoxlab-runtime.pkr.hcl
packer build -var "image_version=0.1.0-dev" dsoxlab-runtime.pkr.hcl
```

Durée attendue : 20-40 minutes selon la vitesse de l'hôte et du réseau
(téléchargement ISO Debian inclus la première fois).

## 3. Vérifier la taille avant d'aller plus loin

```bash
ls -lh output/dsoxlab-runtime-0.1.0-dev/*.ova
```

Si > 2 Go, appliquer la compression avant de continuer (voir PLAN.md
§1.3) :

```bash
ovftool --compress=9 \
  output/dsoxlab-runtime-0.1.0-dev/dsoxlab-runtime-0.1.0-dev.ova \
  output/dsoxlab-runtime-0.1.0-dev/dsoxlab-runtime-0.1.0-dev-compressed.ova
```

## 4. Validation shell — sur le poste de build (VirtualBox)

```bash
VBoxManage import output/dsoxlab-runtime-0.1.0-dev/*.ova --vsys 0 --vmname dsoxlab-runtime-test
VBoxManage startvm dsoxlab-runtime-test --type headless
```

Une fois démarrée (attendre le boot complet, ~1-2 min) :

```bash
ssh packer@<ip-attribuée>
dsoxlab --version
dsoxlab doctor
```

Puis un lab `shell` complet de bout en bout, pas juste une vérification
de présence des outils :

```bash
git clone https://github.com/stephrobert/linux-dsoxlab-training.git
cd linux-dsoxlab-training
dsoxlab run <un-lab-shell-existant>
```

Nettoyer ensuite :

```bash
VBoxManage controlvm dsoxlab-runtime-test poweroff
VBoxManage unregistervm dsoxlab-runtime-test --delete
```

## 5. Validation vm — sur le poste VMware Fusion

Transférer le fichier `.ova` (même artefact, pas de rebuild) vers le
poste VMware, puis :

- **Fusion** : *File → Import*, sélectionner l'OVA.
- Avant premier démarrage, dans les réglages de la VM : cocher
  *"Enable hypervisor applications in this virtual machine"* (nested
  virt / VT-x-EPT — nom exact de l'option selon version de Fusion).

Une fois démarrée :

```bash
ssh packer@<ip-attribuée>
cat /sys/module/kvm_intel/parameters/nested   # doit répondre Y
```

Puis un test `provision` réel sur un lab `vm` du catalogue, pour
confirmer que KVM/Incus fonctionnent effectivement dans ces conditions
(pas seulement que les paquets sont présents) :

```bash
dsoxlab provision
```

**Si ce test échoue** : ne pas publier. Retourner à `packer/scripts/04-providers.sh`,
ajuster, reconstruire, revalider. C'est précisément le scénario que la
séparation build/validation (PLAN.md §1.2) est censée éviter de laisser
passer.

## 6. Une fois les deux validations manuelles concluantes

Committer les ajustements éventuels, puis déclencher la CI :

```bash
git add .
git commit -m "Ajustements post-validation manuelle"
git push

git tag v0.1.0
git push origin v0.1.0
```

Le tag déclenche `build-release.yml` en mode `push` (publication
immédiate, sans attendre le cron mensuel ni la logique de diff).

## 7. Vérifier la Release publiée

```bash
gh release view v0.1.0
gh release download v0.1.0 -p "SHA256SUMS"
gh release download v0.1.0 -p "*.ova"
sha256sum -c SHA256SUMS
```

Vérifier aussi l'attestation de provenance (nécessite `gh` récent avec
le sous-comportement `attestation`) :

```bash
gh attestation verify dsoxlab-runtime-0.1.0.ova --owner stephrobert
```

## 8. Rappel — ne pas publier avant #78

Cette procédure documente comment publier **techniquement**. La
décision de publier une Release **publique** (visible/annoncée) reste
conditionnée à la disponibilité du contrôle `doctor` de détection de
virtualisation imbriquée (#78), comme convenu dans PLAN.md §1.4. Les
tags `v0.1.0-rc*` peuvent servir de jalons internes avant ça, sans
communication publique.
