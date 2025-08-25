## Packer

Locally build an Arch Linux virtual machine from scratch with a single command.

### Pre-requisites

Reference: [Packer Installation](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)

```
# Install Packer
sudo pacman -S packer
```

## Usage

### Quickstart Build

```bash
# QEMU Plugin
packer plugins install github.com/hashicorp/qemu

# Build
packer build .

# Debug build
PACKER_LOG=1 packer build -on-error=ask .

# Add built image to Vagrant
vagrant box add --name arch-box output-arch/arch-box-libvirt-1.0.0.box

# Remove from Vagrant
vagrant box remove arch-box
```

- **Packer Docs**: https://www.packer.io/docs

---

## Arch Installer Script: `install-base.sh`

This repository includes a self-contained Arch Linux installer used by the Packer build and also suitable for manual installs from the official Arch ISO. Consult the beginning of the script and/or run `./install-base.sh --help` for a full list of options.

### Examples

- Interactive (prompts):
```bash
./install-base.sh
```

- Non-interactive with explicit disk and encryption:
```bash
./install-base.sh --non-interactive \
  --disk /dev/vda \
  --hostname myhost \
  --user vagrant \
  --password vagrant \
  --root-password vagrant \
  --disk-encryption mysecret
```