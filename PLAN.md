# Plan — dsoxlab-appliance

*[Version française](PLAN.fr.md)*

This document reflects the current, validated state of the proposal —
not a chronological build log. For the detailed bug-by-bug history of
how each decision was reached, see the git history of this repository;
this file states conclusions and reasoning, not the debugging path.

## 1. Scope decision

**Shell-only base image, with providers installed on demand at first
boot.** This was an open question earlier in the design (bake in
KVM/Incus vs. keep the image minimal); it's now settled by evidence,
not by preference:

- The base image (Debian 12, `dsoxlab`, Terraform, Ansible,
  `ansible-runner`) stays comfortably under the GitHub Release 2 GiB
  limit.
- Baking in KVM/libvirt/Incus adds real, permanent maintenance cost
  (CVE surface, rebuild-on-vulnerability obligation) for users whose
  host will never support nested virtualization anyway (Hyper-V
  active, WSL2, Apple Silicon) — pure waste for them.
- A first-boot script detects nested virtualization live (CPU flags
  via `/proc/cpuinfo`, not a kernel module parameter file that may not
  exist yet — see §3) and installs KVM/libvirt and Incus only when
  it's actually usable. Confirmed working end-to-end on VMware Fusion
  with an Intel host.
- This also sidesteps the "which provider" debate: the appliance
  supports both `kvm` (used by `linux-dsoxlab-training`'s `vm` labs)
  and `incus`, installed together when nested virt is available,
  rather than forcing a choice at build time.

## 2. Build architecture

- **Base OS**: Debian 12.15 (bookworm), installed via automated
  preseed from the immutable archive path
  (`cdimage.debian.org/cdimage/archive/12.15.0/...`) — not `current/`,
  which tracks whatever is the latest stable release and silently
  breaks builds when a new Debian major version supersedes it (this
  happened once during development: bookworm → trixie switch broke
  the pinned URL without warning).
- **Builder**: `virtualbox-iso`, exporting directly to OVA. A single
  build artifact is imported and validated on both VirtualBox and
  VMware Fusion — no separate VMware-specific build path, which would
  require `ovftool` (proprietary, Broadcom account) and complicate CI.
- **Runtime tools**: installed under `/opt/dsoxlab-appliance`, not under
  any user's home directory. The build-time account (`packer`) is
  deleted entirely on first real boot, along with its home — anything
  installed under `/home/packer` would be destroyed with it. `uv`,
  `mise`, and their installed tools are relocated via
  `UV_INSTALL_DIR`/`UV_TOOL_DIR`/`UV_TOOL_BIN_DIR`/`MISE_DATA_DIR`.
  Terraform's version pin lives in `/etc/mise/config.toml` (a genuine
  system-wide location) rather than `mise use --global`, which writes
  to `~/.config/mise/config.toml` — tied to whichever account ran the
  command, which was `packer`, now deleted.
- **Firmware: BIOS legacy, not UEFI.** Never configured deliberately —
  `virtualbox-iso` defaults to BIOS legacy, and that's what this
  appliance has always booted as, unnoticed until a later qcow2
  experiment surfaced it explicitly (attempting UEFI boot against this
  appliance failed to find any ESP partition, since none was ever
  created — see `QCOW2-EXPERIMENT.md` on the `dev` branch). Confirmed
  working across every format/hypervisor validated so far (VirtualBox,
  VMware, and on `dev`: KVM/qcow2 across three environments including
  native Proxmox import). No compatibility issue reported by any
  tester. Staying on BIOS legacy deliberately: switching to UEFI is a
  real undertaking (GPT partitioning + FAT32 ESP in the preseed,
  explicit `loader`/`nv_ram` configuration in Packer — attempted once
  for the OVA and abandoned when it turned out not to be needed), not
  a flag to flip, and no concrete requirement for it (Secure Boot
  enforcement, specific enterprise policy) has surfaced yet. Revisit
  if a real need appears rather than switching preemptively.

## 3. First-boot mechanisms

Everything that must reflect the *deployed* environment rather than
the *build* environment happens via `systemd` oneshot services enabled
at build time but only executed on the real first boot:

- **`dsoxlab-first-boot-setup.service`** — creates the final `user`
  account (default password, forced change on first login via
  `chage -d 0`), deletes `packer` and its NOPASSWD sudo grant, and
  fixes network interface naming (see below).
- **`dsoxlab-provider-setup.service`** — detects nested virtualization
  via `/proc/cpuinfo` (`vmx`/`svm` flags), not
  `/sys/module/kvm_intel/parameters/nested` (that file only exists
  once the `kvm_intel` module is loaded, which it isn't on a
  shell-only image that's never needed it — an earlier version of this
  detection produced false negatives on VMware Fusion for exactly this
  reason). Installs KVM/libvirt/Incus only if detected. Does **not**
  disable itself on a negative detection — it retries on every boot
  until it succeeds once, so enabling nested virtualization after
  first import (a manual step on VMware Fusion/VirtualBox) still
  works without a rebuild.
