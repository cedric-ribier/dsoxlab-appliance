# Release procedure

*[Version française](RELEASE.fr.md)*

Manual procedure — no CI runner is configured yet (see `PLAN.md`, open
questions). Follow this end to end for any new build; skipping the
dual-hypervisor validation (step 4) is how several bugs made it past
a single-hypervisor test during development.

## 1. Prerequisites

```bash
brew install hashicorp/tap/packer
brew install --cask virtualbox
```

macOS will likely block VirtualBox's kernel extension on first install
— allow it once via *System Settings → Privacy & Security*.

## 2. Build

```bash
cd appliance/packer
packer init .
packer validate -var "image_version=X.Y.Z" -var "providers=none" .
packer build -force -on-error=ask -var "image_version=X.Y.Z" -var "providers=none" . 2>&1 | tee build-X.Y.Z.log
```

`providers=none` is the recommended default (shell-only base, providers
install themselves on first boot when the host supports nested
virtualization — see `PLAN.md` §1). `providers=all` bakes in
KVM/libvirt/Incus at build time instead, useful for isolated testing of
that code path but not the release default.

Expect 15–25 minutes. The build downloads Debian's netinst ISO on first
run (cached afterward) and runs the full provisioning chain.

## 3. Check the artifact before importing anywhere

```bash
ls -la output/dsoxlab-appliance-X.Y.Z/*.ova
sha256sum -c output/dsoxlab-appliance-X.Y.Z/SHA256SUMS
```

Confirm the size is under 2 GiB (`2147483648` bytes) — GitHub's hard
per-file Release limit.

## 4. Validate on both hypervisors — do not skip either

This is the step that actually catches hypervisor-specific bugs
(network interface naming, nested-virt detection) that a single-target
test won't reveal.

### VirtualBox
```bash
VBoxManage import output/dsoxlab-appliance-X.Y.Z/dsoxlab-appliance-X.Y.Z.ova --vsys 0 --vmname dsoxlab-appliance-test
VBoxManage startvm dsoxlab-appliance-test --type gui
```
Log in as `user` / `MotDePasse` at first boot — a password change is
forced immediately. Confirm:
```bash
cat /etc/default/keyboard        # XKBLAYOUT="fr" (or whichever locale was preseeded)
ip a                             # interface should have a real DHCP-assigned address
dsoxlab --version
dsoxlab doctor
```

### VMware Fusion
Transfer the same `.ova` (no separate build). Before first boot, in
the VM's settings (VM powered off): enable *"Enable hypervisor
applications in this virtual machine"* if testing the nested-virt
provider path — this is a manual step VMware Fusion doesn't do by
default on import, and the deferred-install script correctly does
nothing without it (retries on every subsequent boot if enabled
later, no rebuild needed).

Same checks as above, plus, if nested virt is enabled:
```bash
sudo journalctl -u dsoxlab-provider-setup.service --no-pager
dpkg -l | grep -E "incus|qemu-kvm|libvirt"
```

## 5. Tag and publish

```bash
git add .
git commit -m "..."
git tag vX.Y.Z
git push origin main --tags
```

Manual publish (no CI runner configured yet):
```bash
gh release create vX.Y.Z \
  output/dsoxlab-appliance-X.Y.Z/dsoxlab-appliance-X.Y.Z.ova \
  output/dsoxlab-appliance-X.Y.Z/SHA256SUMS \
  --title "vX.Y.Z" \
  --notes "..."
```

## 6. Post-publish verification

```bash
gh release download vX.Y.Z -p "SHA256SUMS"
gh release download vX.Y.Z -p "*.ova"
sha256sum -c SHA256SUMS
```

## Known limitations at this stage

- No independent build has been performed by anyone other than the
  repository's author.
- No build provenance attestation is attached yet (planned once CI is
  in place — `actions/attest-build-provenance` requires GitHub Actions,
  which requires the runner question to be settled first).
