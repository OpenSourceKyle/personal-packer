# Packer

Locally build Virtual Machines from-scratch using 1-command.

## Pre-requisites

* Local Builds:
  * Packer installation: [Packer Installation](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)
  * Run `./run_first_time_setup.sh` once manually before running any `packer` commands

# Usage

## Quickstart

Use the included `build.sh` script to handle Packer. More advanced commands will need to be ran manually.

```shell
./build.sh --help
```

## Build

NOTE: This is not recommended since multiple virtualization platforms are supported in this template, which conflict (e.g. QEMU & VirtualBox).

```shell
# Build all templates

packer build .
```
---

## Sample Build Times

Packer runs fairly quickly, depending on if updates or large packages are installed or not. Below are some rough build times to give an estimate:

### Kali

#### With full system upgrade (as of March 2022)
* 39 minutes 35 seconds
_this time will largely depend on how out-of-date the ISO is versus the current rolling distro state_

#### Without full system upgrade
* 27 minutes 14 seconds

### Arch (as of August 2022)

NOTE: Arch can be built to UEFI/GPT or BIOS/MBR and should automatically detect and set all the respective values for each.

#### Minimal build
* 3 minutes 12 seconds

# Troubleshooting Common Issues:

Some simple solutions to common problems.

## Packer deletes the VM on a failure

Packer deletes a VM by default on failure instead of asking. By keeping the VM (that will stay running as well), triage can be possible to troubleshoot a build failure.

```shell
# Add the argument `-on-error=ask` after the subcommand like:
packer build \
    -on-error=ask \
    .
```

## Show debug output

Packer only has debug output, which is similar to setting a verbosity option (e.g. `-v` or `--verbose`) in other programs.

```shell
# Append `PACKER_LOG=1` environment variable to a packer run like:
PACKER_LOG=1 packer build .
```

# TODO

* Arch Linux:
- `base-install.sh`: `genfstab` rarely generates the wrong UUID for the boot drive, which breaks GRUB; this has only been noticed on specific hardware and not in VMs
- `base-install.sh`: clock and timing issues from OS to RTC
- add shared folder (vbox guest utils) commands: echo -e 'HEAD / HTTP/1.0\r\n\r\n' | openssl s_client -connect

# References:

* [Packer Docs](https://www.packer.io/docs)

## Packer Templates 
Templates can be useful examples, and there are many such templates on the Internet. During my experimentation with using many of them, I learned the hard way that many do not work "out-of-the-box" and using the Packer documentation was much simpler than a poorly documented, old template. Be cautious for a few reasons:
- some templates use the old template format in JSON instead of the newer HCL format
- some templates might not work without a lot of variable configuration (because the templates are heavily parameterized)
- some templates might not work because they are simply out-of-date with newer packer versions

* [Unofficial Packer Templates](https://github.com/chef/bento/tree/main/packer_templates)
* [Arch Packer Template 1](https://github.com/conao3/packer-manjaro/blob/master/manjaro-template.json)
* [Arch Packer Template 2](https://github.com/safenetwork-community/mai-in-a-box)
