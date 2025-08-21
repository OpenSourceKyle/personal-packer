# ============================================================================
# PACKER TEMPLATE (QEMU ONLY)
# https://www.packer.io/plugins/builders/qemu
# ============================================================================
#
# Defines the Packer build process for a QEMU/libvirt Arch Linux box.
#
# Build with:
#   packer init .
#   packer build .
#
# ============================================================================

packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# ============================================================================
# SOURCE DEFINITION
# ============================================================================

source "qemu" "arch" {
  # Hardware
  cpus               = var.cpus
  memory             = var.memory
  disk_size          = var.disk_size
  headless           = var.dont_display_gui

  # ISO and Boot
  iso_url            = var.iso_arch
  iso_checksum       = var.iso_arch_hash
  http_directory     = var.http_directory
  boot_command       = var.boot_command_arch
  boot_wait          = var.boot_wait_arch
  shutdown_command   = "echo '${var.vm_password}' | sudo -S shutdown -P now"
  shutdown_timeout   = var.shutdown_timeout

  # Communicator
  communicator       = "ssh"
  ssh_username       = var.vm_username
  ssh_password       = var.vm_password
  ssh_timeout        = var.ssh_timeout
  
  # Output
  vm_name            = "packer_arch.qcow2"
  output_directory   = "${var.output_location}arch-qemu"
}

# ============================================================================
# BUILD BLOCK
# ============================================================================

build {
  # Tell Packer which source to build.
  sources = ["source.qemu.arch"]

  # --- PROVISIONING ---
  # These steps run inside the VM after SSH is available on the live ISO.

  # Step 1: Run the main OS installation script from your http directory.
  # This is a critical step to install Arch to the virtual disk.
  provisioner "shell" {
    execute_command = "echo '${var.vm_password}' | sudo -S -E bash -c '{{ .Vars }} {{ .Path }} --noninteractive'"
    script          = "common/http/arch/install-base.sh"
  }

  # Step 2: Configure the 'vagrant' user for Vagrant compatibility.
  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    inline = [
      "echo '==> Configuring passwordless sudo for vagrant user'",
      "echo '${var.vm_password}' | sudo -S /bin/sh -c 'echo \"${var.vm_username} ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/10-vagrant && chmod 440 /etc/sudoers.d/10-vagrant'",
      
      "echo \"==> Installing Vagrant's default insecure public SSH key\"",
      "mkdir -p /home/${var.vm_username}/.ssh",
      "chmod 700 /home/${var.vm_username}/.ssh",
      "curl -fsSLo /home/${var.vm_username}/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub",
      "chmod 600 /home/${var.vm_username}/.ssh/authorized_keys",
      "chown -R ${var.vm_username}:${var.vm_username} /home/${var.vm_username}/.ssh",
      
      "echo '==> Recording build time'",
      "touch /home/${var.vm_username}/.packer-build-time"
    ]
  }

  # --- POST-PROCESSING ---
  # Package the final image into a Vagrant box.
  post-processor "vagrant" {
    output = "${var.output_location}packer-arch-libvirt-{{timestamp}}.box"
  }
}
