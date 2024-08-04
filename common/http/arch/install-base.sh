#!/usr/bin/env bash
#
# Automated script to install Arch Linux when ran inside of the proper liveboot
#
# Adapted from: https://github.com/elasticdog/packer-arch/blob/master/scripts/install-base.sh
# Reference: https://wiki.archlinux.org/title/Installation_guide

set -e

# === VARIABLES ===

# Save current set vars to show only script-set vars later
# https://unix.stackexchange.com/a/504586
BEFORE_VARIABLES="/tmp/before_set_variables.txt"
declare -p > "$BEFORE_VARIABLES"

# --- EXPORTABLE Vars ---
# NOTE: set via 'export VAR VALUE' before running script
# If var undefined, assign default: https://stackoverflow.com/a/28085062

: "${SET_HOSTNAME:=arch.localhost}"
: "${SET_KEYMAP:=us}"
: "${SET_LANGUAGE:=en_US.UTF-8}"
: "${SET_TIMEZONE:=Mexico/General}"  # from /usr/share/zoneinfo/
: "${ARCH_MIRROR_COUNTRY:=US}"  # reflector --list-countries
: "${LUKS_PASSWORD:=user}"
: "${ROOT_PASSWORD:=root}"
: "${USER_NAME:=user}"
: "${USER_PASSWORD:=user}"

# Discern main disk drive to provision (QEMU & VBox compatible)
# NOTE: This will automatically prefer SSDs (nvme) over normal harddisks (sda)
DISK_HELPER=$(lsblk --paths --output NAME,TYPE --sort NAME | grep disk | awk '{print $1}' | grep --extended-regexp '.da|nvme' | sort --reverse | tail -n1)
: "${DISK:=$DISK_HELPER}"
if [[ "${DISK}" = *nvme* ]] ; then
    # nvmeXnXpX format
    : "${DISK_PART_BOOT:=${DISK}p1}"
    : "${DISK_PART_ROOT:=${DISK}p2}"
else
    # sdX format
    : "${DISK_PART_BOOT:=${DISK}1}"
    : "${DISK_PART_ROOT:=${DISK}2}"
fi

# START !!! === do NOT modify below vars === !!!

CHROOT_MOUNT='/mnt'
BOOT_MOUNT='/boot'
BOOTLOADER_DIR='boot'

LUKS_CONTAINER='luks_container'
LUKS_PATH="/dev/mapper/${LUKS_CONTAINER}"
LVM_VG='luks_root'
LVM_LV_ROOT='root'
LVM_ROOT_PATH="/dev/${LVM_VG}/${LVM_LV_ROOT}"
LUKS_LVM_MKINITCPIO_HOOKS='HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)'

# END !!! === do NOT modify above vars === !!!

# --- SCRIPT FUNCTIONS ---

show_help () {
    echo
    echo "USAGE: $0 -i,--interactive|-n,--noninteractive [options]"
    echo
    echo 'NOTE: options MUST be separated by whitespace:'
    echo "          $0 -i -u"
    echo
    echo '-i, --interactive              : prompt user for values (e.g. disk to pacstrap)'
    echo '                                 (if set, -n|--noninteractive will be ignored)'
    echo '-n, --noninteractive           : smartly discern values (e.g. guess disk to pacstrap)'
    echo '-u, --update-archlinux-keyring : update archlinux-keyring package before pacstrap'
    echo '                                 (only use when pacstrap gives keyring or package issues)'
    echo
}

# Yes/No Confirmation Prompt
# https://stackoverflow.com/a/29436423
yes_or_no () {
    while true ; do
        read -rp "$* [y/n]: " yn
        case $yn in
            [Yy]*)
                echo "Continuing..."
                break
                ;;
            [Nn]*)
                echo "[!] Aborted"
                exit  5
                ;;
        esac
    done
}

# === PRECHECKS ===

# CLI args required
if [[ -z "${1}" ]] ; then
    echo '[E] This script requires commandline arguments!'
    show_help
    exit 2
else
    echo "[+] CLI ARGS set: ${*}"
fi

# Safety to prevent destruction when outside of liveboot
if [[ ! "$(uname --nodename)" == "archiso" ]] ; then
    echo
    echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    echo '[E] This script must only be ran in an Arch Linux liveboot!'
    echo '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    echo
    show_help
    exit 3
fi

# Parse script's commandline args
# https://mywiki.wooledge.org/BashFAQ/035
while : ; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--interactive)
            INTERACTIVE=1
            ;;
        -n|--noninteractive)
            # If $INTERACTIVE=1, safely ignore
            if [[ "$INTERACTIVE" -ne 1 ]] ; then
                INTERACTIVE=0
            fi
            ;;
        -u|--update-archlinux-keyring)
            # Update keyring to avoid corrupted packages ; only sometimes needed
            yes | pacman -S --refresh --refresh --noconfirm archlinux-keyring
            ;;
        *)
            break
    esac
    shift
done

# --- Interactive Mode :: Safe Prompts ---

