# dsoxlab-appliance

*[Version française](README.fr.md)*

> **Status: proposal, validated proof-of-concept — not merged, not published.**
> Written in response to [stephrobert/dsoxlab#91](https://github.com/stephrobert/dsoxlab/issues/91).
> The topic itself is currently paused upstream (recurring maintenance cost
> of an image supply chain outweighs the benefit until the project's
> contract is frozen — see #76/#77 — and provisioning is recoverable — see
> #107). This repository exists to keep a working, tested answer ready for
> when the topic resumes, and to give something concrete to review now
> rather than a plan on paper.

## What this is

A build definition (Packer + Debian 12) for a runtime appliance —
`dsoxlab`, Terraform, Ansible, `ansible-runner` — targeting Windows and
macOS users without a native Linux environment. No lab catalog is
embedded: the catalog is chosen on first boot via `dsoxlab catalog add`.

KVM/libvirt and Incus are **not baked into the image**. They install
themselves automatically on first real boot, only if the host actually
supports nested virtualization — detected live, not assumed. This keeps
the base image small (comfortably under GitHub's 2 GiB release-asset
limit) and keeps the security-sensitive hypervisor stack always
freshly patched rather than frozen at build time.

## What's validated

- Builds cleanly from a Debian 12.15 netinst via Packer/VirtualBox,
  producing both a `.ova` (VirtualBox/VMware) and a `.qcow2` (KVM,
  libvirt, Proxmox) from a single build.
- Boots and completes first-run setup on VirtualBox, VMware Fusion,
  and real KVM (tested via raw QEMU and native Proxmox import) —
  three hypervisors validated, one build.
- Network adapts automatically to whichever hypervisor imported it
  (interface name is detected at first boot, not hardcoded from the
  build machine — each hypervisor names NICs differently).
- KVM/libvirt and Incus install themselves on first boot when nested
  virtualization is available — confirmed on VMware Fusion and on a
  real KVM host (Proxmox, including native `qm importdisk` import);
  do **not** attempt anything (and don't waste space or expose extra
  attack surface) when it isn't. See
  [`QCOW2-EXPERIMENT.md`](QCOW2-EXPERIMENT.md) for the full validation
  log, including a false-positive detection pitfall specific to
  unaccelerated QEMU testing.
- French/AZERTY locale works end-to-end (build-time author's own
  keyboard); the underlying mechanism generalizes to any preseed
  locale/layout.
- Final image size below the 2 GiB GitHub Release limit.
- **Independent, from-scratch build by an external tester on Windows
  11** — found a real bug (`.gitattributes`/CRLF line endings, see
  [`CONTRIBUTORS.md`](CONTRIBUTORS.md)) that the author's own macOS
  testing had never surfaced, leading to v0.1.1.

## What isn't validated yet

- CI-driven builds — no self-hosted runner is set up yet (see
  [`PLAN.md`](PLAN.md) for why GitHub-hosted runners aren't a real
  option here).
- Broader third-party validation — one external tester so far, one
  platform (Windows 11). Not yet a real compatibility matrix across
  multiple people/configurations.

## Where to look

| Document | What's in it |
| --- | --- |
| [`PLAN.md`](PLAN.md) | Architecture, decisions made and why, open questions |
| [`REPO-LAYOUT.md`](REPO-LAYOUT.md) | Repository structure |
| [`RELEASE.md`](RELEASE.md) | Build, validate, and publish, step by step |
| [`packer/`](packer/) | The actual Packer definition, provisioning scripts, CI workflow |

## License

Apache License 2.0, matching [stephrobert/dsoxlab](https://github.com/stephrobert/dsoxlab).

## Open questions for review

See [`PLAN.md`](PLAN.md#open-questions) for the full list — the two
that matter most before anything here could be merged:

1. **Who hosts the CI runner?** Building with `virtualbox-iso` needs a
   machine with VirtualBox installed. GitHub-hosted runners don't
   officially support nested virtualization (GitHub's own docs call
   any use "experimental, at your own risk"). Self-hosting is the only
   reliable option found; the author can offer one, but that's a
   dependency on personal infrastructure worth discussing openly for
   a community project.
2. **Bilingual documentation maintenance.** Following dsoxlab's own
   convention (every root README ships EN + FR) has a recurring
   translation-sync cost of its own — worth naming rather than
   assuming silently.
