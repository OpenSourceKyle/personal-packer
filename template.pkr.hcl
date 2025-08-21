packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "arch" {
  cpus               = 2
  memory             = 4096
  disk_size          = 40000
  headless           = false

  iso_url            = "https://mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
  iso_checksum   = "file:https://mirrors.edge.kernel.org/archlinux/iso/latest/sha256sums.txt"

  http_directory     = "./common/http/"
  
  efi_boot = true
  efi_firmware_code = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
  efi_firmware_vars = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
  
  boot_command       = [
    "<wait10s>",
    "fs0:\\efi\\boot\\bootx64.efi<enter>",
    "<wait60s>",
    "curl -fsSL http://{{ .HTTPIP }}:{{ .HTTPPort }}/arch/enable-ssh.sh | bash",
    "<enter>"
  ]
  boot_wait          = "10s"
  
  shutdown_command   = "echo 'vagrant' | sudo -S shutdown -P now"
  shutdown_timeout   = "10m"

  communicator       = "ssh"
  ssh_username       = "vagrant"
  ssh_password       = "vagrant"
  ssh_timeout        = "30m"
  
  vm_name            = "packer_arch.qcow2"
  output_directory   = "output/arch-qemu"
}

build {
  sources = ["source.qemu.arch"]

  provisioner "shell" {
    execute_command = "echo 'vagrant' | sudo -S -E bash -c '{{ .Vars }} {{ .Path }} --noninteractive'"
    script          = "common/http/arch/install-base.sh"
  }

  post-processor "vagrant" {
    output = "output/packer-arch-libvirt.box"
  }
}
