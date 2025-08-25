packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

locals {
  box_name      = "arch-box"
  box_version   = "1.0.0"
  box_provider  = "libvirt"
  output_dir    = "output-arch"
  disk_size_gib = 40
}

source "qemu" "arch" {
  cpus              = 2
  memory            = 4096
  disk_size         = local.disk_size_gib * 1024
  headless          = true
  iso_url           = "https://mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
  iso_checksum      = "file:https://mirrors.edge.kernel.org/archlinux/iso/latest/sha256sums.txt"
  http_directory    = "."
  efi_boot          = true
  efi_firmware_code = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
  efi_firmware_vars = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
  boot_command = [
    "<wait10s>", "fs0:\\efi\\boot\\bootx64.efi", "<enter>", "<wait5s>", "<enter>", "<wait45s>",
    "curl -fsSL http://{{ .HTTPIP }}:{{ .HTTPPort }}/enable-ssh.sh | bash", "<enter>"
  ]
  boot_wait        = "10s"
  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"
  shutdown_timeout = "10m"
  communicator     = "ssh"
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "30m"
  vm_name          = "box"
  output_directory = local.output_dir
  format           = "qcow2"
}

build {
  sources = ["source.qemu.arch"]

  provisioner "shell" {
    execute_command = "echo 'vagrant' | sudo -S -E bash -c '{{ .Vars }} {{ .Path }} --non-interactive'"
    script          = "install-base.sh"
  }

  post-processor "vagrant" {
    output              = "${local.output_dir}/${local.box_name}-${local.box_provider}-${local.box_version}.box"
    architecture        = "amd64"
    compression_level   = 6
    keep_input_artifact = true
  }
}
