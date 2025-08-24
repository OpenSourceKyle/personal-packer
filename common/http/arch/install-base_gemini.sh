#!/usr/bin/env bash
#
# ArchScript Architect: Arch Linux Installation Script Generator
#
# This script automates the installation of Arch Linux on a UEFI system.
# It provides both an interactive mode for guided setup and a non-interactive
# mode for fully automated deployments.
#
# Features:
#   - UEFI support only.
#   - Interactive and Non-Interactive execution modes.
#   - Default full-disk encryption (LVM on LUKS).
#   - Option to disable encryption for a standard setup.
#   - Adherence to the official Arch Linux Installation Guide.
#
# Usage:
#   ./install.sh [options]
#
# Options:
#   --non-interactive   Run in non-interactive mode with default settings.
#                       (User: vagrant, Password: vagrant)
#   --no-encryption     Disable full-disk encryption.
#   -u, --update-keyring Force an update of the archlinux-keyring package.
#

set -e

# --- Configuration and Variables ---
INTERACTIVE_MODE=true
ENCRYPTION_ENABLED=true
UPDATE_KEYRING=false

# Non-interactive mode defaults
DEFAULT_USER="vagrant"
DEFAULT_PASSWORD="vagrant"
DEFAULT_HOSTNAME="archlinux"
TARGET_DISK=""

# --- Helper Functions ---
log_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    exit 1
}

# --- Pre-flight Checks ---

# 1. Safety Check: Verify running in Arch Linux live environment.
if ! grep -q "Arch Linux" /etc/os-release; then
    log_error "This script must be run within an official Arch Linux live environment."
fi

# Verify UEFI boot mode. [4]
if [ ! -d /sys/firmware/efi/efivars ]; then
    log_error "System not booted in UEFI mode. This script is for UEFI-based systems only."
fi

# Check for internet connectivity. [4]
if ! ping -c 1 archlinux.org &> /dev/null; then
    log_error "No internet connection. Please connect to the internet before running this script."
fi

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --non-interactive)
            INTERACTIVE_MODE=false
            log_info "Non-interactive mode enabled."
            shift
            ;;
        --no-encryption)
            ENCRYPTION_ENABLED=false
            log_info "Disk encryption has been disabled."
            shift
            ;;
        -u|--update-keyring)
            UPDATE_KEYRING=true
            log_info "Arch Linux keyring will be updated."
            shift
            ;;
        *)
            log_error "Unknown parameter passed: $1"
            ;;
    esac
done

# --- Main Logic ---

# In non-interactive mode, we need a target disk.
if [ "$INTERACTIVE_MODE" = false ]; then
    log_warn "Non-interactive mode requires the target disk to be set in the script."
    # In a real-world scenario, you might pass the disk as an argument.
    # For this example, we'll assume the first non-loop, non-cdrom device.
    TARGET_DISK=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print "/dev/"$1; exit}')
    if [ -z "$TARGET_DISK" ]; then
        log_error "Could not automatically determine a target disk in non-interactive mode."
    fi
    log_info "Using target disk: $TARGET_DISK"
fi

# Optional Keyring Update
if [ "$UPDATE_KEYRING" = true ]; then
    log_info "Updating archlinux-keyring..."
    pacman -Sy --noconfirm archlinux-keyring
fi

# Interactive Mode: User Prompts
if [ "$INTERACTIVE_MODE" = true ]; then
    lsblk
    read -p "Enter the target disk (e.g., /dev/sda): " TARGET_DISK
    if [ ! -b "$TARGET_DISK" ]; then
        log_error "Invalid disk specified."
    fi

    read -p "Enter hostname: " HOSTNAME
    read -sp "Enter root password: " ROOT_PASSWORD
    echo
    read -sp "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo
    if [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]; then
        log_error "Root passwords do not match."
    fi

    read -p "Enter username for the new user: " USERNAME
    read -sp "Enter password for $USERNAME: " USER_PASSWORD
    echo
    read -sp "Confirm password for $USERNAME: " USER_PASSWORD_CONFIRM
    echo
    if [ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]; then
        log_error "User passwords do not match."
    fi

    if [ "$ENCRYPTION_ENABLED" = true ]; then
        read -sp "Enter disk encryption passphrase: " ENCRYPTION_PASSWORD
        echo
        read -sp "Confirm disk encryption passphrase: " ENCRYPTION_PASSWORD_CONFIRM
        echo
        if [ "$ENCRYPTION_PASSWORD" != "$ENCRYPTION_PASSWORD_CONFIRM" ]; then
            log_error "Encryption passphrases do not match."
        fi
    fi

    log_warn "This script will wipe all data on $TARGET_DISK."
    read -p "Are you sure you want to continue? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        log_info "Installation aborted."
        exit 0
    fi
