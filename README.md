# Packer

Locally build Virtual Machines from-scratch using 1-command.

## Pre-requisites

Reference: [Packer Installation](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)

```
# Install Packer
sudo pacman -S packer
```

# Usage

## Quickstart Build

```bash
# QEMU Plugin
packer plugins install github.com/hashicorp/qemu

# ===

# Normal
packer build .

# Debug
PACKER_LOG=1 packer build -on-error=ask .

# ===

# Add built image to Vagrant
vagrant box add --name arch-box output-arch/arch-box-libvirt-1.0.0.box

# Remove from Vagrant
vagrant box remove my-arch-box
```

* [Packer Docs](https://www.packer.io/docs)

## Packer Templates

Templates can be useful examples, and there are many such templates on the Internet. During my experimentation with using many of them, I learned the hard way that many do not work "out-of-the-box" and using the Packer documentation was much simpler than a poorly documented, old template. Be cautious for a few reasons:

- some templates use the old template format in JSON instead of the newer HCL format
- some templates might not work without a lot of variable configuration (because the templates are heavily parameterized)
- some templates might not work because they are simply out-of-date with newer packer versions

* [Unofficial Packer Templates](https://github.com/chef/bento/tree/main/packer_templates)
* [Arch Packer Template 1](https://github.com/conao3/packer-manjaro/blob/master/manjaro-template.json)
* [Arch Packer Template 2](https://github.com/safenetwork-community/mai-in-a-box)
