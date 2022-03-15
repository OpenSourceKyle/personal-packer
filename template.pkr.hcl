# Top-level, baseline configurations for local builds
source "vmware-iso" "baseline" {
  cpus          = var.cpus
  cores         = var.cores
  memory        = var.memory
  disk_size     = var.disk_size
  guest_os_type = "ubuntu-64"
  network       = "nat"
  headless      = var.dont_display_gui

  http_directory = var.http_directory

  communicator           = "ssh"
  ssh_username           = var.vm_username
  ssh_password           = var.vm_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_attempts

  shutdown_command = "echo '${var.vm_password}' | sudo -S shutdown -P now"
  shutdown_timeout = var.shutdown_timeout
}
# Top-level, baseline configurations for vSphere builds
source "vsphere-iso" "baseline" {
  vcenter_server      = var.vsphere_hostname
  username            = var.vsphere_user
  password            = var.vsphere_password
  host                = var.vsphere_host
  cluster             = var.vsphere_cluster
  datastore           = var.vsphere_datastore
  folder              = var.vsphere_vm_path
  insecure_connection = true

  guest_os_type   = "debian10_64Guest"
  CPUs            = var.cpus
  cpu_cores       = var.cores
  RAM             = var.memory
  RAM_reserve_all = true

  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  http_directory = var.http_directory
  http_ip        = var.preseed_server_ip
  http_port_min  = var.preeed_server_port_min
  http_port_max  = var.preeed_server_port_max

  ip_wait_timeout        = var.ip_wait_timeout
  ip_settle_timeout      = var.ip_settle_timeout
  communicator           = "ssh"
  ssh_username           = var.vm_username
  ssh_password           = var.vm_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_attempts

  shutdown_command = "echo '${var.vm_password}' | sudo -S shutdown -P now"
  shutdown_timeout = var.shutdown_timeout

  create_snapshot = true

  # ENABLE copy&paste (requires "open-vm-tools-desktop" package)
  # https://www.packer.io/docs/builders/vmware/vsphere-iso#configuration_parameters
  configuration_parameters = {
    # https://kb.vmware.com/s/article/57122
    "isolation.tools.copy.disable"         = "FALSE"
    "isolation.tools.paste.disable"        = "FALSE"
    "isolation.tools.setGUIOptions.enable" = "TRUE"
  }
}

# --- Actual Build Blocks ---

build {
  # Kali - vSphere
  source "vsphere-iso.baseline" {
    name         = "kali_2021"
    vm_name      = "packer_kali_2021"
    boot_command = var.boot_command_debian_kali
    boot_wait    = var.boot_wait_debian_kali
    # NOTE: vSphere Storage path for the ISO
    iso_paths    = var.iso_kali_vsphere
    iso_checksum = var.iso_kali_hash
  }
  # Kali - local
  source "vmware-iso.baseline" {
    name             = "kali_2021"
    vm_name          = "packer_kali_2021"
    output_directory = "YOUR_BUILT_VM-kali_2021"
    boot_command     = var.boot_command_debian_kali
    boot_wait        = var.boot_wait_debian_kali
    # NOTE: ISO must be downloaded to $CWD or the ISO will be downloaded
    iso_urls     = var.iso_kali
    iso_checksum = var.iso_kali_hash
  }
  # Debian - vSphere
  source "vsphere-iso.baseline" {
    name         = "debian_10"
    vm_name      = "packer_debian_10"
    boot_command = var.boot_command_debian_kali
    boot_wait    = var.boot_wait_debian_kali
    # NOTE: vSphere Storage path for the ISO
    iso_paths    = var.iso_debian_vsphere
    iso_checksum = var.iso_debian_hash
  }
  # Debian - local 
  source "vmware-iso.baseline" {
    name             = "debian_10"
    vm_name          = "packer_debian_10"
    output_directory = "YOUR_BUILT_VM-debian_10"
    boot_command     = var.boot_command_debian_kali
    boot_wait        = var.boot_wait_debian_kali
    # NOTE: vSphere Storage path for the ISO
    iso_urls     = var.iso_debian
    iso_checksum = var.iso_debian_hash
  }
  # --- Provision to enable Ansible configuration later ---
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
    inline = ["echo '${var.vm_password}' | sudo -S /bin/sh -c 'echo \"${var.vm_username} ALL=(ALL) NOPASSWD: ALL\" | tee -a /etc/sudoers && visudo -c'", "chmod 700 ~/.ssh", "chmod 644 -R ~/.ssh/*", "chmod 600 ~/.ssh/id_rsa", "chmod g-w,o-w ~", "touch ~/VM_CREATED_ON_\"$(date +%Y-%m-%d_%H-%M-%S)\""]
  }
  # Perform full system update/upgrade
  # NOTE: this will take some time on rolling-updates OSes
  provisioner "shell" {
    inline = [var.full_system_upgrade_command_debian_kali]
  }
}
