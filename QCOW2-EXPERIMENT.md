# qcow2 export — experiment log

Second format from Stéphane's original list in
[dsoxlab#91](https://github.com/stephrobert/dsoxlab/issues/91) (after
OVA), targeting native KVM/libvirt/Proxmox usage without going through
a hypervisor-specific import step. This document states conclusions
and reasoning, not a raw chronological transcript — see `dev` branch
commit history for the step-by-step.

## Status: validated as bootable and provider-functional. Not yet
## wired into `main` or the release pipeline.

## Approach

Reused the existing `virtualbox-iso` build entirely — no second Packer
source, no `qemu` builder. The OVA's VMDK (already produced by the
validated build) is extracted and converted with `qemu-img`, as an
additional `post-processor "shell-local"` block in the same
`dsoxlab-appliance.pkr.hcl`. One `packer build` invocation produces
both artifacts side by side; nothing about the provisioning scripts,
first-boot services, or validated OVA behavior changes.

New build-machine prerequisite: `qemu-img` (`brew install qemu` on
macOS; ships as part of the `qemu` package, not separate).

```hcl
post-processor "shell-local" {
  inline = [
    "mkdir -p output/dsoxlab-appliance-${var.image_version}/qcow2-extract",
    "tar -xf output/dsoxlab-appliance-${var.image_version}/dsoxlab-appliance-${var.image_version}.ova -C output/dsoxlab-appliance-${var.image_version}/qcow2-extract",
    "qemu-img convert -f vmdk -O qcow2 -c output/dsoxlab-appliance-${var.image_version}/qcow2-extract/*.vmdk output/dsoxlab-appliance-${var.image_version}/dsoxlab-appliance-${var.image_version}.qcow2",
    "rm -rf output/dsoxlab-appliance-${var.image_version}/qcow2-extract"
  ]
}
```

## Bugs found

