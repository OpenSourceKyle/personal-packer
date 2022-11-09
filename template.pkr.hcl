# --- Baseline Configurations ---

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

  shutdown_timeout = var.shutdown_timeout

  iso_target_path = "iso_file"
}

# https://www.packer.io/plugins/builders/virtualbox/iso
source "virtualbox-iso" "baseline" {
  cpus                 = var.cpus
  memory               = var.memory
  disk_size            = var.disk_size
  guest_additions_mode = "disable"
  headless             = var.dont_display_gui

  http_directory = var.http_directory

  communicator           = "ssh"
  ssh_username           = var.vm_username
  ssh_password           = var.vm_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_attempts

  shutdown_timeout = var.shutdown_timeout

  iso_target_path = "iso_file"

  # https://wiki.archlinux.org/title/VirtualBox/Install_Arch_Linux_as_a_guest#Fullscreen_mode_shows_blank_screen
  gfx_controller = "vmsvga"
  gfx_vram_size  = "64"

  firmware        = var.virtualbox_firmware
  keep_registered = true
  vboxmanage = [
    # Disable PAE/NX
    ["modifyvm", "{{.Name}}", "--pae", "off"],
  ]
  vboxmanage_post = [
    # Add bridged adapters for default Ethernet and WiFi (in addition to existing NAT)
    ["modifyvm", "{{.Name}}", "--nic2", "bridged", "--bridgeadapter2", "enp3s0"],
    ["modifyvm", "{{.Name}}", "--cableconnected2", "off"],
    ["modifyvm", "{{.Name}}", "--nic3", "bridged", "--bridgeadapter3", "wlp2s0"],
    ["modifyvm", "{{.Name}}", "--cableconnected3", "off"],
    # Setup port forwarding: localhost:2222 -> guest_VM:22
    ["modifyvm", "{{.Name}}", "--nat-pf1", "forwarded_ssh,tcp,,2222,,22"],
    # Disable Remote Display
    ["modifyvm", "{{.Name}}", "--vrde", "off"],
    # Shared Folder setup
    ["sharedfolder", "add", "{{.Name}}", "--name", "1_sharedfolder", "--hostpath", "${var.shared_folder_host_path}/VirtualBox VMs/1_sharedfolder", "--automount"],
    # Snapshot VM
    ["snapshot", "{{.Name}}", "take", "CLEAN_BUILD", "--description=Clean build via Packer"],
  ]
}

# --- Build Blocks ---

build {

  # Arch - QEMU (KVM) 
  source "qemu.baseline" {
    name             = "arch"
    vm_name          = "packer_arch.img"
    output_directory = "${var.output_location}arch-qemu"
    boot_command     = var.boot_command_arch
    boot_wait        = var.boot_wait_arch
    shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
    iso_url          = var.iso_arch
    iso_checksum     = var.iso_arch_hash
  }

  # Arch - VirtualBox
  source "virtualbox-iso.baseline" {
    name             = "arch"
    guest_os_type    = "ArchLinux_64"
    vm_name          = "packer_arch.img"
    output_directory = "${var.output_location}arch-virtualbox"
    boot_command     = var.boot_command_arch
    boot_wait        = var.boot_wait_arch
    shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
    iso_url          = var.iso_arch
    iso_checksum     = var.iso_arch_hash
    # https://developer.hashicorp.com/packer/plugins/builders/virtualbox/iso#creating-an-efi-enabled-vm
    #iso_interface    = var.virtualbox_iso_interface
  }

  # Kali - QEMU (KVM) 
  source "qemu.baseline" {
    name             = "kali"
    vm_name          = "packer_kali.img"
    output_directory = "${var.output_location}kali-qemu"
    boot_command     = var.boot_command_debian_kali
    boot_wait        = var.boot_wait_debian_kali
    shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
    iso_url          = var.iso_kali
    iso_checksum     = var.iso_kali_hash
  }

  # Kali - VirtualBox
  source "virtualbox-iso.baseline" {
    name             = "kali"
    guest_os_type    = "Debian_64"
    vm_name          = "packer_kali.img"
    output_directory = "${var.output_location}kali-virtualbox"
    boot_command     = var.boot_command_debian_kali
    boot_wait        = var.boot_wait_debian_kali
    shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
    iso_url          = var.iso_kali
    iso_checksum     = var.iso_kali_hash
  }

  # --- Post-Building Provisioning ---

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
    inline = [
      "echo '${var.vm_password}' | sudo --stdin /bin/sh -c 'echo \"${var.vm_username} ALL=(ALL) NOPASSWD: ALL\" | tee /etc/sudoers.d/11_passwordless_sudo_user && chmod 440 /etc/sudoers.d/11_passwordless_sudo_user && visudo --check --strict'",
      "chmod 700 ~/.ssh",
      "chmod 644 --recursive ~/.ssh/*",
      "chmod 600 ~/.ssh/id_rsa",
      "chmod g-w,o-w ~",
      "touch ~/VM_CREATED_ON_\"$(date +%Y-%m-%d_%H-%M-%S)\""
    ]
  }
  provisioner "shell" {
    only            = ["virtualbox-iso.arch"]
    execute_command = "sudo --preserve-env bash -c '{{ .Vars}} {{ .Path }} --noninteractive #--update-archlinux-keyring'"
    script          = "common/http/arch/install-base.sh"
  }
  # Perform full system update/upgrade
  # NOTE: this will take some time on rolling-updates OSes
  provisioner "shell" {
    only   = ["*.kali"]
    inline = [var.full_system_upgrade_command_debian_kali]
  }
}
