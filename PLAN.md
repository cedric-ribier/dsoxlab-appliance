# Plan — dsoxlab-runtime (image d'exécution OVA)

Ce document reprend le *Release Plan* de Stéphane Robert tel quel sur les
points déjà tranchés, et documente les décisions complémentaires
nécessaires pour passer du plan à une implémentation réelle : choix du
builder Packer, gestion de la contrainte de taille GitHub Releases,
séparation construction/validation liée à l'absence de virtualisation
imbriquée sur le poste de build, et cadence de publication.

Objectif de ce document : pouvoir l'exécuter étape par étape sans
zone d'ombre, du premier commit jusqu'à la publication de la Release.

---

## 1. Décisions d'implémentation (au-delà du plan produit)

### 1.1 Builder Packer unique : `virtualbox-iso`

Un seul artefact source, exporté nativement en OVA — pas de build
`vmware-iso` séparé, pour éviter la dépendance CI à `ovftool`
(propriétaire, compte Broadcom, indisponible sur runners GitHub-hosted
standards).

**Conséquence assumée** : l'OVA VMware n'est pas construite par un
pipeline VMware natif, mais par **import puis re-validation manuelle**
de l'OVA produite par VirtualBox dans VMware Fusion/Workstation. C'est
suffisant car le format OVA (OVF + disque) est un standard neutre, pas
propriétaire à VirtualBox.

### 1.2 Construction vs validation — deux machines, deux rôles

Point critique identifié : le poste de build (le mien, VirtualBox sans
virtualisation imbriquée disponible) peut **construire** l'image sans
restriction — installer Debian, `dsoxlab`, Terraform, Ansible, les
paquets `libvirt`/`qemu-kvm`/`incus` est de l'installation de paquets
classique, aucune dépendance à `/dev/kvm` pendant le build.

Ce même poste ne peut pas **valider** que les labs `vm` fonctionnent
réellement dans l'image produite (ça nécessite la virtualisation
imbriquée, absente ici). D'où deux étapes distinctes et obligatoires,
jamais fusionnées :

| Étape | Où | Quoi |
| --- | --- | --- |
| Build | Poste VirtualBox (le mien) | `packer build` → OVA brute |
| Validation shell | Poste VirtualBox (le mien) | Import OVA, `dsoxlab doctor`, lab `shell` complet |
| Validation vm | Poste VMware Fusion (nested virt confirmée) | Import de la **même** OVA, test KVM/Incus réel |

Les scripts de provisioning Packer (`04-providers.sh`) **installent et
activent au démarrage** les paquets `libvirt`/`qemu-kvm`/`incus`, sans
jamais tenter de démarrer `libvirtd` ni tester `/dev/kvm` *pendant* le
build — pour rester non-bloquants quel que soit le poste de build.

### 1.3 Contrainte de taille (2 Go / fichier GitHub Release)

Absente du plan produit — à traiter explicitement en Phase 1, pas
découverte au moment de la publication :

1. Mesurer la taille réelle de l'OVA après le premier build complet.
2. Si < 2 Go : rien à faire.
3. Si > 2 Go : compression via `ovftool --compress=9` en post-traitement
   avant publication (pas de split multi-fichiers, plus simple côté
   utilisateur final).
4. Si la compression ne suffit toujours pas : réévaluer le contenu
   embarqué (les paquets `libvirt`/`qemu-kvm`/`incus` sont probablement
   le poste le plus lourd) — décision à reporter à Stéphane si ce cas
   se présente, car ça rouvre la question du périmètre MVP.

**Mesure effectuée** sur premier build > 2 Go

1. Compression via `ovftool --compress=9` non concluant
2. Réévaluer le contenu semble être la meilleure voie,
   privilégier un provider me semble une bonne logique, 
   choix à déterminé: `libvirt`/`incus`

### 1.4 Cohérence MVP / Phase 3 — hyperviseurs embarqués

