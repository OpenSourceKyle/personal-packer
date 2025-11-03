# Packer

Locally build an Arch Linux virtual machine from scratch with a single command.

## Pre-requisites

Reference: [Packer Installation](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)

```bash
# Install Packer
sudo pacman -S packer
```

## Usage

### Quickstart Build

```bash
# QEMU Plugin
packer plugins install github.com/hashicorp/qemu

# Build
packer build archlinux.pkr.hcl
export TMPDIR=~/.cache/packer/ ; packer build kali.pkr.hcl  # /tmp is normally too small for a Kali VM

# Add image to Vagrant boxes
vagrant box add --name arch-box output-arch/arch-box-libvirt-*.box
vagrant box add --name kali-box output-kali/kali-box-libvirt-*.box

# Remove from Vagrant
vagrant box remove arch-box
vagrant box remove kali-box

---

# Debug build
PACKER_LOG=1 packer build -on-error=ask .
```

- **Packer Docs**: <https://www.packer.io/docs>

---

## Arch Installer Script: `arch-base.sh`

This repository includes a self-contained Arch Linux installer used by the Packer build and also suitable for manual installs from the official Arch ISO. Consult the beginning of the script and/or run `./arch-base.sh --help` for a full list of options.

### Examples

- Interactive (prompts):

```bash
./arch-base.sh
```

- Non-interactive with explicit disk and encryption:

```bash
./arch-base.sh --non-interactive \
  --disk /dev/vda \
  --hostname myhost \
  --user vagrant \
  --password vagrant \
  --root-password vagrant \
  --disk-encryption mysecret
```
