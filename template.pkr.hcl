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
  vboxmanage_post = [
    # Add bridged adapters for default Ethernet and WiFi (in addition to existing NAT)
    ["modifyvm", "{{.Name}}", "--nic2", "bridged", "--bridgeadapter2", "enp3s0"],
    ["modifyvm", "{{.Name}}", "--nic3", "bridged", "--bridgeadapter3", "wlp2s0"],
    # Disable Remote Display
    ["modifyvm", "{{.Name}}", "--vrde", "off"],
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
    output_directory = "YOUR_BUILT_VM-arch-qemu"
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
    output_directory = "YOUR_BUILT_VM-arch-virtualbox"
    boot_command     = var.boot_command_arch
    boot_wait        = var.boot_wait_arch
    shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
    iso_url          = var.iso_arch
    iso_checksum     = var.iso_arch_hash
  }

  # Kali - QEMU (KVM) 
  source "qemu.baseline" {
    name             = "kali"
    vm_name          = "packer_kali.img"
    output_directory = "YOUR_BUILT_VM-kali-qemu"
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
    output_directory = "YOUR_BUILT_VM-kali-virtualbox"
    boot_command     = var.boot_command_debian_kali
    boot_wait        = var.boot_wait_debian_kali
    shutdown_command = "echo '${var.vm_password}' | sudo --stdin shutdown --poweroff now"
    iso_url          = var.iso_kali
    iso_checksum     = var.iso_kali_hash
  }

#  # Win_10 - VirtualBox
#  source "virtualbox-iso.baseline" {
#    name             = "win_10"
#    guest_os_type    = "Windows10_64"
#    output_directory = "YOUR_BUILT_VM-win_10-virtualbox"
#    floppy_files = [
#      "${var.autounattend_win_10}",
#      "./common/scripts/fixnetwork.ps1",
#      "./common/scripts/microsoft-updates.bat",
#      "./common/scripts/win-updates.ps1",
#      "./common/scripts/openssh.ps1"
#    ]
#    ssh_wait_timeout = "2h"
#    iso_checksum     = "${var.iso_win_10_checksum}"
#    iso_url          = "${var.iso_win_10}"
#    boot_command     = var.boot_command_win_10
#    boot_wait        = var.boot_wait_win_10
#    shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
#    vboxmanage = [
#      ["modifyvm", "{{ .Name }}", "--boot1", "dvd", "--boot2", "disk"],
#      #["modifyvm", "{{ .Name }}", "--memory", "${var.memory}"],
#      #["modifyvm", "{{ .Name }}", "--cpus", "${var.cpus}"],
#    ]
#  }

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
#  provisioner "shell" {
#    only            = ["virtualbox-iso.win_10"]
#    execute_command = "{{ .Vars }} cmd /c C:/Windows/Temp/script.bat"
#    remote_path     = "/tmp/script.bat"
#    scripts = [
#      "./common/scripts/vm-guest-tools.bat",
#      "./common/scripts/vagrant-ssh.bat",
#      "./common/scripts/disable-auto-logon.bat",
#      "./common/scripts/enable-rdp.bat",
#      "./common/scripts/compile-dotnet-assemblies.bat",
#      "./common/scripts/compact.bat"
#    ]
#  }
}
