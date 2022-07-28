#!/usr/bin/env bash
# Adapted from: https://github.com/conao3/packer-manjaro/blob/master/scripts/install-base.sh
# Reference: https://www.tecmint.com/arch-linux-installation-and-configuration-guide/
# Reference: https://github.com/badele/archlinux-auto-install/blob/main/install/install.sh

set -eux

# --- VARIABLES ---

# Discern main disk drive ending in "-da" to provision (QEMU & VBox compatible)
DISK=/dev/$(/usr/bin/lsblk --output NAME,TYPE | /usr/bin/grep disk | /usr/bin/awk '{print $1}' | /usr/bin/grep -E '.da')
DISK_PART_BOOT="${DISK}1"
DISK_PART_ROOT="${DISK}2"
CHROOT_MOUNT='/mnt'
CHROOT_MOUNT_BOOT="${CHROOT_MOUNT}/boot/EFI"
HOSTNAME='arch.localhost'

KEYMAP='us'
LANGUAGE='en_US.UTF-8'
TIMEZONE='US/Chicago'  # from /usr/share/zoneinfo/

ARCH_MIRROR_COUNTRY=${ARCH_MIRROR_COUNTRY:-US}
MIRRORLIST="https://archlinux.org/mirrorlist/?country=${ARCH_MIRROR_COUNTRY}&protocol=https&ip_version=4&use_mirror_status=on"

PASSWORD=$(/usr/bin/openssl passwd -crypt 'user')

# --- PRECHECKS ---

if [[ ! -e /sys/firmware/efi/efivars ]] ; then
    echo "(U)EFI required for this installation. Exiting..."
    return 1
fi

# --- ACTIONS ---

# Clearing partition table on ${DISK}
/usr/bin/sgdisk --zap ${DISK}

# Destroying magic strings and signatures on ${DISK}
/usr/bin/dd if=/dev/zero of=${DISK} bs=512 count=2048
/usr/bin/wipefs --all ${DISK}

# Create EFI partition: size, type EFI (ef00), named, attribute bootable
/usr/bin/sgdisk --new=1:0:+550M --typecode=1:ef00 --change-name=1:efi --attributes=1:set:2 ${DISK}
# Create root partition: remaining free space, type Linux (8300), named
/usr/bin/sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:root ${DISK}
/usr/bin/sgdisk -p ${DISK}

# Creating /boot filesystem (FAT32)
/usr/bin/mkfs.fat -F32 ${DISK_PART_BOOT}
# Creating /root filesystem (ext4)
/usr/bin/mkfs.ext4 -O ^64bit -F -m 0 -L root ${DISK_PART_ROOT}

# Mounting ${DISK_PART_ROOT} to ${CHROOT_MOUNT}
/usr/bin/mount ${DISK_PART_ROOT} ${CHROOT_MOUNT}

# Setting pacman ${ARCH_MIRROR_COUNTRY} mirrors
/usr/bin/curl -s "$MIRRORLIST" | /usr/bin/sed 's/^#Server/Server/' > /etc/pacman.d/mirrorlist

# Bootstrapping the base installation
/usr/bin/sed -i 's/.*ParallelDownloads.*/ParallelDownloads = 5/g' /etc/pacman.conf
/usr/bin/yes | /usr/bin/pacman -Syy --noconfirm archlinux-keyring
# Need to install netctl as well: https://github.com/archlinux/arch-boxes/issues/70
# Can be removed when user's Arch plugin will use systemd-networkd: https://github.com/hashicorp/vagrant/pull/11400
/usr/bin/yes | /usr/bin/pacstrap ${CHROOT_MOUNT} base base-devel linux archlinux-keyring gptfdisk openssh syslinux dhcpcd netctl python vim grub efibootmgr dosfstools os-prober mtools rng-tools
/usr/bin/genfstab -U -p ${CHROOT_MOUNT} >> ${CHROOT_MOUNT}/etc/fstab

# System configuration
/usr/bin/arch-chroot ${CHROOT_MOUNT} echo '${HOSTNAME}' > /etc/hostname
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
/usr/bin/arch-chroot ${CHROOT_MOUNT} echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/sed -i 's/#${LANGUAGE}/${LANGUAGE}/' /etc/locale.gen
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/locale-gen
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/mkinitcpio -p linux
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/usermod --password ${PASSWORD} root
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/systemctl enable dhcpcd@eth0.service
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/systemctl enable sshd.service
# Workaround for https://bugs.archlinux.org/task/58355 which prevents sshd to accept connections after reboot
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/systemctl enable rngd

/usr/bin/mount -o noatime,errors=remount-ro --mkdir ${DISK_PART_BOOT} ${CHROOT_MOUNT}/boot/efi
/usr/bin/arch-chroot ${CHROOT_MOUNT} ls -laR /boot/
# Install GRUB UEFI
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/grub-install --target=x86_64-efi --bootloader-id=boot --efi-directory=/boot/efi $DISK
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
# https://www.reddit.com/r/archlinux/comments/5mqheo/comment/dc6ufmq/?utm_source=reddit&utm_medium=web2x&context=3
# https://askubuntu.com/questions/566315/virtualbox-boots-only-in-uefi-interactive-shell
/usr/bin/arch-chroot ${CHROOT_MOUNT} /usr/bin/cp -rv /boot/efi/EFI/boot/grubx64.efi /boot/efi/EFI/boot/bootx64.efi
/usr/bin/arch-chroot ${CHROOT_MOUNT} ls -laR /boot/

echo "===>>> INSTALLATION COMPLETE <<<==="