# Show (only) script-set vars for validation
echo "=== DEFINED VARIABLES FOR BULD ==="
declare -p | diff --ed --ignore-matching-lines='PIPESTATUS' --ignore-matching-lines='_=' "$BEFORE_VARIABLES" - | grep 'declare' | awk '{print $3}'

if [[ "$INTERACTIVE" -eq 1 ]] ; then
    # Pause to allow interactive user to review build variables
    echo "[i] Review script vars above for build... Hit ENTER when done"
    read

    # Get disk partitioning info
    echo '[i] INTERACTIVE MODE... will prompt for destructive values!'
    echo '!!! NOTE: Values are not validated... that is YOUR job !!!'
    echo
    echo 'For the following disk-related questions, provide FULL-PATH for each'
    echo '  e.g. /dev/nvme0n1 /dev/nvme0n1p1 /dev/nvme0n1p2'
    echo 'OR hit ENTER if the default value in [] is okay'
    echo
    lsblk --fs
    echo
    echo "─HARDDRIVE :: DISK [$DISK]: " 
    read -r READ_DISK
    DISK=READ_DISK
    echo "└─BOOT PARTITION :: DISK_PART_BOOT [$DISK_PART_BOOT]: "
    read -r READ_DISK_PART_BOOT
    DISK_PART_BOOT=READ_DISK_PART_BOOT
    echo "└─ROOT PARTITION :: DISK_PART_ROOT [$DISK_PART_ROOT]: "
    read -r READ_DISK_PART_ROOT
    DISK_PART_ROOT=READ_DISK_PART_ROOT
    echo

    yes_or_no "Values collected... Remember, these are not validated... Ready to continue?"
fi

# ---

set -u

# === DISK ===

# Unmount all drives from previous runs (just in case)
set +e
cryptsetup close "$LUKS_PATH"
umount -f "$DISK_PART_BOOT"
umount -f "$DISK_PART_ROOT"
set -e

# Clearing partition table on "${DISK}"
sgdisk \
    --zap-all \
    "${DISK}"

# Destroying magic strings and signatures on "${DISK}"
dd \
    if=/dev/zero \
    of="${DISK}" \
    bs=512 \
    count=2048
wipefs \
    --all \
    "${DISK}"

if [[ -e /sys/firmware/efi/efivars ]] ; then
    # (U)EFI
    # https://wiki.archlinux.org/title/Installation_guide#Example_layouts
    echo "[i] Detected (U)EFI... will use GPT."
    GRUB_PKGS="efibootmgr dosfstools mtools"
    GRUB_TARGET="x86_64-efi"
    GRUB_INSTALL_PARAMS="--removable --bootloader-id=${BOOTLOADER_DIR} --efi-directory=${BOOT_MOUNT}"

    # Create EFI partition: 550MB size, type EFI (ef00), named, attribute bootable
    sgdisk \
        --new=1:0:+550M \
        --typecode=1:ef00 \
        --change-name=1:${BOOTLOADER_DIR} \
        --attributes=1:set:2 \
        "${DISK}"
    # Create root partition: remaining free space, type Linux (8300), named
    sgdisk \
        --new=2:0:0 \
        --typecode=2:8300 \
        --change-name=2:${LVM_LV_ROOT} \
        "${DISK}"

    # Creating /boot filesystem (FAT32)
    yes | mkfs.fat \
        -F 32 \
        -n ${BOOTLOADER_DIR^^} \
        "${DISK_PART_BOOT}"

else
    # BIOS
    # https://wiki.archlinux.org/title/Partitioning#BIOS/MBR_layout_example
    echo "[i] Detected BIOS... will use MBR."
    GRUB_PKGS=""
    GRUB_TARGET="i386-pc"
    GRUB_INSTALL_PARAMS=""
    
    # Reference: https://www.man7.org/linux/man-pages/man8/sfdisk.8.html
    # "Header lines": set disk as MBR
    echo 'label: dos' | sfdisk \
        --quiet \
        "${DISK}"
    # "Named-fields format": start & size implied (1MB to end), boot active, 83 Linux type
    echo -e "size=256MiB, type=83, name='${BOOTLOADER_DIR}'\ntype=83, name='${LVM_LV_ROOT}'" | sfdisk \
        --quiet \
        "${DISK}"
    
    yes | mkfs.ext4 \
        -L ${BOOTLOADER_DIR} \
        "${DISK_PART_BOOT}"
fi

# === LVM on LUKS ===
# Reference: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS

# Create LUKS encrypted container
# NOTE: Grub supports LUKS1 (LUKS2 not well-supported): https://wiki.archlinux.org/title/GRUB#Encrypted_/boot
echo -n "${LUKS_PASSWORD}" | cryptsetup \
    luksFormat \
    --type luks \
    --force-password \
    "${DISK_PART_ROOT}" -
echo -n "${LUKS_PASSWORD}" | cryptsetup \
    open \
    "${DISK_PART_ROOT}" \
    "${LUKS_CONTAINER}"
# Create LVM
pvcreate \
    "${LUKS_PATH}"  # physical group
vgcreate \
    "${LVM_VG}" \
    "${LUKS_PATH}"  # volume group
