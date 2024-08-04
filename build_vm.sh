#!/usr/bin/env bash
#
# Adapted from: https://github.com/menri005/kali_unattended/blob/master/build_kali.sh

# ---

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
        .
}

show_help () {
    echo "
EZ wrapper scripts for building Packer images.

Usage:
    [PACKER_BUILD_ARGS=''] $0 [-OPTION, ...] BUILD_NAME

Example:
    $0 -t -f vbox-arch

Environment Variables:
    PACKER_BUILD_ARGS can be set and passed through to 'packer build'. This is
    especially useful for any variable in the file 'variables.pkr.hcl'. For
    example, to skip the full system upgrade at the end of a Kali build:

    PACKER_BUILD_ARGS='-var=output_location=/new_location/VirtualMachines/' \\
        $0 vbox-arch

Options:
    NOTE: These MUST come before the BUILD_NAME & must be separated by spaces.

    -a|--ask        : on errors, pause and prompt for next action
    -f|--force      : overwrite existing build artifacts
    -t|--timestamp  : show timestamps
    -g|--gui        : show GUI of VM while building
    -h|--help       : show this help
    -v|--verbose    : run with Packer verbose
    -d|--debug      : runs with Bash 'set -x' flag

BUILD_NAME:
    The {Hypervisor}-{OS} to build. Most names should be self-explanatory.

    Supported BUILD_NAMEs:
        * vbox-arch
        * qemu-arch
   " 
}

# ---

# Enforce last args cannot be a flag ("-blah")
# https://www.cyberciti.biz/faq/linux-unix-bsd-apple-osx-bash-get-last-argument/
for last_arg in "$@" ; do : ; done
if [[ "${last_arg}" = -* ]] ; then
    echo "[E] No switch args like '${last_arg}' allowed as last argument"
    show_help
    exit 1
fi

# Ensure initial setup is complete
FIRST_TIME_SETUP="/tmp/packer-${0#./}"
if [[ ! -e "$FIRST_TIME_SETUP" ]] ; then
    ./run_first_time_setup.sh
    touch "$FIRST_TIME_SETUP"
fi

# ARGS always required
if [[ -z "${1}" ]] ; then
    show_help
else
    while : ; do
        case "${1}" in

            # OPTIONS
            -d|--debug)
                set -x
                ;;
            -v|--verbose)
                export PACKER_LOG=1
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
            vbox-arch)
                packer_build virtualbox-iso.arch
                break
                ;;
            qemu-arch)
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
