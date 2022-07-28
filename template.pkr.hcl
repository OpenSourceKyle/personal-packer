# --- Baseline configurations ---

# https://www.packer.io/plugins/builders/qemu
source "qemu" "baseline" {
  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size
  headless  = var.dont_display_gui

  http_directory = var.http_directory

  communicator           = "ssh"
  ssh_username           = var.vm_username
  ssh_password           = var.vm_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_attempts

  shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
  shutdown_timeout = var.shutdown_timeout

  iso_target_path = "iso_file"
}

# https://www.packer.io/plugins/builders/virtualbox/iso
source "virtualbox-iso" "baseline" {
  cpus      = var.cpus
  firmware  = "efi"
  memory    = var.memory
  disk_size = var.disk_size
  headless  = var.dont_display_gui

  http_directory = var.http_directory

  communicator           = "ssh"
  ssh_username           = var.vm_username
  ssh_password           = var.vm_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_attempts

  shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
  shutdown_timeout = var.shutdown_timeout

  iso_target_path = "iso_file"
}

# --- Build Blocks ---

build {

  # Arch - QEMU (KVM) 
  source "qemu.baseline" {
    name             = "arch"
    vm_name          = "packer_arch.img"
    output_directory = "YOUR_BUILT_VM-arch-qemu"
    boot_command     = var.boot_command_arch
    boot_wait        = var.boot_wait_arch
    # NOTE: ISO must be downloaded to $CWD or the ISO will be downloaded
    iso_url      = var.iso_arch
    iso_checksum = var.iso_arch_hash
  }

  # Arch - Virtualbox
  source "virtualbox-iso.baseline" {
    name             = "arch"
    guest_os_type    = "ArchLinux_64"
    vm_name          = "packer_arch.img"
    output_directory = "YOUR_BUILT_VM-arch-virtualbox"
    boot_command     = var.boot_command_arch
    boot_wait        = var.boot_wait_arch
    # NOTE: ISO must be downloaded to $CWD or the ISO will be downloaded
    iso_url      = var.iso_arch
    iso_checksum = var.iso_arch_hash
  }

  # Kali - QEMU (KVM) 
  source "qemu.baseline" {
    name             = "kali"
    vm_name          = "packer_kali.img"
    output_directory = "YOUR_BUILT_VM-kali-qemu"
    boot_command     = var.boot_command_debian_kali
    boot_wait        = var.boot_wait_debian_kali
    # NOTE: ISO must be downloaded to $CWD or the ISO will be downloaded
    iso_url      = var.iso_kali
    iso_checksum = var.iso_kali_hash
  }

  # Kali - Virtualbox
  source "virtualbox-iso.baseline" {
    name             = "kali"
    guest_os_type    = "Debian_64"
    vm_name          = "packer_kali.img"
    output_directory = "YOUR_BUILT_VM-kali-virtualbox"
    boot_command     = var.boot_command_debian_kali
    boot_wait        = var.boot_wait_debian_kali
    # NOTE: ISO must be downloaded to $CWD or the ISO will be downloaded
    iso_url      = var.iso_kali
    iso_checksum = var.iso_kali_hash
  }

  # --- Provision post-building ---

  # Create ~/.ssh directory
  provisioner "shell" {
    inline = ["rm -rf ~/.ssh/", "mkdir ~/.ssh"]
  }
  # Copy in pre-built keys
  provisioner "file" {
    sources     = ["./common/ssh_keys_for_packer/"]
    destination = "~/.ssh/"
  }
  # Ensure SSH keys permissions are correct & passwordless sudo user exists
  provisioner "shell" {
    inline = ["echo '${var.vm_password}' | sudo -S /bin/sh -c 'echo \"${var.vm_username} ALL=(ALL) NOPASSWD: ALL\" | tee /etc/sudoers.d/11_passwordless_sudo_user && chmod 440 /etc/sudoers.d/11_passwordless_sudo_user && visudo -c'", "chmod 700 ~/.ssh", "chmod 644 -R ~/.ssh/*", "chmod 600 ~/.ssh/id_rsa", "chmod g-w,o-w ~", "touch ~/VM_CREATED_ON_\"$(date +%Y-%m-%d_%H-%M-%S)\""]
  }
  provisioner "shell" {
    # only            = ["*.arch"]
    only            = ["virtualbox-iso.arch"]
    execute_command = "sudo --preserve-env bash '{{ .Path }}'"
    script          = "common/http/arch/install-base.sh"
  }
  # Perform full system update/upgrade
  # NOTE: this will take some time on rolling-updates OSes
  provisioner "shell" {
    only   = ["*.kali"]
    inline = [var.full_system_upgrade_command_debian_kali]
  }
}
