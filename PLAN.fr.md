# Plan — dsoxlab-appliance

*[English version](PLAN.md)*

Ce document reflète l'état actuel et validé de la proposition — pas un
journal chronologique de build. Pour l'historique détaillé, bug par
bug, de la façon dont chaque décision a été atteinte, voir l'historique
Git de ce dépôt ; ce fichier expose des conclusions et un raisonnement,
pas le chemin de debug.

## 1. Décision de périmètre

**Image de base shell seul, avec providers installés à la demande au
premier démarrage.** C'était une question ouverte plus tôt dans la
conception (figer KVM/Incus vs. garder l'image minimale) — désormais
tranchée par les faits, pas par préférence :

- L'image de base (Debian 12, `dsoxlab`, Terraform, Ansible,
  `ansible-runner`) tient confortablement sous la limite de 2 Gio des
  Releases GitHub.
- Figer KVM/libvirt/Incus ajoute un coût de maintenance réel et
  permanent (surface CVE, obligation de rebuild à chaque vulnérabilité)
  pour des utilisateurs dont l'hôte ne supportera de toute façon jamais
  la virtualisation imbriquée (Hyper-V actif, WSL2, Apple Silicon) —
  pur gaspillage pour eux.
- Un script de premier démarrage détecte la virtualisation imbriquée en
  direct (flags CPU via `/proc/cpuinfo`, pas un fichier de paramètre de
  module kernel qui peut ne pas encore exister — voir §3) et installe
  KVM/libvirt et Incus seulement quand c'est réellement utilisable.
  Confirmé fonctionnel de bout en bout sur VMware Fusion avec un hôte
  Intel.
- Ça évite aussi le débat "quel provider" : l'appliance supporte à la
  fois `kvm` (utilisé par les labs `vm` de `linux-dsoxlab-training`) et
  `incus`, installés ensemble quand la virtualisation imbriquée est
  disponible, plutôt que d'imposer un choix au moment du build.

## 2. Architecture de build

- **OS de base** : Debian 12.15 (bookworm), installé via preseed
  automatisé depuis le chemin d'archive immuable
  (`cdimage.debian.org/cdimage/archive/12.15.0/...`) — pas `current/`,
  qui suit la dernière stable et casse silencieusement les builds
  quand une nouvelle version majeure de Debian la remplace (constaté
  une fois en cours de développement : bascule bookworm → trixie ayant
  cassé le lien épinglé sans avertissement).
- **Builder** : `virtualbox-iso`, export direct en OVA. Un seul
  artefact de build est importé et validé sur VirtualBox **et** VMware
  Fusion — pas de chemin de build séparé spécifique à VMware, qui
  nécessiterait `ovftool` (propriétaire, compte Broadcom) et
  compliquerait la CI.
- **Outils runtime** : installés sous `/opt/dsoxlab-appliance`, pas dans
  le home d'un utilisateur. Le compte de build (`packer`) est
  entièrement supprimé au premier démarrage réel, avec son home — tout
  ce qui aurait été installé sous `/home/packer` disparaîtrait avec
  lui. `uv`, `mise` et leurs outils installés sont relocalisés via
  `UV_INSTALL_DIR`/`UV_TOOL_DIR`/`UV_TOOL_BIN_DIR`/`MISE_DATA_DIR`.
  L'épinglage de version Terraform vit dans `/etc/mise/config.toml`
  (un vrai emplacement système) plutôt que via `mise use --global`, qui
  écrit dans `~/.config/mise/config.toml` — lié au compte qui a lancé
  la commande, en l'occurrence `packer`, désormais supprimé.
