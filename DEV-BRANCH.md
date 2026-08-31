# `dev` branch — what it's for

Not a staging area for a specific set of planned changes — a standing
space to experiment without ever touching `main` directly, so that a
sudden need (e.g. a CVE forcing a base-distro change) doesn't mean
prototyping in production. `main` stays the only branch meant to be
reviewed or presented; anything here is unvalidated by definition.

Ideas parked here get their own short-lived branch off `dev`
(`dev/<topic>`), merged into `dev` once they produce something
coherent — not committed directly to `dev` as a growing, mixed pile.

Current parked ideas (not started unless noted, not committed to any
timeline):
- **qcow2 output** — validated as bootable and provider-functional
  (real KVM host, fresh first boot, virt-host-validate PASS). See
  [`QCOW2-EXPERIMENT.md`](QCOW2-EXPERIMENT.md) for the full log,
  including bugs found along the way and what's still needed before
  this could move toward `main`. Not merged yet.
- Vagrant box output — revisits the tradeoff Stéphane raised in a
  private message, which was set aside on UX grounds without hard
  data; worth prototyping to get an actual size/friction comparison
  rather than continuing to guess.
- VHDX output — needs a real Hyper-V host to validate; VirtualBox and
  Hyper-V can't coexist on the same machine (see `RELEASE.md`), so
  this can't be tested on the current build machine as-is.
- Alternate base distro — the heaviest change of the four; a project
  identity question (single-distro vs distro-agnostic appliance), not
  just a build variant. Deliberately kept separate from the other
  three.