### 1. Missing `-c` flag inflated the qcow2 to ~3× the OVA size
First attempt (`qemu-img convert -f vmdk -O qcow2 ...`, no compression
flag) produced a 2.78 GiB file from a 1.04 GiB OVA. Cause: the source
VMDK is VirtualBox's stream-optimized (compressed) export; `qemu-img
convert` to qcow2 is uncompressed by default, so the conversion
effectively decompressed without recompressing. Fixed by adding `-c`
(qcow2's own internal zlib compression). Result: 0.98 GiB qcow2 vs
1.04 GiB OVA — same order of magnitude, no further tuning needed.
Consistent with the earlier `ovftool --compress=9` finding on the
OVA itself (recompressing an already-compressed export doesn't
reliably help, and can make things worse without the right flag).

### 2. UEFI firmware assumption was wrong — this build is BIOS legacy
First boot test used `-bios <edk2-x86_64-code.fd>` (OVMF/UEFI), which
failed to find any ESP partition (`map -r` showed only raw `BLK*:`
entries, no `FS*:`). Root cause: `virtualbox-iso` was never configured
with `firmware = "efi"` — VirtualBox defaults to BIOS legacy, and
that's what this appliance has always booted as, unnoticed until now
because both VirtualBox and VMware handle legacy BIOS transparently
during import. Confirmed by booting with plain SeaBIOS (no `-bios`/
`-pflash` flags at all): GRUB loaded correctly from the MBR boot
sector. **Not a qcow2-specific bug** — this is true of the OVA too,
just never surfaced before because neither validated hypervisor cares.
Worth a deliberate decision later: stay BIOS legacy (simpler, works
today) or move to UEFI (more modern, potentially required for some
future target like Secure Boot–enforcing environments) — not decided
here, flagging only.

### 3. `-nographic` hung indefinitely on GRUB (false "frozen" read)
With `-nographic`, the VM appeared stuck after "Welcome to GRUB!" —
no visible progress, but `ps aux` showed the QEMU process pinned near
100% CPU for several minutes, i.e. actively spinning, not idle/hung.
Cause: GRUB's default output targets the VGA framebuffer, which
`-nographic` removes entirely — GRUB (or whatever ran right after)
was very likely looping trying to write to a display that doesn't
exist in that mode. Switching to a real display (plain QEMU window,
or `-display vnc=...`) resolved it immediately — same boot completed
normally in seconds. Lesson for any future QEMU-based testing of this
appliance: don't default to `-nographic` for interactive/first boots;
reserve it for scenarios confirmed compatible with serial-console
output (this appliance's GRUB config isn't, at least not as shipped).

### 4. False positive on nested-virt detection under software-emulated QEMU (macOS, no `-accel hvf`)
Running without hardware acceleration (plain TCG emulation, no
`-accel hvf` on macOS), `/proc/cpuinfo` inside the guest reported
`svm` — but `virt-host-validate qemu` failed with *"HW virtualization
CPU features not found"*, and no real nested virtualization was
possible. TCG's default emulated CPU model appears to expose this
flag cosmetically without real backing hardware capability. Re-tested
with `-accel hvf -cpu host`: the flag disappeared entirely, and
`virt-host-validate` correctly failed for the real reason (Apple's
Hypervisor Framework doesn't expose VMX/SVM to guests — a known,
structural HVF limitation, not a bug here). **This is a testing-
environment artifact, not a flaw in the detection script** — real
hypervisors (VirtualBox, VMware, Hyper-V, real KVM) report actual CPU
capabilities faithfully; this false positive is specific to
unaccelerated TCG and unlikely to occur for an actual end user on a
real hypervisor. Documented here so it isn't rediscovered as a scare
later without context.

### 5. Testing pitfall — reused a disk that had already completed first boot
After the initial macOS test, the same `.qcow2` file was carried over
to KVM/Proxmox testing. Since `dsoxlab-first-boot-setup.service` and
`dsoxlab-provider-setup.service`-on-success both self-disable after a
successful run, the account/network setup from the *first* environment
(macOS) persisted and did not re-run on the *second* environment
(Proxmox), even though the actual system state (login, network) had
already been configured for a different host. Result: an apparently
successful "first boot" test that wasn't actually testing first-boot
behavior at all for that second environment. Re-extracted a fresh,
never-booted `.qcow2` from the same untouched `.ova` and repeated the
test properly. **General lesson, not qcow2-specific**: any
"first boot" validation must start from an artifact that has never
been booted anywhere — reusing a disk across test environments quietly
invalidates the test.

## Final validated result (fresh disk, real KVM host — Debian 13 VM on Proxmox, nested virtualization enabled at the Proxmox VM level)

```
virt-host-validate qemu:
  hardware virtualization ............: PASS
  /dev/kvm exists .....................: PASS
  /dev/kvm is accessible ..............: PASS
  (IOMMU / Secure Guest: WARN — informational, not blocking)

dsoxlab doctor:
  virsh/KVM ...........................: installed (libvirt 9.0.0)
  incus ................................: installed (client 7.4, daemon ok)
```

First real first-boot on this environment: account creation, network
adaptation, and the deferred provider install all completed correctly
against genuine hardware-accelerated nested virtualization — not the
false positive from #4.

## Remaining before this could move toward `main`

- [ ] `post-processor "checksum"` doesn't cover the qcow2 yet — only
      checksums the OVA. Needs explicit input file list update.
- [ ] `RELEASE.md`'s dual-hypervisor validation checklist would need a
      third leg (VirtualBox + VMware + real KVM/qcow2), not a shortcut
      because the conversion itself is fast.
- [ ] `qemu-img` prerequisite not yet documented anywhere outside this
      file.
- [ ] CI (`build-release.yml`) would need the same tool-presence
      verification pattern already used for Packer/VirtualBox/gh/
      plumber, plus qcow2 in the `gh release create` asset list and
      `attest-build-provenance` subject-path.
- [ ] No decision yet on BIOS-legacy vs UEFI (#2) — affects both OVA
      and qcow2 equally, worth resolving once rather than per format.