- **Firmware : BIOS legacy, pas UEFI.** Jamais configuré délibérément —
  `virtualbox-iso` retombe par défaut sur le BIOS legacy, et c'est ce
  sur quoi cette appliance a toujours démarré, passé inaperçu jusqu'à
  ce qu'une expérimentation qcow2 ultérieure le révèle explicitement
  (tenter un boot UEFI contre cette appliance ne trouvait aucune
  partition ESP, puisqu'aucune n'a jamais été créée — voir
  `QCOW2-EXPERIMENT.md` sur la branche `dev`). Confirmé fonctionnel sur
  chaque format/hyperviseur validé jusqu'ici (VirtualBox, VMware, et
  sur `dev` : KVM/qcow2 sur trois environnements dont un import natif
  Proxmox). Aucun problème de compatibilité signalé par un testeur.
  Rester délibérément en BIOS legacy : basculer vers UEFI est un vrai
  chantier (partitionnement GPT + ESP FAT32 dans le preseed,
  configuration explicite `loader`/`nv_ram` dans Packer — tenté une
  fois pour l'OVA et abandonné une fois qu'il s'est avéré ne pas être
  nécessaire), pas un simple flag à activer, et aucun besoin concret
  (exigence Secure Boot, politique d'entreprise précise) n'est apparu
  jusqu'ici. À revoir si un vrai besoin apparaît, plutôt que de
  basculer par anticipation.

## 3. Mécanismes de premier démarrage

Tout ce qui doit refléter l'environnement *déployé* plutôt que
l'environnement de *build* passe par des services `systemd` de type
oneshot activés au moment du build mais exécutés seulement au véritable
premier démarrage :

- **`dsoxlab-first-boot-setup.service`** — crée le compte final `user`
  (mot de passe par défaut, changement forcé à la première connexion
  via `chage -d 0`), supprime `packer` et son accès sudo NOPASSWD, et
  corrige le nom d'interface réseau (voir ci-dessous).
- **`dsoxlab-provider-setup.service`** — détecte la virtualisation
  imbriquée via `/proc/cpuinfo` (flags `vmx`/`svm`), pas
  `/sys/module/kvm_intel/parameters/nested` (ce fichier n'existe que
  si le module `kvm_intel` est chargé, ce qui n'est pas le cas sur une
  image shell seul qui n'en a jamais eu besoin — une version antérieure
  de cette détection produisait des faux négatifs sur VMware Fusion
  précisément pour cette raison). Installe KVM/libvirt/Incus seulement
  si détecté. Ne se désactive **pas** sur une détection négative — il
  retente à chaque démarrage jusqu'à réussir une fois, donc activer la
  virtualisation imbriquée après le premier import (étape manuelle sur
  VMware Fusion/VirtualBox) fonctionne quand même, sans rebuild.
- **Portabilité réseau** — l'installeur Debian fige le nom d'interface
  détecté *au moment du build* dans `/etc/network/interfaces` (ex.
  `enp0s3` sous VirtualBox). Une fois exportée et importée sur un autre
  hyperviseur, la topologie PCI virtuelle diffère et l'interface change
  de nom (ex. `ens32`/`enp2s0` sous VMware Fusion) — la config figée ne
  matche plus rien, DHCP ne démarre jamais. Corrigé en détectant le
  vrai nom d'interface au premier démarrage et en régénérant
  `/etc/network/interfaces` en conséquence, en gardant l'approche
  `ifupdown` traditionnelle (cohérente avec ce qui est déjà documenté
  pour un public débutant) plutôt que de basculer vers
  `systemd-networkd` (tenté d'abord ; casse la résolution DNS en cours
  de build si appliqué au mauvais moment, et ajoute une dépendance dont
  l'approche traditionnelle n'a pas besoin).

## 4. Pourquoi ces correctifs précis, pas d'autres

Quelques décisions à signaler explicitement, pas évidentes à la
première tentative :

- **Disposition clavier** : preseeder directement
  `keyboard-configuration/layoutcode` et `console-setup/layoutcode` ne
  fonctionne *pas* de façon fiable — les deux sont documentées comme
  "for internal use" dans la référence officielle des templates
  debconf de Debian, dérivées en interne depuis la question publique
  `keyboard-configuration/xkb-keymap` plutôt que destinées à être
  réglées directement. Le preseed fonctionnel n'utilise que
  `xkb-keymap` + `modelcode` ; `06-verify.sh` porte aussi un filet de
  rattrapage au moment du build qui corrige directement
  `/etc/default/keyboard` si l'installeur ignore quand même le preseed
  sur certains environnements.
- **`environment_vars` silencieusement ignoré** : le provisioner
  `shell` de Packer n'injecte `environment_vars` que si
  `execute_command` référence explicitement `{{ .Vars }}`. Un
  `execute_command` personnalisé (nécessaire ici pour le passage de mot
  de passe via `sudo -S`) qui omet cette référence calcule les
  variables en interne mais ne les transmet jamais réellement au
  script — aucune erreur, juste un échec silencieux. C'était la cause
  racine de toute une soirée de symptômes "le scope `providers` n'est
  pas respecté". Documenté en amont :
  [hashicorp/packer#12687](https://github.com/hashicorp/packer/issues/12687).

## 5. CI et publication

### Cadence
Tentative de build automatique mensuelle ; publication seulement si le
contenu du build a réellement changé depuis la dernière Release
publiée (diff sur un hash de contenu) — résout la tension entre
"publier selon un calendrier fixe" et "republier seulement si la base
change" (un cadrage plus étroit de la même question posé plus tôt).

### Runner
`virtualbox-iso` nécessite une vraie installation VirtualBox. GitHub
ne supporte pas officiellement la virtualisation imbriquée sur les
runners hébergés — leur propre documentation la qualifie explicitement
d'expérimentale, sans garantie de stabilité. Ce n'est pas une
limitation contournable pour un projet qui valorise la reproductibilité ;
un runner self-hosted est la seule option fiable identifiée.
**Question ouverte** : qui l'héberge (voir ci-dessous).

### Taille
Confirmé : l'image de base shell seul mesure nettement sous la limite
de 2 Gio par fichier des Releases GitHub. Aucune étape de compression
n'a été nécessaire une fois le bon périmètre retenu (shell seul,
providers différés) — une tentative antérieure de
`ovftool --compress=9` sur un build avec providers embarqués a produit
un fichier *plus gros*, pas plus petit (l'export VMDK stream-optimized
natif de VirtualBox est déjà proche de l'optimal pour ce contenu ;
recompresser a ajouté de l'overhead de manifeste/réempaquetage sans
rien récupérer, puisque les blocs supprimés par `rm` ne sont pas mis à
zéro sauf passage dédié avant export).

### Posture de sécurité CI
Scannée avec [Plumber](https://github.com/getplumber/plumber) (scanner
de conformité CI/CD open source) — score **A, 100/100**, 21/21
contrôles réussis, aucun constat à quelque niveau de sévérité que ce
soit. Ce contrôle est indépendant de la question du runner self-hosted
ci-dessous (Plumber valide le fichier de workflow et les réglages du
dépôt, pas l'exécution réelle du build) — il peut tourner, et a
tourné, avant même qu'un runner existe.

Trois constats corrigés pour atteindre ce score, tous dans
`.github/workflows/build-release.yml` :
- La branche `main` n'avait aucune règle de protection — ajoutée
  (bloque force-push et suppression ; pas de revue obligatoire,
  approprié pour un dépôt à mainteneur unique à ce stade).
- L'étape de publication utilisait une action tierce
  (`softprops/action-gh-release@v2`), non épinglée par SHA de commit
  et hors de la liste d'origines autorisées. Remplacée par un appel
  direct à `gh release create` — retire complètement une dépendance
  tierce plutôt que de simplement l'épingler, et correspond à la même
  commande déjà utilisée dans la procédure manuelle documentée dans
  `RELEASE.md`.

Rapport committé sous `plumber-report.txt`/`plumber-findings.csv`,
pour que quiconque relit cette proposition puisse vérifier de façon
indépendante plutôt que de croire le score sur parole.

**Pas encore fait** : intégrer Plumber directement dans le workflow CI
comme contrôle bloquant (échec du build sous un seuil de score) —
actuellement un re-scan manuel occasionnel. À ajouter une fois le
runner (ci-dessous) réglé, pour que les régressions de score soient
attrapées automatiquement plutôt que de dépendre de se souvenir de
relancer le scan.

## 6. Questions ouvertes

Points nécessitant l'avis de Stéphane avant toute fusion éventuelle,
listés par ordre de blocage :

1. **Hébergement du runner CI.** Le self-hosted est requis (§5).
   L'auteur peut en proposer un, mais c'est une dépendance à une
   infrastructure personnelle — mérite une décision explicite pour un
   projet communautaire plutôt qu'un défaut que personne n'a choisi.
2. **Coût de maintenance de la documentation bilingue.** Ce dépôt suit
   déjà la convention propre à dsoxlab (README + PLAN + REPO-LAYOUT +
   RELEASE racine, tous en EN + FR). Vaut le coup de nommer que c'est
   en soi un coût récurrent, pas gratuit — cohérent avec l'argument
   même qui a mis ce sujet en pause.
3. **Licence** : proposée en Apache License 2.0, alignée sur le
   fichier `LICENSE` actuel de
   [stephrobert/dsoxlab](https://github.com/stephrobert/dsoxlab) (un
   écart a été remarqué entre la page GitHub vivante — Apache 2.0 — et
   une ancienne page du paquet PyPI — CC BY 4.0 — probablement un
   instantané figé d'une release antérieure ; la source vivante GitHub
   a été retenue comme faisant foi).
4. **Validation indépendante par un tiers.** Tout ce qui précède n'est
   validé que sur les propres machines de l'auteur (Mac Intel,
   VirtualBox + VMware Fusion). Pas encore de test par quelqu'un
   construisant de zéro sur une autre machine.
