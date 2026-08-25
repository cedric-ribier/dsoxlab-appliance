# Repository layout

*[Version française](REPO-LAYOUT.fr.md)*

Proposed as a subfolder `appliance/` inside
[stephrobert/dsoxlab](https://github.com/stephrobert/dsoxlab), consistent
with how Terraform templates and cloud-init configs already live inside
the engine repository rather than as separate repos per artifact type.

```
dsoxlab/
└── appliance/
    ├── README.md                    # this proposal's entry point (EN)
    ├── README.fr.md                 # (FR)
    ├── PLAN.md                      # architecture, decisions, open questions (EN)
    ├── PLAN.fr.md                   # (FR)
    ├── REPO-LAYOUT.md               # this file (EN)
    ├── REPO-LAYOUT.fr.md            # (FR)
    ├── RELEASE.md                   # build/validate/publish procedure (EN)
    ├── RELEASE.fr.md                # (FR)
    ├── LICENSE                      # Apache License 2.0
    ├── .gitignore
    ├── .github/
    │   └── workflows/
    │       └── build-release.yml    # monthly build, conditional publish
    └── packer/
        ├── dsoxlab-appliance.pkr.hcl  # source + build definition
        ├── variables.pkr.hcl        # version, resources, providers scope
        ├── http/
        │   └── preseed.cfg          # Debian 12 automated install
        └── scripts/
            ├── 01-base.sh                     # system update, base packages, sudo NOPASSWD for build
            ├── 02-uv-dsoxlab.sh               # uv, dsoxlab (installed under /opt/dsoxlab-appliance)
            ├── 03-terraform-ansible.sh        # Terraform (mise), ansible-core, ansible-runner
            ├── 04-providers.sh                # optional build-time providers (scope-controlled, default: none)
            ├── 06-verify.sh                   # sanity checks before cleanup; keyboard fallback
            ├── 05-cleanup.sh                  # final cleanup + writes first-boot scripts/services
            └── first-boot-provider-setup.sh   # deferred KVM/Incus install, copied in by the file provisioner
```

## Notes on structure

- **Numbering doesn't match execution order.** Provisioning runs
  `01 → 02 → 03 → 04 → 06-verify → 05-cleanup` — verification happens
  *before* cleanup deliberately (cleanup locks the build account;
  running verification after that breaks authentication for the rest
  of the build). The filenames were kept as originally numbered rather
  than renamed, to avoid rewriting every reference across scripts and
  docs for a cosmetic fix.
- **`first-boot-provider-setup.sh`** is not run during the build at
  all. It's copied into the image via a Packer `file` provisioner,
  then wired to a `systemd` oneshot unit (created inside
  `05-cleanup.sh`) that only executes on the real first boot of the
  exported appliance.
- **`packer/output/`** (build artifacts) and `*.ova`/`*.log` are
  gitignored — never committed.
- **`.github/workflows/build-release.yml`** requires a self-hosted
  runner with VirtualBox installed (see `PLAN.md` for why GitHub-hosted
  runners aren't viable here) — not yet configured, see open questions
  in `PLAN.md`.

## Alternative considered

A separate repository (`dsoxlab-appliance`) was the initial default
while this was purely a personal exploration; the subfolder placement
was adopted once the proposal matured, for consistency with how
Terraform/cloud-init templates are already organized inside the engine
repo rather than scattered across per-artifact repositories.
