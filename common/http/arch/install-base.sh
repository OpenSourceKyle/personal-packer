#!/usr/bin/env bash
# Adapted from: https://github.com/conao3/packer-manjaro/blob/master/scripts/install-base.sh
# Reference: https://www.tecmint.com/arch-linux-installation-and-configuration-guide/
# Reference: https://github.com/badele/archlinux-auto-install/blob/main/install/install.sh

set -eu
set -x

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
    echo "(U)EFI required for this installation. Exiting..."
    return 1
fi

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
yes | pacstrap "${CHROOT_MOUNT}" base base-devel linux linux-firmware intel-ucode archlinux-keyring openssh dhcpcd python vim grub efibootmgr dosfstools os-prober mtools
# TODO: add to Ansible playbooks
# xdg-user-dirs xorg xorg-xinit i3

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
    systemctl enable dhcpcd.service sshd.service

    # Root
    usermod --password ${ROOT_PASSWORD_CRYPTED} root

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

# === DONE ===

echo -e "\n===>>> BASE INSTALLATION COMPLETE <<<===\n"
