#!/usr/bin/env bash
# Adapted from: https://github.com/elasticdog/packer-arch/blob/master/scripts/install-base.sh
# Reference: https://www.tecmint.com/arch-linux-installation-and-configuration-guide/
# Reference: https://github.com/badele/archlinux-auto-install/blob/main/install/install.sh

set -x
set -e

# === VARIABLES ===

# Discern main disk drive to provision (QEMU & VBox compatible)
# NOTE: This will automatically prefer SSDs (nvme) over normal harddisks (sda)
DISK=$(lsblk --paths --output NAME,TYPE --sort NAME | grep disk | awk '{print $1}' | grep --extended-regexp '.da|nvme' | sort --reverse | tail -n1)
# nvmeXnXpX format
if [[ "${DISK}" = *nvme* ]] ; then
    DISK_PART_BOOT="${DISK}p1"
    DISK_PART_ROOT="${DISK}p2"
# sdX format
else
    DISK_PART_BOOT="${DISK}1"
    DISK_PART_ROOT="${DISK}2"
fi

HOSTNAME='arch.localhost'
KEYMAP='us'
LANGUAGE='en_US.UTF-8'
TIMEZONE='US/Chicago'  # from /usr/share/zoneinfo/

# https://stackoverflow.com/a/28085062
# reflector --list-countries
: "${ARCH_MIRROR_COUNTRY:=US}"

LUKS_PASSWORD='user'

# Reference: https://unix.stackexchange.com/a/361789
# ROOT_PASSWORD="$(< /dev/urandom tr -cd '[:print:]' | head -c 20)" # generates random password
ROOT_PASSWORD='root'

USER_NAME='user'
USER_PASSWORD='user'

# --- do NOT modify ---

CHROOT_MOUNT='/mnt'
# Bootloader: ${EFI_DIR}/EFI/${BOOTLOADER_DIR}/grubx64.efi
EFI_DIR='/boot'
BOOTLOADER_DIR='boot'

# TODO: Warning: truncating password to 8 characters
ROOT_PASSWORD_CRYPTED=$(openssl passwd -crypt "$ROOT_PASSWORD")
USER_PASSWORD_CRYPTED=$(openssl passwd -crypt "$USER_PASSWORD")

LUKS_CONTAINER='cryptlvm'
LUKS_PATH="/dev/mapper/${LUKS_CONTAINER}"
LVM_VG='luks_root'
LVM_LV_ROOT='root'
LVM_ROOT_PATH="/dev/${LVM_VG}/${LVM_LV_ROOT}"
LUKS_LVM_MKINITCPIO_MODULES='MODULES=(ext4)'
LUKS_LVM_MKINITCPIO_HOOKS='HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)'

# --- SCRIPT FUNCTIONS ---

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

# --- SCRIPT ARGS ---

if [[ -z "${1+null}" ]] ; then
    echo "[E] This script requires commandline arguments!"
    exit 2
else
    echo "[+] CLI ARGS set: ${1}"
fi

# Prompt user before destructive actions take place when
# this option is unset (aka provide option to skip prompts)
INTERACTIVE=1

# Parse script's commandline args
# https://mywiki.wooledge.org/BashFAQ/035
while :; do
    case $1 in
        -i|--interactive)
            INTERACTIVE=1
            ;;
        -n|--noninteractive)
            INTERACTIVE=0
            ;;
        *)
            break
    esac
    shift
done

