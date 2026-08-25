# Structure du dépôt

*[English version](REPO-LAYOUT.md)*

Proposée comme sous-dossier `appliance/` à l'intérieur de
[stephrobert/dsoxlab](https://github.com/stephrobert/dsoxlab), cohérent
avec la façon dont les templates Terraform et les configs cloud-init
vivent déjà dans le dépôt du moteur plutôt que comme dépôts séparés par
type d'artefact.

```
dsoxlab/
└── appliance/
    ├── README.md                    # point d'entrée de cette proposition (EN)
    ├── README.fr.md                 # (FR)
    ├── PLAN.md                      # architecture, décisions, questions ouvertes (EN)
    ├── PLAN.fr.md                   # (FR)
    ├── REPO-LAYOUT.md               # ce fichier (EN)
    ├── REPO-LAYOUT.fr.md            # (FR)
    ├── RELEASE.md                   # procédure build/validation/publication (EN)
    ├── RELEASE.fr.md                # (FR)
    ├── LICENSE                      # Apache License 2.0
    ├── .gitignore
    ├── .github/
    │   └── workflows/
    │       └── build-release.yml    # build mensuel, publication conditionnelle
    └── packer/
        ├── dsoxlab-appliance.pkr.hcl  # définition source + build
        ├── variables.pkr.hcl        # version, ressources, scope providers
        ├── http/
        │   └── preseed.cfg          # installation automatisée Debian 12
        └── scripts/
            ├── 01-base.sh                     # mise à jour système, paquets de base, sudo NOPASSWD pour le build
            ├── 02-uv-dsoxlab.sh               # uv, dsoxlab (installés sous /opt/dsoxlab-appliance)
            ├── 03-terraform-ansible.sh        # Terraform (mise), ansible-core, ansible-runner
            ├── 04-providers.sh                # providers optionnels au build (scope contrôlé, défaut : none)
            ├── 06-verify.sh                   # contrôles avant nettoyage ; filet de rattrapage clavier
            ├── 05-cleanup.sh                  # nettoyage final + écrit les scripts/services de premier démarrage
            └── first-boot-provider-setup.sh   # installation différée KVM/Incus, copié par le file provisioner
```

## Notes sur la structure

- **La numérotation ne correspond pas à l'ordre d'exécution.** Le
  provisioning s'exécute `01 → 02 → 03 → 04 → 06-verify → 05-cleanup` —
  la vérification se fait délibérément *avant* le nettoyage (le
  nettoyage verrouille le compte de build ; exécuter la vérification
  après casserait l'authentification pour le reste du build). Les noms
  de fichiers ont été gardés tels que numérotés à l'origine plutôt que
  renommés, pour éviter de réécrire chaque référence à travers scripts
  et docs pour un correctif cosmétique.
- **`first-boot-provider-setup.sh`** ne s'exécute pas du tout pendant
  le build. Il est copié dans l'image via un `file` provisioner
  Packer, puis câblé à une unité `systemd` de type oneshot (créée dans
  `05-cleanup.sh`) qui ne s'exécute qu'au véritable premier démarrage
  de l'appliance exportée.
- **`packer/output/`** (artefacts de build) et `*.ova`/`*.log` sont
  dans `.gitignore` — jamais committés.
- **`.github/workflows/build-release.yml`** nécessite un runner
  self-hosted avec VirtualBox installé (voir `PLAN.md` pour pourquoi
  les runners GitHub-hosted ne sont pas viables ici) — pas encore
  configuré, voir les questions ouvertes dans `PLAN.md`.

## Alternative envisagée

Un dépôt séparé (`dsoxlab-appliance`) était le choix par défaut initial
tant que ceci restait une exploration personnelle ; le placement en
sous-dossier a été adopté une fois la proposition mûrie, par cohérence
avec la façon dont les templates Terraform/cloud-init sont déjà
organisés dans le dépôt du moteur plutôt qu'éparpillés entre dépôts
par type d'artefact.
