#!/usr/bin/env bash
set -e

# === VARIABLES ===
: "${SET_HOSTNAME:=arch.localhost}"
: "${SET_KEYMAP:=us}"
: "${SET_LANGUAGE:=en_US.UTF-8}"
: "${SET_TIMEZONE:=UTC}"
: "${LUKS_PASSWORD:=vagrant}"
: "${ROOT_PASSWORD:=vagrant}"
: "${USER_NAME:=vagrant}"
: "${USER_PASSWORD:=vagrant}"

DISK_HELPER=$(lsblk --paths --output NAME,TYPE --sort NAME | grep disk | awk '{print $1}' | grep -E 'vd[a-z]$|sd[a-z]$|hd[a-z]$|nvme[0-9]+n[0-9]+$' | sort --reverse | tail -n1)
[[ -n "$DISK_HELPER" ]] || { echo "[E] No valid disk found"; exit 4; }
: "${DISK:=$DISK_HELPER}"
if [[ "${DISK}" = *nvme* ]] ; then
    : "${DISK_PART_BOOT:=${DISK}p1}"
    : "${DISK_PART_ROOT:=${DISK}p2}"
else
    : "${DISK_PART_BOOT:=${DISK}1}"
    : "${DISK_PART_ROOT:=${DISK}2}"
fi

set -u

CHROOT_MOUNT='/mnt'
BOOT_MOUNT='/boot'
LUKS_CONTAINER='luks_container'
LUKS_PATH="/dev/mapper/${LUKS_CONTAINER}"
LVM_VG='luks_root'
LVM_LV_ROOT='root'
LVM_ROOT_PATH="/dev/${LVM_VG}/${LVM_LV_ROOT}"
LUKS_LVM_MKINITCPIO_HOOKS='HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)'

# === DISK PREPARATION ===
echo "==> DISK PREPARATION"
umount -R "$CHROOT_MOUNT" &>/dev/null || true
cryptsetup close "$LUKS_CONTAINER" &>/dev/null || true

sgdisk --zap-all "${DISK}"
wipefs --all "${DISK}"
sgdisk --new=1:0:+512M --typecode=1:ef00 --change-name=1:"boot" "${DISK}"
sgdisk --new=2:0:0   --typecode=2:8300 --change-name=2:"root" "${DISK}"
mkfs.fat -F 32 "${DISK_PART_BOOT}"

echo "==> LVM ON LUKS SETUP"
echo -n "${LUKS_PASSWORD}" | cryptsetup luksFormat --type luks1 "${DISK_PART_ROOT}" -
echo -n "${LUKS_PASSWORD}" | cryptsetup open "${DISK_PART_ROOT}" "${LUKS_CONTAINER}"
pvcreate "${LUKS_PATH}"
vgcreate "${LVM_VG}" "${LUKS_PATH}"
lvcreate --extents 100%FREE --name "${LVM_LV_ROOT}" "${LVM_VG}"
mkfs.ext4 -F "${LVM_ROOT_PATH}"

mount "${LVM_ROOT_PATH}" "${CHROOT_MOUNT}"
mount --mkdir "${DISK_PART_BOOT}" "${CHROOT_MOUNT}${BOOT_MOUNT}"

LUKS_DEVICE_UUID="$(blkid -s UUID -o value ${DISK_PART_ROOT})"
LUKS_KERNEL_BOOT_PARAM="cryptdevice=UUID=${LUKS_DEVICE_UUID}:${LUKS_CONTAINER} root=${LVM_ROOT_PATH}"

echo "==> BASE INSTALLATION"
timedatectl set-ntp true
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacstrap -K "${CHROOT_MOUNT}" base base-devel linux linux-headers linux-firmware intel-ucode archlinux-keyring networkmanager vim openssh python lvm2 grub efibootmgr

genfstab -U "${CHROOT_MOUNT}" >> "${CHROOT_MOUNT}/etc/fstab"

# === SYSTEM CONFIGURATION (First Chroot) ===
echo "==> Configuring base system..."
arch-chroot "${CHROOT_MOUNT}" /bin/bash <<EOF
set -euxo pipefail

echo "${SET_HOSTNAME}" > /etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 ${SET_HOSTNAME}.localdomain ${SET_HOSTNAME}" > /etc/hosts
ln -sf /usr/share/zoneinfo/${SET_TIMEZONE} /etc/localtime
hwclock --systohc
echo "KEYMAP=${SET_KEYMAP}" > /etc/vconsole.conf
sed -i "s/#${SET_LANGUAGE}/${SET_LANGUAGE}/" /etc/locale.gen
locale-gen

echo "root:${ROOT_PASSWORD}" | chpasswd --crypt-method SHA512
useradd "${USER_NAME}" --create-home --user-group --groups wheel
echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd --crypt-method SHA512
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-wheel-sudo
chmod 440 /etc/sudoers.d/10-wheel-sudo
visudo --check --strict

systemctl enable NetworkManager
systemctl enable sshd
EOF

# === BOOTLOADER CONFIGURATION (Second Chroot) ===
echo "==> Configuring bootloader..."
arch-chroot "${CHROOT_MOUNT}" /bin/bash <<EOF
set -euxo pipefail

# 1. Fix mkinitcpio.conf
sed -i 's/^HOOKS=.*/'"${LUKS_LVM_MKINITCPIO_HOOKS}"'/' /etc/mkinitcpio.conf

# 2. Regenerate initramfs with the correct hooks
mkinitcpio -P

# 3. Fix GRUB config
sed -i "s#.*GRUB_CMDLINE_LINUX_DEFAULT.*#GRUB_CMDLINE_LINUX_DEFAULT=\"${LUKS_KERNEL_BOOT_PARAM}\"#g" /etc/default/grub
sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub

# 4. Install and generate final GRUB config
if systemd-detect-virt -q; then
    grub-install --target=x86_64-efi --efi-directory=${BOOT_MOUNT} --bootloader-id=GRUB --recheck --removable
else
    grub-install --target=x86_64-efi --efi-directory=${BOOT_MOUNT} --bootloader-id=GRUB --recheck
fi
grub-mkconfig -o ${BOOT_MOUNT}/grub/grub.cfg

# 5. Clean package cache
pacman -Scc --noconfirm
EOF

# === CLEANUP ===
echo "===>>> BASE INSTALLATION COMPLETE <<<==="
set +e
umount "${CHROOT_MOUNT}${BOOT_MOUNT}"
umount "${CHROOT_MOUNT}"
sleep 2
cryptsetup status "${LUKS_CONTAINER}" >/dev/null 2>&1 && cryptsetup close "${LUKS_CONTAINER}"
echo "==> Cleanup finished. Script complete."
