#!/usr/bin/env bash
#
# Adapted from: https://github.com/menri005/kali_unattended/blob/master/build_kali.sh

# ---

# Kali does not have a nice URL download pathway, so this discerns the latest
# version name (e.g. '2022.3') and overwrites that Packer variable
KALI_LATEST="-var=iso_kali=https://cdimage.kali.org/current/$(curl --silent https://cdimage.kali.org/current/ | grep --perl-regexp --only-matching 'kali-linux-.*?-installer.amd64.iso' | uniq)"

# $PACKER_BUILD_ARGS is exportable, so this prevents it from being overwritten
# when its value is already set
: "${PACKER_BUILD_ARGS:=}"

# ---

packer_build () {
    # $1 : Hypervisor+OS build
    # $2 : any other CLI args that might be needed
    CHECKPOINT_DISABLE=1 \
    packer \
        build \
        ${PACKER_BUILD_ARGS} \
        -only "${1}" \
        "${KALI_LATEST}" \
        .
}

show_help () {
    echo "
EZ wrapper scripts for building Packer images.

Usage:
    [PACKER_BUILD_ARGS=''] $0 [-OPTION, ...] BUILD_NAME

Example:
    $0 -t -f vbox-kali

Environment Variables:
    PACKER_BUILD_ARGS can be set and passed through to 'packer build'. This is
    especially useful for any variable in the file 'variables.pkr.hcl'. For
    example, to skip the full system upgrade at the end of a Kali build:
    
    PACKER_BUILD_ARGS='-var=full_system_upgrade_command_debian_kali=ls' \
        $0 vbox-kali

Options:
    NOTE: These MUST come before the BUILD_NAME & must be separated by spaces.

    -a|--ask        : on errors, pause and prompt for next action
    -f|--force      : overwrite existing build artifacts
    -t|--timestamp  : show timestamps
    -g|--gui        : show GUI of VM while building
    -h|--help       : show this help
    -v|--verbose    : run with Packer verbose

BUILD_NAME:
    The {Hypervisor}-{OS} to build. Most names should be self-explanatory.

    Supported BUILD_NAMEs:
        * vbox-kali
        * qemu-kali
        * vbox-arch
        * qemu-arch
   " 
}

# ---

# ARGS always required
if [[ -z "${1}" ]] ; then
    show_help
else
    while : ; do
        case "${1}" in

            # OPTIONS
            -v|--verbose)
                export PACKER_LOG=1
                #set -x
                ;;
            -f|--force)
                PACKER_BUILD_ARGS+=" -force"
                ;;
            -t|--timestamp)
                PACKER_BUILD_ARGS+=" -timestamp-ui"
                ;;
            -g|--gui)
                PACKER_BUILD_ARGS+=" -var=dont_display_gui=false"
                ;;
            -a|--ask)
                PACKER_BUILD_ARGS+=" -on-error=ask"
                ;;

            # BUILD_NAMEs
            vbox-kali)
                echo "[i] Currently only BIOS mode is supported!"
                PACKER_BUILD_ARGS+=" -var=virtualbox_firmware=bios"
                packer_build virtualbox-iso.kali
                break
                ;;
            qemu-kali)
                printf "\n!!! CURRENTLY UNTESTED !!!\n"
                packer_build qemu.kali
                break
                ;;
            vbox-arch)
                packer_build virtualbox-iso.arch
                break
                ;;
            qemu-arch)
                printf "\n!!! CURRENTLY UNTESTED !!!\n"
                packer_build qemu.arch
                break
                ;;

            # DEFAULT/HELP
            -h|--help|*)
                show_help
                break
                ;;
        esac
        shift
    done
fi