# Safe prompting
if [[ "$INTERACTIVE" -eq 1 ]] ; then
    echo '[i] INTERACTIVE MODE... will prompt for destructive values!'
    echo 'NOTE: Values are not validated... that is YOUR job!'

    echo
    echo 'For the following disk-related questions, provide FULL-PATH for each'
    echo '  e.g. /dev/nvme0n1 /dev/nvme0n1p1 /dev/nvme0n1p2'
    echo
    lsblk
    echo
    echo "─HARDDRIVE :: DISK [$DISK]: " 
    read -r DISK
    echo "└─BOOT PARTITION :: DISK_PART_BOOT [$DISK_PART_BOOT]: "
    read -r DISK_PART_BOOT
    if [[ -e /sys/firmware/efi/efivars ]] ; then
        echo "└─ROOT PARTITION :: DISK_PART_ROOT [$DISK_PART_ROOT]: "
        read -r DISK_PART_ROOT
    else
        echo "NOTE: in MBR only, DISK_PART_ROOT will be set to DISK_PART_BOOT automatically"
    fi
    echo

    yes_or_no "Values collected... Ready to continue?"
fi

set -u

# === DISK ===

# Clearing partition table on "${DISK}"
sgdisk --zap-all "${DISK}"

# Destroying magic strings and signatures on "${DISK}"
dd if=/dev/zero of="${DISK}" bs=512 count=2048
wipefs --all "${DISK}"

if [[ -e /sys/firmware/efi/efivars ]] ; then
    # (U)EFI
    # https://wiki.archlinux.org/title/Installation_guide#Example_layouts
    echo "[i] Detected (U)EFI... will use GPT."
    GRUB_PKGS="efibootmgr dosfstools mtools"
    GRUB_TARGET="x86_64-efi"
    GRUB_INSTALL_PARAMS="--bootloader-id=${BOOTLOADER_DIR} --efi-directory=${EFI_DIR}"

    # Create EFI partition: 550MB size, type EFI (ef00), named, attribute bootable
    sgdisk --new=1:0:+550M --typecode=1:ef00 --change-name=1:boot --attributes=1:set:2 "${DISK}"
    # Create root partition: remaining free space, type Linux (8300), named
    sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:root "${DISK}"
    
    # Creating /boot filesystem (FAT32)
    yes | mkfs.fat -F 32 -n BOOT "${DISK_PART_BOOT}"

else
    # BIOS
    # https://wiki.archlinux.org/title/Partitioning#BIOS/MBR_layout_example
    echo "[i] Detected BIOS... will use MBR."
    GRUB_PKGS=""
    GRUB_TARGET="i386-pc"
    GRUB_INSTALL_PARAMS=""
    DISK_PART_ROOT="$DISK_PART_BOOT"  # only 1 partition needed for BIOS & MBR
    
    # Reference: https://www.man7.org/linux/man-pages/man8/sfdisk.8.html
    # "Header lines": set disk as MBR
    echo 'label: dos' | sfdisk "${DISK}"
    # "Named-fields format": start & size implied (1MB to end), boot active, 83 Linux type
    echo 'bootable, type=83' | sfdisk "${DISK}"
fi

# LVM on LUKS
# Reference: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS

# Create LUKS encrypted container
# NOTE: Grub supports LUKS1 (LUKS2 not well-supported): https://wiki.archlinux.org/title/GRUB#Encrypted_/boot
echo -n "${LUKS_PASSWORD}" | cryptsetup luksFormat --type luks --force-password "${DISK_PART_ROOT}" -
echo -n "${LUKS_PASSWORD}" | cryptsetup open "${DISK_PART_ROOT}" "${LUKS_CONTAINER}"
# Create LVM
pvcreate "${LUKS_PATH}"  # physical group
vgcreate "${LVM_VG}" "${LUKS_PATH}"  # volume group
lvcreate --extents 100%FREE "${LVM_VG}" --name "${LVM_LV_ROOT}"

# Creating /root filesystem (ext4)
yes | mkfs.ext4 -F -m 0 -L "${LVM_LV_ROOT}" "${LVM_ROOT_PATH}"

# Mounting "${LVM_ROOT_PATH}" to "${CHROOT_MOUNT}"
mount "${LVM_ROOT_PATH}" "${CHROOT_MOUNT}"
    
