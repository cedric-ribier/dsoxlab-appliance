# dsoxlab-appliance

*[English version](README.md)*

> **Statut : proposition, preuve de concept validée — non fusionnée,
> non publiée.** Rédigé en réponse à
> [stephrobert/dsoxlab#91](https://github.com/stephrobert/dsoxlab/issues/91).
> Le sujet lui-même est actuellement en pause côté officiel (le coût
> récurrent de maintenance d'une chaîne d'approvisionnement d'images
> l'emporte sur le bénéfice tant que le contrat du projet n'est pas
> gelé — voir #76/#77 — et que le provisionnement n'est pas
> récupérable — voir #107). Ce dépôt garde une réponse fonctionnelle
> et testée prête pour le jour où le sujet reprendra, et donne
> quelque chose de concret à examiner dès maintenant plutôt qu'un
> plan sur papier.

## Ce que c'est

Une définition de build (Packer + Debian 12) pour une appliance
d'exécution — `dsoxlab`, Terraform, Ansible, `ansible-runner` —
destinée aux utilisateurs Windows et macOS sans environnement Linux
natif. Aucun catalogue de labs n'est embarqué : le choix se fait au
premier démarrage via `dsoxlab catalog add`.

KVM/libvirt et Incus **ne sont pas figés dans l'image**. Ils s'installent
automatiquement au premier démarrage réel, uniquement si l'hôte
supporte réellement la virtualisation imbriquée — détecté en direct,
pas supposé. Ça garde l'image de base légère (confortablement sous la
limite de 2 Gio des Releases GitHub) et maintient la pile hyperviseur
(sensible côté sécurité) toujours à jour plutôt que figée au moment du
build.

## Ce qui est validé

- Build propre depuis un netinst Debian 12.15 via Packer/VirtualBox,
  produisant à la fois une `.ova` (VirtualBox/VMware) et un `.qcow2`
  (KVM, libvirt, Proxmox) depuis un seul build.
- Démarre et termine la configuration de premier démarrage sur
  VirtualBox, VMware Fusion, et un vrai KVM (testé via QEMU brut et
  import natif Proxmox) — trois hyperviseurs validés, un seul build.
- Le réseau s'adapte automatiquement à l'hyperviseur qui l'a importée
  (nom d'interface détecté au premier démarrage, pas figé depuis la
  machine de build — chaque hyperviseur nomme les cartes réseau
  différemment).
- KVM/libvirt et Incus s'installent au premier démarrage quand la
  virtualisation imbriquée est disponible — confirmé sur VMware Fusion
  et sur un vrai hôte KVM (Proxmox, y compris un import natif via `qm
  importdisk`) ; ne tentent **rien** (et ne gaspillent ni espace ni
  surface d'attaque) quand elle ne l'est pas. Voir
  [`QCOW2-EXPERIMENT.md`](QCOW2-EXPERIMENT.md) pour le journal complet
  de validation, y compris un piège de détection en faux positif
  spécifique aux tests QEMU non accélérés.
- Locale française/AZERTY fonctionnelle de bout en bout (clavier de
  l'auteur pendant le build) ; le mécanisme sous-jacent se généralise à
  n'importe quelle locale/disposition de preseed.
- Taille finale de l'image sous la limite de 2 Gio des Releases GitHub.
- **Build indépendant, depuis zéro, par un testeur externe sous
  Windows 11** — a trouvé un vrai bug (fins de ligne
  `.gitattributes`/CRLF, voir [`CONTRIBUTORS.md`](CONTRIBUTORS.md))
  que les propres tests macOS de l'auteur n'avaient jamais fait
  remonter, menant à la v0.1.1.

## Ce qui n'est pas encore validé

- Builds pilotés par CI — aucun runner self-hosted n'est encore en
  place (voir [`PLAN.md`](PLAN.md) pour pourquoi les runners
  GitHub-hosted ne sont pas une vraie option ici).
- Validation tierce plus large — un seul testeur externe jusqu'ici,
  une seule plateforme (Windows 11). Pas encore une vraie matrice de
  compatibilité sur plusieurs personnes/configurations.

## Où regarder

| Document | Contenu |
| --- | --- |
| [`PLAN.md`](PLAN.md) | Architecture, décisions prises et pourquoi, questions ouvertes |
| [`REPO-LAYOUT.md`](REPO-LAYOUT.md) | Structure du dépôt |
| [`RELEASE.md`](RELEASE.md) | Build, validation et publication, pas à pas |
| [`packer/`](packer/) | La définition Packer elle-même, scripts de provisioning, workflow CI |

## Licence

Apache License 2.0, alignée sur
[stephrobert/dsoxlab](https://github.com/stephrobert/dsoxlab).

## Questions ouvertes pour relecture

Voir [`PLAN.md`](PLAN.md#questions-ouvertes) pour la liste complète —
les deux qui comptent le plus avant toute fusion éventuelle :

1. **Qui héberge le runner CI ?** Construire via `virtualbox-iso`
   nécessite une machine avec VirtualBox installé. Les runners
   GitHub-hosted ne supportent pas officiellement la virtualisation
   imbriquée (la doc GitHub qualifie tout usage d'"expérimental, à vos
   risques"). Le self-hosted est la seule option fiable trouvée ;
   l'auteur peut en proposer un, mais c'est une dépendance à une
   infrastructure personnelle qui mérite d'être discutée ouvertement
   pour un projet communautaire.
2. **Maintenance de la documentation bilingue.** Suivre la convention
   propre à dsoxlab (chaque README racine en EN + FR) a un coût
   récurrent de synchronisation des traductions — à nommer plutôt qu'à
   supposer silencieusement.