else
    # Assign default values for non-interactive mode
    HOSTNAME=$DEFAULT_HOSTNAME
    ROOT_PASSWORD=$DEFAULT_PASSWORD
    USERNAME=$DEFAULT_USER
    USER_PASSWORD=$DEFAULT_PASSWORD
    ENCRYPTION_PASSWORD=$DEFAULT_PASSWORD
fi

# --- Disk Partitioning ---
log_info "Partitioning disk $TARGET_DISK..."
sgdisk --zap-all "$TARGET_DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI System Partition" "$TARGET_DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux Filesystem" "$TARGET_DISK"
partprobe "$TARGET_DISK"
sleep 2

EFI_PARTITION="${TARGET_DISK}1"
ROOT_PARTITION="${TARGET_DISK}2"
if [[ "$TARGET_DISK" == /dev/nvme* ]]; then
    EFI_PARTITION="${TARGET_DISK}p1"
    ROOT_PARTITION="${TARGET_DISK}p2"
fi

# --- Encryption and LVM Setup (Default Path) ---
if [ "$ENCRYPTION_ENABLED" = true ]; then
    log_info "Setting up LVM on LUKS..."
    echo -n "$ENCRYPTION_PASSWORD" | cryptsetup luksFormat --type luks2 "$ROOT_PARTITION" -
    echo -n "$ENCRYPTION_PASSWORD" | cryptsetup open "$ROOT_PARTITION" cryptlvm -

    pvcreate /dev/mapper/cryptlvm
    vgcreate vg0 /dev/mapper/cryptlvm
    lvcreate -l 100%FREE vg0 -n root
    ROOT_DEVICE="/dev/vg0/root"
else
    log_info "Skipping encryption setup."
    ROOT_DEVICE="$ROOT_PARTITION"
fi

# --- Filesystem Formatting ---
log_info "Formatting filesystems..."
mkfs.fat -F32 "$EFI_PARTITION"
mkfs.ext4 "$ROOT_DEVICE"

# --- Mount Filesystems ---
log_info "Mounting filesystems..."
mount "$ROOT_DEVICE" /mnt
mount --mkdir "$EFI_PARTITION" /mnt/boot

# --- System Installation ---
log_info "Enabling parallel downloads in pacman..."
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

log_info "Installing base system and packages..."
CPU_VENDOR=$(grep -m 1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
UCODE_PACKAGE="intel-ucode"
if [ "$CPU_VENDOR" == "AuthenticAMD" ]; then
    UCODE_PACKAGE="amd-ucode"
fi

pacstrap /mnt base base-devel linux linux-headers linux-firmware lvm2 "$UCODE_PACKAGE" networkmanager iwd vim openssh python

# --- System Configuration ---
log_info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

log_info "Chrooting into the new system to continue configuration..."

# Create a configuration script to be executed inside the chroot
cat > /mnt/chroot-script.sh <<EOF
set -e

# --- Inside Chroot Configuration ---

# Timezone and Locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# mkinitcpio
if [ "$ENCRYPTION_ENABLED" = true ]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
fi
mkinitcpio -P

# GRUB Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
ROOT_UUID=\$(blkid -s UUID -o value $ROOT_DEVICE)
if [ "$ENCRYPTION_ENABLED" = true ]; then
    ENCRYPTED_PART_UUID=\$(blkid -s UUID -o value $ROOT_PARTITION)
    sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=".*"|GRUB_CMDLINE_LINUX_DEFAULT="quiet cryptdevice=UUID=\$ENCRYPTED_PART_UUID:cryptlvm root=/dev/vg0/root"|' /etc/default/grub
else
    sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=".*"|GRUB_CMDLINE_LINUX_DEFAULT="quiet root=UUID=\$ROOT_UUID"|' /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg

# User Management
echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel

# System Services
systemctl enable NetworkManager
systemctl enable sshd

# Swap File
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

EOF

# Pass variables to the chroot script
chmod +x /mnt/chroot-script.sh
arch-chroot /mnt /bin/bash -c "ENCRYPTION_ENABLED=$ENCRYPTION_ENABLED ROOT_PARTITION=$ROOT_PARTITION ROOT_DEVICE=$ROOT_DEVICE HOSTNAME='$HOSTNAME' ROOT_PASSWORD='$ROOT_PASSWORD' USERNAME='$USERNAME' USER_PASSWORD='$USER_PASSWORD' /chroot-script.sh"

# --- Cleanup and Finalization ---
rm /mnt/chroot-script.sh
umount -R /mnt

log_info "Installation complete. You can now reboot the system."