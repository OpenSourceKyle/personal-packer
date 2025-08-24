#!/usr/bin/env bash

# Arch Linux Installation Script
# Charter: ArchScript Architect - Automated Arch Linux Installer
# Follows official Arch Linux Installation Guide strictly
# Supports both interactive and non-interactive modes with optional encryption

set -e  # Exit immediately if a command exits with a non-zero status

# =============================================================================
# GLOBAL VARIABLES AND DEFAULTS
# =============================================================================

# Script configuration
SCRIPT_NAME="$(basename "$0")"
NON_INTERACTIVE=false
UPDATE_KEYRING=false
ENABLE_ENCRYPTION=true

# Non-interactive mode defaults
DEFAULT_DISK="/dev/sda"
DEFAULT_HOSTNAME="archlinux"
DEFAULT_USERNAME="vagrant"
DEFAULT_PASSWORD="vagrant"
DEFAULT_ROOT_PASSWORD="vagrant"

# System variables
TARGET_DISK=""
HOSTNAME=""
USERNAME=""
PASSWORD=""
ROOT_PASSWORD=""
CPU_VENDOR=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

warning() {
    echo "[WARNING] $*" >&2
}

prompt_user() {
    local prompt="$1"
    local default="$2"
    local response
    
    if [[ -n "$default" ]]; then
        read -r -p "$prompt [$default]: " response
        echo "${response:-$default}"
    else
        read -r -p "$prompt: " response
        echo "$response"
    fi
}

prompt_password() {
    local prompt="$1"
    local password
    local password_confirm
    
    while true; do
        read -r -s -p "$prompt: " password
        echo
        read -r -s -p "Confirm password: " password_confirm
        echo
        
        if [[ "$password" == "$password_confirm" ]]; then
            echo "$password"
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

This script automates the installation of Arch Linux with optional full-disk encryption.

OPTIONS:
    --non-interactive    Run in non-interactive mode with default values
                        (disk: $DEFAULT_DISK, hostname: $DEFAULT_HOSTNAME, 
                         user: $DEFAULT_USERNAME, passwords: $DEFAULT_PASSWORD)
    --no-encryption     Disable full-disk encryption (LVM on LUKS)
                        Creates simple unencrypted ext4 root filesystem
    -u, --update-keyring Force update of archlinux-keyring before installation
    -h, --help          Show this help message

EXAMPLES:
    $SCRIPT_NAME                    # Interactive mode with encryption (default)
    $SCRIPT_NAME --no-encryption    # Interactive mode without encryption
    $SCRIPT_NAME --non-interactive  # Automated install with encryption
    $SCRIPT_NAME --non-interactive --no-encryption  # Automated install without encryption

EOF
}

# =============================================================================
# SAFETY CHECKS
# =============================================================================

check_archiso_environment() {
    log "Verifying Arch Linux live environment..."
    
    # Check if running in archiso environment
    if [[ ! -f /etc/arch-release ]] || [[ ! -f /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux ]]; then
        error "This script must be run within an official Arch Linux live environment (archiso)."
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
    fi
    
    # Check UEFI boot mode
    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        error "This script requires UEFI boot mode. Legacy BIOS is not supported."
    fi
    
    log "✓ Running in valid Arch Linux live environment with UEFI support"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --no-encryption)
                ENABLE_ENCRYPTION=false
                shift
                ;;
            -u|--update-keyring)
                UPDATE_KEYRING=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use -h for help."
                ;;
        esac
    done
}

# =============================================================================
# USER INPUT COLLECTION
# =============================================================================

collect_user_input() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        log "Running in non-interactive mode with default values..."
        TARGET_DISK="$DEFAULT_DISK"
        HOSTNAME="$DEFAULT_HOSTNAME"
        USERNAME="$DEFAULT_USERNAME"
        PASSWORD="$DEFAULT_PASSWORD"
        ROOT_PASSWORD="$DEFAULT_ROOT_PASSWORD"
        return
    fi
    
    echo
    echo "=== Arch Linux Installation Configuration ==="
    echo
    
    # Show available disks
    echo "Available disks:"
    lsblk -d -n -o NAME,SIZE,MODEL | grep -E '^sd|^nvme|^vd' | while read -r line; do
        echo "  /dev/$line"
    done
    echo
    
    # Get target disk
    while true; do
        TARGET_DISK=$(prompt_user "Enter target disk (e.g., /dev/sda)" "$DEFAULT_DISK")
        if [[ -b "$TARGET_DISK" ]]; then
            break
        else
            echo "Error: $TARGET_DISK is not a valid block device."
        fi
    done
    
    # Get hostname
    HOSTNAME=$(prompt_user "Enter hostname" "$DEFAULT_HOSTNAME")
    
    # Get username
    USERNAME=$(prompt_user "Enter username" "$DEFAULT_USERNAME")
    
    # Get passwords
    PASSWORD=$(prompt_password "Enter user password")
    ROOT_PASSWORD=$(prompt_password "Enter root password")
    
    # Show final configuration
    echo
    echo "=== Installation Summary ==="
    echo "Target disk: $TARGET_DISK"
    echo "Hostname: $HOSTNAME"
    echo "Username: $USERNAME"
    echo "Encryption: $([ "$ENABLE_ENCRYPTION" == "true" ] && echo "Enabled (LVM on LUKS)" || echo "Disabled")"
    echo
    
    # Final warning
    echo "WARNING: This will completely wipe $TARGET_DISK and all its data!"
    read -r -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Installation cancelled."
        exit 0
    fi
}

