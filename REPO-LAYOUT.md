# Structure du dépôt

Proposition de structure, à intégrer soit comme dépôt séparé
`stephrobert/dsoxlab-runtime`, soit comme sous-dossier `runtime/` dans
`stephrobert/dsoxlab` — à trancher avec Stéphane selon la logique déjà
établie pour les templates Terraform/cloud-init (déjà packagés dans
`dsoxlab` lui-même).

```
dsoxlab-runtime/
├── README.md                          # public : présentation, liens de téléchargement, import VMware/VirtualBox
├── PLAN.md                            # ce document — décisions d'implémentation et roadmap
├── REPO-LAYOUT.md                     # ce fichier
├── CHANGELOG.md                       # une entrée par Release publiée (pas par build tenté)
├── .github/
│   └── workflows/
│       └── build-release.yml          # CI : build mensuel conditionnel + publication
└── packer/
    ├── dsoxlab-runtime.pkr.hcl        # source + build
    ├── variables.pkr.hcl              # version, checksums ISO, ressources VM
    ├── http/
    │   └── preseed.cfg                # installation Debian 12 automatisée
    ├── scripts/
    │   ├── 01-base.sh                 # mises à jour, paquets système
    │   ├── 02-uv-dsoxlab.sh           # uv, dsoxlab
    │   ├── 03-terraform-ansible.sh    # Terraform (mise), ansible-core, ansible-runner
    │   ├── 04-providers.sh            # libvirt/QEMU/Incus — installés, non testés au build
    │   ├── 05-cleanup.sh              # nettoyage : logs, cache, machine-id, clés SSH, identifiants de build
    │   └── 06-verify.sh               # sanity check final, échoue le build si un outil manque
    └── output/                        # généré par packer build — jamais commité (.gitignore)
```

## Fichiers à ajouter séparément

- **`.gitignore`** : exclure `packer/output/`, `*.ova`, `crash.log`
  (Packer), et tout fichier `.pkrvars.hcl` local contenant des valeurs
  spécifiques à une machine de build.
- **`README.md`** public : rédigé une fois le premier OVA validé sur les
  deux hyperviseurs — pas avant, pour ne pas documenter une procédure
  d'import non encore vérifiée.
- **`CHANGELOG.md`** : une ligne par Release **publiée**, pas par
  exécution du cron mensuel (voir PLAN.md §1.5 — la plupart des runs
  mensuels ne publieront rien si rien n'a changé).
