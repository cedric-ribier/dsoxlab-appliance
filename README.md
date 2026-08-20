# dsoxlab-runtime — brouillon de proposition

⚠️ **Ceci est un brouillon de travail**, pas une release ni un dépôt
officiel. Proposé en réponse à
[stephrobert/dsoxlab#91](https://github.com/stephrobert/dsoxlab/issues/91),
en attente d'arbitrage sur plusieurs points avant toute publication ou
intégration.

## Contexte

Image d'exécution OVA embarquant le moteur dsoxlab (Debian, `dsoxlab`,
Terraform, Ansible, `ansible-runner`, libvirt/QEMU, Incus), destinée en
priorité aux utilisateurs Windows/macOS sans environnement Linux natif.
Aucun catalogue de labs embarqué — le choix se fait au premier
démarrage via `dsoxlab init`.

## Où regarder en premier

| Document | Contenu |
| --- | --- |
| [`PLAN.md`](./PLAN.md) | Décisions d'implémentation, roadmap, points résolus depuis le cadrage initial |
| [`REPO-LAYOUT.md`](./REPO-LAYOUT.md) | Structure proposée, question dépôt séparé vs sous-dossier de `dsoxlab` |
| [`RELEASE.md`](./RELEASE.md) | Procédure complète : build local, validation VirtualBox + VMware, publication |
| [`packer/`](./packer) | Définition Packer, scripts de provisioning, workflow CI |

## État actuel

- [x] Définition Packer écrite (`virtualbox-iso`, export OVA natif)
- [x] Scripts de provisioning rédigés et vérifiés syntaxiquement
- [x] Workflow CI écrit (build mensuel, publication conditionnelle)
- [ ] **Pas encore buildé ni testé en conditions réelles** — en attente
      de retour sur les points ouverts avant d'investir du temps de
      build/validation
- [ ] Aucune publication prévue avant la disponibilité du contrôle
      `doctor` de détection de virtualisation imbriquée
      ([stephrobert/dsoxlab#78](https://github.com/stephrobert/dsoxlab/issues/78))

## Points en attente d'arbitrage

Voir la section correspondante dans [`PLAN.md`](./PLAN.md#1-décisions-dimplémentation-au-delà-du-plan-produit) :
hébergement du dépôt final, hébergement du runner CI self-hosted,
cadence exacte de publication.