# =============================================================================
# SYSTEM PREPARATION
# =============================================================================

update_system_clock() {
    log "Updating system clock..."
    timedatectl set-ntp true
    sleep 2
    log "✓ System clock synchronized"
}

update_keyring() {
    if [[ "$UPDATE_KEYRING" == "true" ]]; then
        log "Updating archlinux-keyring..."
        pacman -Sy --noconfirm archlinux-keyring
        log "✓ Keyring updated"
    fi
}

enable_parallel_downloads() {
    log "Enabling parallel downloads in pacman..."
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    log "✓ Parallel downloads enabled"
}

detect_cpu_vendor() {
    log "Detecting CPU vendor..."
    if grep -q "AuthenticAMD" /proc/cpuinfo; then
        CPU_VENDOR="amd"
        log "✓ Detected AMD CPU"
    elif grep -q "GenuineIntel" /proc/cpuinfo; then
        CPU_VENDOR="intel"
        log "✓ Detected Intel CPU"
    else
        CPU_VENDOR="intel"  # Default fallback
        warning "Could not detect CPU vendor, defaulting to Intel"
    fi
}

# =============================================================================
# DISK OPERATIONS
# =============================================================================

partition_disk() {
    log "Partitioning disk $TARGET_DISK..."
    
    # Unmount any existing mounts
    umount -R /mnt 2>/dev/null || true
    
    # Wipe existing partition table and create GPT
    sgdisk --zap-all "$TARGET_DISK"
    sgdisk --clear "$TARGET_DISK"
    
    # Create partitions
    sgdisk --new=1:0:+1G --typecode=1:ef00 --change-name=1:"EFI System" "$TARGET_DISK"
    sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:"Linux Root" "$TARGET_DISK"
    
    # Inform kernel of partition table changes
    partprobe "$TARGET_DISK"
    sleep 2
    
    log "✓ Disk partitioned successfully"
}

setup_encryption() {
    if [[ "$ENABLE_ENCRYPTION" != "true" ]]; then
        return
    fi
    
    log "Setting up full-disk encryption (LVM on LUKS)..."
    
    local root_partition="${TARGET_DISK}2"
    if [[ "$TARGET_DISK" == *"nvme"* ]]; then
        root_partition="${TARGET_DISK}p2"
    fi
    
    # Setup LUKS2 container
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        echo -n "$PASSWORD" | cryptsetup luksFormat --type luks2 "$root_partition" -
    else
        echo "Enter encryption password for the root partition:"
        cryptsetup luksFormat --type luks2 "$root_partition"
    fi
    
    # Open LUKS container
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        echo -n "$PASSWORD" | cryptsetup open "$root_partition" cryptroot -
    else
        cryptsetup open "$root_partition" cryptroot
    fi
    
    # Setup LVM
    pvcreate /dev/mapper/cryptroot
    vgcreate vgarch /dev/mapper/cryptroot
    lvcreate -l 100%FREE vgarch -n root
    
    log "✓ Encryption and LVM setup completed"
}

format_filesystems() {
    log "Formatting filesystems..."
    
    local boot_partition="${TARGET_DISK}1"
    if [[ "$TARGET_DISK" == *"nvme"* ]]; then
        boot_partition="${TARGET_DISK}p1"
    fi
    
    # Format EFI partition
    mkfs.fat -F 32 "$boot_partition"
    
    # Format root partition
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        mkfs.ext4 /dev/vgarch/root
    else
        local root_partition="${TARGET_DISK}2"
        if [[ "$TARGET_DISK" == *"nvme"* ]]; then
            root_partition="${TARGET_DISK}p2"
        fi
        mkfs.ext4 "$root_partition"
    fi
    
    log "✓ Filesystems formatted"
}