lvcreate \
    --extents 100%FREE \
    --name "${LVM_LV_ROOT}" \
    "${LVM_VG}"

# Creating /root filesystem (ext4)
yes | mkfs.ext4 \
    -F \
    -m 0 \
    -L "${LVM_LV_ROOT}" \
    "${LVM_ROOT_PATH}"

# Mounting "${LVM_ROOT_PATH}" to "${CHROOT_MOUNT}"
mount \
    "${LVM_ROOT_PATH}" \
    "${CHROOT_MOUNT}"
    
# Mount boot drive
mount \
    --mkdir \
    "${DISK_PART_BOOT}" \
    "${CHROOT_MOUNT}${BOOT_MOUNT}"

# After partitioning, discern LUKS device for GRUB
LUKS_DEVICE_UUID="$(lsblk --noheadings --nodeps --output UUID ${DISK_PART_ROOT})"
# TODO: add SSD TRIM support https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)
LUKS_KERNEL_BOOT_PARAM="cryptdevice=UUID=${LUKS_DEVICE_UUID}:${LUKS_CONTAINER} root=${LVM_ROOT_PATH}"

# === SYSTEM CONFIG ===

ln --symbolic --force /usr/share/zoneinfo/${SET_TIMEZONE} /etc/localtime
# Sync time
timedatectl \
    set-ntp true
hwclock --systohc

# Valid internet connection required
ping -c 1 -W 10 archlinux.org

# Set pkg mirrorlist w/ desired options
# Reference: https://xyne.dev/projects/reflector/
reflector \
    --country "${ARCH_MIRROR_COUNTRY}" \
    --ipv4 \
    --latest 10 \
    --completion-percent 100 \
    --protocol https \
    --sort rate \
    --threads 5 \
    --save /etc/pacman.d/mirrorlist

# pacstrap installation
sed \
    --in-place \
    's/.*ParallelDownloads.*/ParallelDownloads = 10/g' \
    /etc/pacman.conf
yes | pacstrap "${CHROOT_MOUNT}" \
    base \
    base-devel \
    linux \
    linux-headers \
    linux-firmware \
    intel-ucode \
    archlinux-keyring \
    networkmanager \
    iwd \
    vim \
    openssh \
    python \
    lvm2 \
    grub \
    os-prober \
    ${GRUB_PKGS}

# TODO: genfstab sometimes generates bad UUID for boot disk
genfstab \
    -t UUID \
    -p \
    "${CHROOT_MOUNT}" \
    > "${CHROOT_MOUNT}"/etc/fstab
arch-chroot "${CHROOT_MOUNT}" bash -c "
    # Machine
    echo ${SET_HOSTNAME} > /etc/hostname
    echo -e '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 ${SET_HOSTNAME} $(echo ${SET_HOSTNAME} | cut --fields=1 --delimiter=. -)' > /etc/hosts
    ln --symbolic --force /usr/share/zoneinfo/${SET_TIMEZONE} /etc/localtime
    #timedatectl set-ntp true
    #sleep 10 && timedatectl status
    #hwclock --systohc
    echo SET_KEYMAP=${SET_KEYMAP} > /etc/vconsole.conf
    sed --in-place s/#${SET_LANGUAGE}/${SET_LANGUAGE}/ /etc/locale.gen
    locale-gen
    systemctl enable NetworkManager sshd

    # Root User
    echo 'root:${ROOT_PASSWORD}' | chpasswd --crypt-method SHA512

    # Unprivileged User
    echo '%wheel ALL=(ALL) ALL' | tee --append /etc/sudoers && visudo --check --strict
    useradd ${USER_NAME} --create-home --user-group --groups wheel
    echo '${USER_NAME}:${USER_PASSWORD}' | chpasswd --crypt-method SHA512
"

# === BOOT ===

# Regenerate mkinitcpio and install Grub
arch-chroot "${CHROOT_MOUNT}" bash -c "
    # Reconfigure mkinitcpio due to LUKS + LVM
    sed --in-place 's/^\s*HOOKS.*/${LUKS_LVM_MKINITCPIO_HOOKS}/g' /etc/mkinitcpio.conf
    mkinitcpio --allpresets

    # Add kernel boot params for LUKS
    sed --in-place 's#.*GRUB_CMDLINE_LINUX_DEFAULT.*#GRUB_CMDLINE_LINUX_DEFAULT=\"${LUKS_KERNEL_BOOT_PARAM}\"#g' /etc/default/grub
    # Install GRUB bootloader
    grub-install --recheck --modules='lvm part_gpt part_msdos' --target=${GRUB_TARGET} ${GRUB_INSTALL_PARAMS} ${DISK}
    grub-mkconfig --output ${BOOT_MOUNT}/grub/grub.cfg
"

# === CLEANUP ===

# Cleanup pacman cache before saving VM disk
arch-chroot "${CHROOT_MOUNT}" bash -c "
    yes | pacman -S --clean --clean --noconfirm
"

# === DONE ===

echo -e "\n===>>> BASE INSTALLATION COMPLETE <<<===\n"