Le plan produit liste `libvirt`/`QEMU`/`Incus` dans le MVP (Phase 1),
mais le contrôle `doctor` de détection de virtualisation imbriquée
n'arrive qu'en Phase 3. Stéphane travaille déjà sur ce contrôle dans
[#78](https://github.com/stephrobert/dsoxlab/issues/78) — pas
d'implémentation de notre côté sur ce point.

Décision d'implémentation retenue ici, en attendant que #78 soit prêt :
les hyperviseurs restent dans le MVP (cohérent avec le plan produit),
mais **aucune Release n'est publiée avant que le contrôle `doctor`
existe et soit intégré** — le MVP peut être construit et testé en
interne dès maintenant, sans attendre #78, mais sa publication publique
est bloquée jusqu'à cette dépendance. Ça évite de distribuer une image
qui expose au risque documenté dans #36 (provisioning qui expire
silencieusement).

### 1.5 Cadence de publication

Tension identifiée entre "republication mensuelle" et "republication
seulement si la base change" (position initiale de Stéphane). Résolution
proposée : **build mensuel automatique (cron), publication conditionnelle**.

- Le pipeline CI tourne chaque mois (date à fixer, ex. 1er du mois).
- Il compare le hash du contenu généré (versions des paquets embarqués)
  à celui de la dernière Release publiée.
- Publication **seulement si différence détectée**, avec incrément de
  version automatique (patch si dépendances runtime, mineur si base OS
  ou hyperviseur).
- Sinon, le run se termine sans publier — traçable dans les logs CI,
  aucun bruit côté Releases GitHub.

---

## 2. Roadmap (reprise du plan produit, phases inchangées)

### Phase 0 — Validation du concept
- Analyse des images existantes (#28, #29) — **déjà couvert** : elles
  ont été construites manuellement, hors critères (pas de Packer/CI, pas
  de SHA256SUMS/attestation) ; elles ont servi à valider la faisabilité
  technique (virtualisation imbriquée confirmée VirtualBox et VMware sur
  mon setup), pas comme base de code à reprendre telle quelle.
- Décision écrite : l'image est un runtime dsoxlab, pas une image de
  labs. **Validé.**

### Phase 1 — MVP
- Format unique : OVA, construit via `virtualbox-iso`, validé par
  import dans VMware.
- Contenu : Debian 12 LTS, dsoxlab, Terraform, Ansible, ansible-runner,
  Incus, libvirt, QEMU (installés/activés au démarrage, non testés au
  build).
- Premier démarrage : `dsoxlab init` (mécanisme de Stéphane, pas
  réimplémenté ici).
- Documentation : README dédié (import VMware/VirtualBox, configuration
  recommandée, public cible, limitations).
- Publication bloquée tant que le contrôle `doctor` (#78) n'est pas
  disponible — voir §1.4.

### Phase 2 — Runtime Qualification
- Mesure réelle (pas estimée) des prérequis matériels sur les 4 cas de
  test listés dans le plan produit (Linux Training shell, Terraform
  Training shell, provider libvirt, provider Incus).

### Phase 3 — Nested Virtualization
- Contrôle `doctor` — porté par #78, pas par ce projet.
- Débloque la publication du MVP une fois disponible (voir §1.4).

### Phase 4 — Formats complémentaires
- qcow2, VHDX, UTM/QEMU aarch64 — hors périmètre de ce document, sujet
  séparé comme indiqué dans le plan produit.

---

## 3. Prochaines étapes concrètes

1. Construire le premier OVA en local (`packer build`) — voir `packer/`.
2. Mesurer sa taille réelle, ajuster la stratégie de compression si
   nécessaire (§1.3).
3. Valider `shell` sur mon poste VirtualBox.
4. Valider `vm` (import de la même OVA) sur mon poste VMware Fusion.
5. Mettre en place le pipeline CI (`.github/workflows/build-release.yml`)
   une fois la validation manuelle concluante.
6. Ne pas publier tant que #78 n'est pas disponible (§1.4).