- **Network portability** — the Debian installer bakes the network
  interface name detected *at build time* into
  `/etc/network/interfaces` (e.g. `enp0s3` under VirtualBox). Once
  exported and imported into a different hypervisor, the virtual PCI
  topology differs and the interface gets a different name (e.g.
  `ens32`/`enp2s0` under VMware Fusion) — the hardcoded config matches
  nothing, DHCP never starts. Fixed by detecting the actual interface
  name at first boot and regenerating `/etc/network/interfaces`
  accordingly, keeping the traditional `ifupdown` approach (consistent
  with what's already documented for a beginner audience) rather than
  switching to `systemd-networkd` (tried first; broke DNS resolution
  mid-build when applied at build time instead of first boot, and
  added a dependency the traditional approach doesn't need).

## 4. Why these specific fixes, not others

A few decisions worth flagging explicitly, since they weren't obvious
on the first attempt:

- **Keyboard layout**: preseeding `keyboard-configuration/layoutcode`
  and `console-setup/layoutcode` directly does *not* work reliably —
  both are documented as "for internal use" in Debian's own debconf
  template reference, derived internally from the public
  `keyboard-configuration/xkb-keymap` question rather than meant to be
  set directly. The working preseed uses only `xkb-keymap` +
  `modelcode`; `06-verify.sh` also carries a build-time fallback that
  corrects `/etc/default/keyboard` directly if the installer still
  ignores the preseed for some environments.
- **`environment_vars` silently ignored**: Packer's `shell` provisioner
  only injects `environment_vars` when `execute_command` explicitly
  references `{{ .Vars }}`. A custom `execute_command` (needed here for
  `sudo -S` password piping) that omits this reference computes the
  variables internally but never actually passes them to the script —
  no error, just silent failure. This was the root cause of an entire
  evening's worth of "the `providers` scope isn't respected" symptoms.
  Documented upstream: [hashicorp/packer#12687](https://github.com/hashicorp/packer/issues/12687).

## 5. CI and publication

### Cadence
Monthly automated build attempt; publication only if the build's
content actually changed since the last published Release (diff on a
content hash) — resolves the tension between "publish on a fixed
schedule" and "only republish when the base changes" (an earlier,
narrower framing of the same question).

### Runner
`virtualbox-iso` requires an actual VirtualBox installation. GitHub
does not officially support nested virtualization on hosted runners —
their own documentation explicitly disclaims it as experimental with
no stability guarantee. This is not a workaround-able limitation for a
project that values reproducibility; a self-hosted runner is the only
reliable option identified. **Open question**: who hosts it (see
below).

### Size
Confirmed: shell-only base measures well under GitHub's 2 GiB
per-file Release limit. No compression step was needed once the
correct scope (shell-only, providers deferred) was settled — an
earlier attempt at `ovftool --compress=9` on a providers-included
build produced a *larger* file, not smaller (VirtualBox's own
stream-optimized VMDK export is already close to optimal for that
content; recompressing added manifest/repackaging overhead without
reclaiming anything, since `rm`-deleted blocks aren't zeroed unless a
dedicated pass does it before export).

### CI security posture
Scanned with [Plumber](https://github.com/getplumber/plumber) (open
source CI/CD compliance scanner) — score **A, 100/100**, 21/21
controls passing, zero findings at any severity. This check is
independent of the self-hosted runner question below (Plumber
validates the workflow file and repository settings, not the actual
build execution) — it can, and did, run before a runner exists.

Three findings fixed to reach this score, all in
`.github/workflows/build-release.yml`:
- Branch `main` had no protection rule — added (blocks force-push and
  deletion; no required review, appropriate for a single-maintainer
  repo at this stage).
- The publish step used a third-party action
  (`softprops/action-gh-release@v2`), unpinned by commit SHA and
  outside the authorized-source allowlist. Replaced with a direct
  `gh release create` call — removes a third-party dependency
  entirely rather than just pinning it, and matches the same command
  already used in the manual procedure documented in `RELEASE.md`.

Report committed at `plumber-report.txt`/`plumber-findings.csv`, for
anyone reviewing this proposal to verify independently rather than
take the score on faith.

**Not yet done**: wiring Plumber into the CI workflow itself as a
gating check (fail the build below a score threshold) — currently a
manual, occasional re-run. Worth adding once the runner (below) is
settled, so score regressions get caught automatically rather than
relying on remembering to re-scan.

## 6. Open questions

Points that need Stéphane's input before this could move toward being
merged, listed by how much they block everything else:

1. **CI runner ownership.** Self-hosted is required (§5). The author
   can offer one, but that's a dependency on personal infrastructure —
   worth an explicit decision for a community project rather than a
   default nobody chose.
2. **Bilingual documentation maintenance cost.** This repository
   already follows dsoxlab's own convention (root README + PLAN +
   REPO-LAYOUT + RELEASE all ship EN + FR). Worth naming that this is
   itself a recurring cost, not free — consistent with the very
   argument that paused this whole topic.
3. **License**: proposed as Apache License 2.0, matching
   [stephrobert/dsoxlab](https://github.com/stephrobert/dsoxlab)'s
   current `LICENSE` file (a discrepancy was noticed between GitHub's
   live page — Apache 2.0 — and an older PyPI package page — CC BY
   4.0 — likely a stale snapshot from an earlier release; GitHub's
   live source was treated as authoritative).
4. **Third-party independent validation — partially resolved.** An
   external tester built this appliance from source on Windows 11 and
   found a real bug (`.gitattributes`/CRLF, see §4 and
   `CONTRIBUTORS.md`), leading to v0.1.1. That's one confirmed
   from-scratch build by someone other than the author, on a platform
   (Windows) the author can't test directly. Still open: validation on
   more platforms/configurations than this one instance, and by more
   than one person.
