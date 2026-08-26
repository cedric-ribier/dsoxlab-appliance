# Release procedure

*[Version française](RELEASE.fr.md)*

Manual procedure — no CI runner is configured yet (see `PLAN.md`, open
questions). Follow this end to end for any new build; skipping the
dual-hypervisor validation (step 4) is how several bugs made it past
a single-hypervisor test during development.

Validated Versions

This procedure has been validated with:

| Composant | Version |
|------------|------------|
| Debian netinst | 12.15.0 |
| VirtualBox | 7.2.14 - 7.2.16 |
| Packer | 1.15.4 - 1.16 |
| Git | 2.50.1 - 2.51.0 |
| VMware Fusion | 13.6.2 |
| VMware Workstation | 26.0.025388281 |

Other versions may work but have not been verified.

## 1. Prerequisites

Hardware Requirements

Minimum recommended configuration:

| Configuration | CPU | RAM | DISQUE | Internet |
|:--:|:--:|:--:|:--:|:--:|
|minimal|4 coeurs|8 Go|50 Go|✅|
|recommandée|8 coeurs|16 Go|100 Go|✅|

### macOS

```bash
brew install git
brew install hashicorp/tap/packer
brew install --cask virtualbox
```

macOS will likely block VirtualBox's kernel extension on first install
— allow it once via *System Settings → Privacy & Security*.

### Linux (Debian/Ubuntu)

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y packer virtualbox
```

No known hypervisor conflict on Linux — VirtualBox's kernel module
(`vboxdrv`) coexists normally with KVM if both happen to be installed,
as long as they're not both trying to run a VM at the exact same time
on the same CPU.

Add your user to the VirtualBox group :

```bash
sudo usermod -aG vboxusers $USER
```
Log out and back in afterward.

### Windows

> **Hyper-V/WSL2 conflict — read before installing anything.**
> VirtualBox and Hyper-V-based virtualization (which includes WSL2,
> and often Windows 11's own Virtualization-Based Security /
> Memory Integrity, sometimes on by default) compete for exclusive
> access to VT-x. Running both on the same machine leads to VirtualBox
> falling back to a slow/unstable compatibility mode (community
> reports describe frequent crashes even in recent VirtualBox
> releases) — not a rare edge case, a fundamental architecture
> conflict.
>
> **Before building on Windows**: disable Hyper-V, WSL2, and
> Virtualization-Based Security (*Turn Windows features on or off* →
> uncheck *Hyper-V*, *Virtual Machine Platform*, *Windows Subsystem
> for Linux*; also check *Windows Security → Device Security → Core
> isolation* and turn off *Memory integrity* if present), then
> restart.

Install [Git for Windows](https://git-scm.com/download/win) (provides
**Git Bash** — a real bash shell with no Hyper-V dependency, unlike
WSL2) and run the rest of this procedure from Git Bash, so the exact
same commands as macOS/Linux apply throughout this document.

```bash
# In Git Bash, after installing Git for Windows:
winget install HashiCorp.Packer
winget install Oracle.VirtualBox
```

(or download both installers manually from
[developer.hashicorp.com/packer](https://developer.hashicorp.com/packer/install)
and [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) if
`winget` isn't available.)

## 2. Clone the Repository

```bash
git clone https://github.com/cedric-ribier/dsoxlab-appliance.git
```

## 3. Build

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

Expected build time:

- NVMe SSD + 8 vCPU: approximately 15 minutes
- SATA SSD + 4 vCPU: approximately 25 minutes
- HDD: untested

## 4. Check the artifact before importing anywhere

```bash
ls -la output/dsoxlab-appliance-X.Y.Z/*.ova
sha256sum -c output/dsoxlab-appliance-X.Y.Z/SHA256SUMS
```
SHA256SUM for Windows
```bash
(cd /D/Documents/Github/dsoxlab-appliance/packer/output/dsoxlab-appliance-X.Y.Z && sha256sum -c SHA256SUMS)
```
> On Windows (Git Bash), an explicit absolute path turned out to be necessary — confirmed by an external tester; a plain relative `cd` + `sha256sum -c` wasn't reliable in their environment.

> On macOS, `sha256sum` isn't installed by default (BSD userland uses
> `shasum` instead) — either `brew install coreutils`, or substitute
> `shasum -a 256 -c` for every `sha256sum -c` in this document. Native
> on Linux and in Git Bash on Windows, no substitution needed there.

Confirm the size is under 2 GiB (`2147483648` bytes) — GitHub's hard
per-file Release limit.

## 5. Validate on both hypervisors — do not skip either

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
ping -c 4 deb.debian.org
dsoxlab --version
dsoxlab doctor
ls /etc/ssh/ssh_host_*           # Host keys must have been regenerated
systemctl status ssh --no-pager  # Must be enabled and running
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

## 6. Tag and publish

### Verify Git Status

Before creating a release:

```bash
git status
```
The repository must be clean:

```texte
nothing to commit, working tree clean
```
Build logs must remain local and must never be committed.

Example:
```bash
git status
```
must not show anything except optionally untracked local files such as:
```texte
build-*.log
```

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

## 7. Post-publish verification

```bash
gh release download vX.Y.Z -p "SHA256SUMS"
gh release download vX.Y.Z -p "*.ova"
sha256sum -c SHA256SUMS
```
Import the downloaded OVA a second time to verify that the published artifact is exactly the one validated locally.

## Release Acceptance Criteria

A release is considered valid if:

- the Packer build completes successfully;
- SHA256 checksums are valid;
- the OVA imports successfully into VirtualBox;
- the OVA imports successfully into VMware;
- keyboard layout is configured correctly;
- networking obtains a DHCP address;
- Internet access works;
- SSH host keys are regenerated;
- dsoxlab doctor reports no blocking issues.

## Known limitations at this stage

- No independent build has been performed by anyone other than the
  repository's author.
- No build provenance attestation is attached yet (planned once CI is
  in place — `actions/attest-build-provenance` requires GitHub Actions,
  which requires the runner question to be settled first).