mount_filesystems() {
    log "Mounting filesystems..."
    
    local boot_partition="${TARGET_DISK}1"
    if [[ "$TARGET_DISK" == *"nvme"* ]]; then
        boot_partition="${TARGET_DISK}p1"
    fi
    
    # Mount root
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        mount /dev/vgarch/root /mnt
    else
        local root_partition="${TARGET_DISK}2"
        if [[ "$TARGET_DISK" == *"nvme"* ]]; then
            root_partition="${TARGET_DISK}p2"
        fi
        mount "$root_partition" /mnt
    fi
    
    # Create and mount boot
    mkdir -p /mnt/boot
    mount "$boot_partition" /mnt/boot
    
    log "✓ Filesystems mounted"
}

# =============================================================================
# SYSTEM INSTALLATION
# =============================================================================

install_base_system() {
    log "Installing base system..."
    
    local microcode_package="${CPU_VENDOR}-ucode"
    
    pacstrap /mnt base base-devel linux linux-headers linux-firmware lvm2 \
        "$microcode_package" networkmanager iwd vim openssh python
    
    log "✓ Base system installed"
}

generate_fstab() {
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    log "✓ fstab generated"
}

# =============================================================================
# SYSTEM CONFIGURATION (CHROOT)
# =============================================================================

configure_system() {
    log "Configuring system in chroot..."
    
    # Create configuration script for chroot
    cat > /mnt/configure_system.sh << 'CHROOT_SCRIPT'
#!/bin/bash
set -e

# Configure timezone and locale
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Configure locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Configure hostname and hosts
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# Configure mkinitcpio
if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
else
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
fi
mkinitcpio -P

# Install and configure GRUB
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# Configure GRUB
if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    ROOT_UUID=$(blkid -s UUID -o value "${TARGET_DISK}2" || blkid -s UUID -o value "${TARGET_DISK}p2")
    sed -i "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$ROOT_UUID:cryptroot root=\/dev\/vgarch\/root\"/" /etc/default/grub
else
    ROOT_UUID=$(blkid -s UUID -o value "${TARGET_DISK}2" || blkid -s UUID -o value "${TARGET_DISK}p2")
    sed -i "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"root=UUID=$ROOT_UUID\"/" /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Enable parallel downloads in pacman
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create user and configure sudo
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Configure sudo for wheel group
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

# Enable services
systemctl enable NetworkManager
systemctl enable sshd

# Create swap file
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab

CHROOT_SCRIPT
    
    # Make script executable and pass variables
    chmod +x /mnt/configure_system.sh
    
    # Execute configuration in chroot with environment variables
    arch-chroot /mnt env \
        HOSTNAME="$HOSTNAME" \
        USERNAME="$USERNAME" \
        PASSWORD="$PASSWORD" \
        ROOT_PASSWORD="$ROOT_PASSWORD" \
        ENABLE_ENCRYPTION="$ENABLE_ENCRYPTION" \
        TARGET_DISK="$TARGET_DISK" \
        ./configure_system.sh
    
    # Clean up configuration script
    rm /mnt/configure_system.sh
    
    log "✓ System configuration completed"
}

# =============================================================================
# CLEANUP AND FINALIZATION
# =============================================================================

cleanup_and_unmount() {
    log "Cleaning up and unmounting filesystems..."
    
    # Unmount filesystems
    umount -R /mnt
    
    # Close LUKS container if encryption was used
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        cryptsetup close cryptroot
    fi
    
    log "✓ Cleanup completed"
}

# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================

main() {
    echo "========================================="
    echo "  Arch Linux Installation Script"
    echo "========================================="
    echo
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Safety checks
    check_archiso_environment
    
    # System preparation
    update_system_clock
    update_keyring
    enable_parallel_downloads
    detect_cpu_vendor
    
    # Collect user input
    collect_user_input
    
    # Disk operations
    partition_disk
    setup_encryption
    format_filesystems
    mount_filesystems
    
    # System installation
    install_base_system
    generate_fstab
    configure_system
    
    # Finalization
    cleanup_and_unmount
    
    echo
    echo "========================================="
    echo "  Installation completed successfully!"
    echo "========================================="
    echo
    echo "System details:"
    echo "  Hostname: $HOSTNAME"
    echo "  Username: $USERNAME"
    echo "  Encryption: $([ "$ENABLE_ENCRYPTION" == "true" ] && echo "Enabled" || echo "Disabled")"
    echo "  Boot partition: ${TARGET_DISK}1"
    echo "  Root partition: ${TARGET_DISK}2"
    echo
    echo "You can now reboot into your new Arch Linux system."
    echo "Remove the installation media before rebooting."
    echo
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        echo "Default credentials (non-interactive mode):"
        echo "  Root password: $DEFAULT_PASSWORD"
        echo "  User password: $DEFAULT_PASSWORD"
        echo
    fi
}

# Execute main function with all arguments
main "$@"