# Mount boot drive
# NOTE: it must be mounted in this order for (U)EFI only
if [[ -e /sys/firmware/efi/efivars ]] ; then
    mount --mkdir "${DISK_PART_BOOT}" "${CHROOT_MOUNT}${EFI_DIR}"
fi

# After partitioning, discern LUKS device for GRUB
LUKS_DEVICE_UUID="$(lsblk --noheadings --nodeps --output UUID ${DISK_PART_ROOT})"
# TODO: add SSD TRIM support https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)
LUKS_KERNEL_BOOT_PARAM="cryptdevice=UUID=${LUKS_DEVICE_UUID}:${LUKS_CONTAINER} root=${LVM_ROOT_PATH}"

# === SYSTEM CONFIG ===

# Sync time
timedatectl set-ntp true

# Set pkg mirrorlist w/ desired options
# Reference: https://xyne.dev/projects/reflector/
reflector --country "${ARCH_MIRROR_COUNTRY}" --ipv4 --latest 10 --completion-percent 100 --protocol https --sort rate --threads 5 --save /etc/pacman.d/mirrorlist

# pacstrap installation
sed --in-place 's/.*ParallelDownloads.*/ParallelDownloads = 5/g' /etc/pacman.conf
# Update keyring to avoid corrupted packages; only sometimes needed
# yes | pacman -S --refresh --refresh --noconfirm archlinux-keyring
# yes | pacman -S --refresh --refresh --noconfirm ca-certificates
yes | pacstrap "${CHROOT_MOUNT}" base base-devel linux linux-headers linux-firmware intel-ucode archlinux-keyring dhcpcd vim openssh python lvm2 grub os-prober ${GRUB_PKGS}

genfstab -U -p "${CHROOT_MOUNT}" > "${CHROOT_MOUNT}"/etc/fstab
arch-chroot "${CHROOT_MOUNT}" bash -c "
    # Machine
    echo ${HOSTNAME} > /etc/hostname
    ln --symbolic --force /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    hwclock --systohc
    echo KEYMAP=${KEYMAP} > /etc/vconsole.conf
    sed --in-place s/#${LANGUAGE}/${LANGUAGE}/ /etc/locale.gen
    locale-gen
    systemctl enable dhcpcd sshd

    # Root User
    usermod --password ${ROOT_PASSWORD_CRYPTED} root
    echo '%wheel ALL=(ALL) ALL' | tee --append /etc/sudoers && visudo --check --strict

    # Unprivileged User
    useradd $USER_NAME --create-home --user-group --password $USER_PASSWORD_CRYPTED --groups wheel
"

# === BOOT ===

# Install GRUB UEFI
arch-chroot "${CHROOT_MOUNT}" bash -c "
    # Reconfigure mkinitcpio due to LUKS + LVM
    sed --in-place 's/^\s*MODULES.*/${LUKS_LVM_MKINITCPIO_MODULES}/g' /etc/mkinitcpio.conf
    sed --in-place 's/^\s*HOOKS.*/${LUKS_LVM_MKINITCPIO_HOOKS}/g' /etc/mkinitcpio.conf
    mkinitcpio --allpresets

    # Add kernel boot params for LUKS
    sed --in-place 's#.*GRUB_CMDLINE_LINUX_DEFAULT.*#GRUB_CMDLINE_LINUX_DEFAULT=\"${LUKS_KERNEL_BOOT_PARAM}\"#g' /etc/default/grub
    # Install GRUB bootloader
    grub-install --removable --recheck --modules='lvm part_gpt part_msdos' --target=${GRUB_TARGET} ${GRUB_INSTALL_PARAMS} ${DISK}
    grub-mkconfig --output /boot/grub/grub.cfg
"

# === CLEANUP ===

arch-chroot "${CHROOT_MOUNT}" bash -c "
    yes | pacman -S --clean --clean --noconfirm
"

# === DONE ===

echo -e "\n===>>> BASE INSTALLATION COMPLETE <<<===\n"
