# Packer

Locally build Virtual Machines from-scratch using 1-command.

## Pre-requisites

Reference: [Packer Installation](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)

```
# Install Packer
sudo pacman -S packer

# Only necessary if running raw `packer` commands
./run_first_time_setup.sh
```

# Usage

## Quickstart Build

Use the included `build_vm.sh` script to handle Packer; it runs `run_first_time_setup.sh` automatically. More advanced commands will need to be ran manually.

```shell
./build_vm.sh --help

./build_vm.sh vbox-arch
./build_vm.sh qemu-arch 
```

# Troubleshooting Common Issues:

Some simple solutions to common problems.

## Packer deletes the VM on a failure

Packer deletes a VM by default on failure instead of asking. By keeping the VM (that will stay running as well), triage can be possible to troubleshoot a build failure.

```shell
./build_vm.sh --ask <BUILD>
```

## Show debug output

Packer only has debug output, which is similar to setting a verbosity option (e.g. `-v` or `--verbose`) in other programs.

```shell
./build_vm.sh --verbose <BUILD>
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
