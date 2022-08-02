#!/usr/bin/env bash
# Adapted from: https://github.com/elasticdog/packer-arch/blob/master/scripts/install-base.sh
# Reference: https://www.tecmint.com/arch-linux-installation-and-configuration-guide/
# Reference: https://github.com/badele/archlinux-auto-install/blob/main/install/install.sh

set -e

# === VARIABLES ===

# TODO: SETUP manually setting of drive and partition variables (for SSD)

# Discern main disk drive to provision (QEMU & VBox compatible)
DISK=/dev/$(lsblk --output NAME,TYPE | grep disk | awk '{print $1}' | grep --extended-regexp '.da|nvme' | tail -n1)
DISK_PART_BOOT="${DISK}1"
DISK_PART_ROOT="${DISK}2"

HOSTNAME='arch.localhost'
KEYMAP='us'
LANGUAGE='en_US.UTF-8'
TIMEZONE='US/Chicago'  # from /usr/share/zoneinfo/

# https://stackoverflow.com/a/28085062
: "${ARCH_MIRROR_COUNTRY:=US}"

# Reference: https://unix.stackexchange.com/a/361789
# ROOT_PASSWORD="$(< /dev/urandom tr -cd '[:print:]' | head -c 20)" # generates random password
ROOT_PASSWORD="root"

USER_NAME='user'
USER_PASSWORD='user'

# --- do NOT modify ---

CHROOT_MOUNT='/mnt'
# Bootloader: ${EFI_DIR}/EFI/${BOOTLOADER_DIR}/grubx64.efi
EFI_DIR='/boot/efi'
BOOTLOADER_DIR='boot'

# TODO: Warning: truncating password to 8 characters
ROOT_PASSWORD_CRYPTED=$(openssl passwd -crypt "$ROOT_PASSWORD")
USER_PASSWORD_CRYPTED=$(openssl passwd -crypt "$USER_PASSWORD")

MIRRORLIST="https://archlinux.org/mirrorlist/?country=${ARCH_MIRROR_COUNTRY}&protocol=https&ip_version=4&use_mirror_status=on"

# === PRECHECKS ===

if [[ ! -e /sys/firmware/efi/efivars ]] ; then
    echo "[E] (U)EFI required for this installation. Exiting..."
    exit 1
else
    echo "[+] (U)EFI detected. continuing installation..."
fi

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
    echo "─HARDDRIVE :: DISK [$DISK]: " 
    read -r DISK
    echo "└─BOOT PARTITION :: DISK_PART_BOOT [$DISK_PART_BOOT]: "
    read -r DISK_PART_BOOT
    echo "└─ROOT PARTITION :: DISK_PART_ROOT [$DISK_PART_ROOT]: "
    read -r DISK_PART_ROOT
    echo

    yes_or_no "Values collected... Ready to continue?"
fi

set -u

# === DISK ===

# Clearing partition table on "${DISK}"
sgdisk --zap "${DISK}"

# Destroying magic strings and signatures on "${DISK}"
dd if=/dev/zero of="${DISK}" bs=512 count=2048
wipefs --all "${DISK}"

# Create EFI partition: size, type EFI (ef00), named, attribute bootable
sgdisk --new=1:0:+550M --typecode=1:ef00 --change-name=1:boot_efi --attributes=1:set:2 "${DISK}"
# Create root partition: remaining free space, type Linux (8300), named
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:root "${DISK}"
# Creating /boot filesystem (FAT32)
mkfs.fat -F32 -n BOOT_EFI "${DISK_PART_BOOT}"
# Creating /root filesystem (ext4)
mkfs.ext4 -O ^64bit -F -m 0 -L root "${DISK_PART_ROOT}"

# Mounting "${DISK_PART_ROOT}" to "${CHROOT_MOUNT}"
mount "${DISK_PART_ROOT}" "${CHROOT_MOUNT}"

# === SYSTEM CONFIG ===

# Setting pacman ${ARCH_MIRROR_COUNTRY} mirrors
curl --silent "${MIRRORLIST}" | sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist

# pacstrap installation
sed --in-place 's/.*ParallelDownloads.*/ParallelDownloads = 5/g' /etc/pacman.conf
yes | pacman -S --refresh --refresh --noconfirm archlinux-keyring
yes | pacstrap "${CHROOT_MOUNT}" base base-devel linux linux-headers linux-firmware intel-ucode archlinux-keyring dhcpcd vim openssh python grub efibootmgr dosfstools os-prober mtools

genfstab -U -p "${CHROOT_MOUNT}" > "${CHROOT_MOUNT}"/etc/fstab
arch-chroot "${CHROOT_MOUNT}" bash -c "
    # Machine
    echo ${HOSTNAME} > /etc/hostname
    ln --symbolic --force /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    hwclock --systohc
    timedatectl set-ntp true
    echo KEYMAP=${KEYMAP} > /etc/vconsole.conf
    sed --in-place s/#${LANGUAGE}/${LANGUAGE}/ /etc/locale.gen
    locale-gen
    systemctl enable dhcpcd sshd

    # Root
    usermod --password ${ROOT_PASSWORD_CRYPTED} root
    echo '%wheel ALL=(ALL) ALL' | tee -a /etc/sudoers && visudo -cs

    # User
    useradd $USER_NAME --create-home --user-group --password $USER_PASSWORD_CRYPTED --groups wheel
"

# === BOOT ===

# Mount boot drive
mount --options noatime,errors=remount-ro --mkdir "${DISK_PART_BOOT}" "${CHROOT_MOUNT}${EFI_DIR}"
# Install GRUB UEFI
arch-chroot "${CHROOT_MOUNT}" bash -c "
    grub-install --target=x86_64-efi --bootloader-id=${BOOTLOADER_DIR} --efi-directory=${EFI_DIR} ${DISK}
    grub-mkconfig --output /boot/grub/grub.cfg
    # Virtualbox UEFI Workaround: https://askubuntu.com/a/573672
    echo -E '\EFI\\${BOOTLOADER_DIR}\grubx64.efi' | tee ${EFI_DIR}/startup.nsh
"

# === CLEANUP ===

yes | pacman -S --clean --clean --noconfirm

# === DONE ===

echo -e "\n===>>> BASE INSTALLATION COMPLETE <<<===\n"
