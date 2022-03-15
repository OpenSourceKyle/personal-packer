# Packer

Remotely or locally build Virtual Machines from-scratch using 1-command.

### Disclaimer

In below usages,
- **Local builds** are VMs that are created on the local, host computer. 
  - These cannot be created inside of a VM or container (because these are built with the hypervisor binaries).
- **Remote builds** are VMs that are created on a remote vSphere server.
  - These can be built from inside of a VM or container (because these are built with the respective REST API).

## Pre-requisites

Please read "Disclaimer" above in regards to VM location (and required setup).

* Remote-only Builds\*\*:
  * run Dockerized version via `./1_run_packer_controller.sh`
> \*\* NOTE: only works for vSphere remote VMs ; local VMs will require Packer to be installed and ran from the host (i.e. not from within a VM or container)

* Local (as well as Remote) Builds:
  * Packer installation: [Packer Installation](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)
  * Run `./run_first_time_setup.sh` once manually before running any `packer` commands

---

# Usage

Either inside of the Packer controller container (`./1_run_packer_controller.sh`) or after installing Packer locally, run:

```shell
# Build all templates (local & remote)
packer build .

# Build only remote
packer build -only="vsphere-iso.*" .
# Build only local
packer build -only="vmware-iso.*" .

# Build only a particular template
packer build -only="vsphere-iso.kali_2021" .
packer build -only="vsphere-iso.debian_10" .
packer build -only="vmware-iso.kali_2021" .
packer build -only="vmware-iso.debian_10" .

# Overwrite variable from CLI arg
# NOTE: the arg must be defined in variables.pkr.hcl
packer build -var="cpus=1" .

# EXAMPLE of overwriting variable:
### ACTION: Do NOT perform full system upgrade after installation (to minimize build time)
### NOTE: this works by overwriting the system update command to a 'nop' command and
### this cannot be an empty string or the build will fail (at the very end!)
### NOTE: the arg must be and is defined in variables.pkr.hcl
packer build -var="full_system_upgrade_command_debian_kali='whoami'" .
```

# Sample Build Times

Packer runs fairly quickly, depending on if updates or large packages are installed or not. Below are some build times to give an estimate:

## Kali 2021

### With full system upgrade
* 38 minutes 11 seconds

### Without full system upgrade
* 17 minutes 47 seconds

## Debian 10

Since Debian does not use rolling updates, the with and without full system upgrade times are the same:
* 12 minutes 24 seconds

---

# Troubleshooting Common Issues:

Some simple solutions to common problems.

## Packer deletes the VM on a failure

Packer deletes a VM by default on failure instead of asking. By keeping the VM (that will stay running as well), triage can be possible to troubleshoot a build failure.

```shell
# Add the argument `-on-error=ask` after the subcommand like:
packer build -on-error=ask .
```

## Show debug output

Packer only has debug output, which is similar to setting a verbosity option (e.g. "-v" or "--verbose") in other programs.

```shell
# Append `PACKER_DEBUG=1` environment variable to a packer run like:
PACKER_DEBUG=1 packer build .
```

# References:

* [Packer Docs](https://www.packer.io/docs)

Packer templates can be useful examples, and there are many such templates on the Internet. During my experimentation with using them, I learned the difficult way that many do not work "out-of-the-box" and using the Packer documentation was much simpler than a poorly documented, old template. Be cautious for a few reasons:
- some templates use the old template format in JSON instead of the newer HCL format
- some templates might not work without a lot of variable configuration (because the temaplates are parameterized so heavily)
- some templates might not work because they are simply out-of-date with newer packer versions

* [Unofficial Packer Templates](https://github.com/chef/bento/tree/main/packer_templates)
