# https://www.packer.io/docs/templates/hcl_templates/variables
# packer validate .

variable "iso_kali" {
  type    = string
  default = "https://kali.download/base-images/current/kali-linux-2022.2-installer-amd64.iso"
}
variable "iso_kali_hash" {
  type    = string
  default = "file:https://kali.download/base-images/current/SHA256SUMS"
}

variable "iso_arch" {
  type    = string
  default = "https://mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
}

variable "iso_arch_hash" {
  type    = string
  default = "file:https://mirrors.edge.kernel.org/archlinux/iso/latest/sha256sums.txt"
}

# --- Local Builds only ---

# overwrite this with a path to build VM elsewhere
# NOTE: mind any slashes...
variable "output_location" {
  type    = string
  default = "YOUR_BUILD_VM-"
}

# Do NOT show GUI during OS installation (headless mode)
variable "dont_display_gui" {
  type    = bool
  default = true
}

# --- RECOMMENDED TO NOT CHANGE --- 

# Boot Command: https://www.debian.org/releases/stable/amd64/apbs02#preseed-aliases
# Boot Command: https://hands.com/d-i/
# Removed due to local networking limitations:
# "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian_kali/preseed.cfg ",
variable "boot_command_debian_kali" {
  type = list(string)
  default = [
    "<esc><wait>",
    "DEBCONF_DEBUG=5 ",
    "auto ",
    "url=https://gitlab.com/thebwitty/packer/-/raw/main/common/http/debian_kali/preseed.cfg ",
    "debian-installer=en_US ",
    "locale=en_US ",
    "kbd-chooser/method=us ",
    "console-keymaps-at/keymap=us ",
    "keyboard-configuration/xkb-keymap=us ",
    "<enter><wait> "
  ]
}
variable "boot_wait_debian_kali" {
  type    = string
  default = "8s"
}

variable "full_system_upgrade_command_debian_kali" {
  type    = string
  default = "export DEBIAN_FRONTEND=noninteractive ; echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections ; sudo bash -E -c 'apt update --yes && yes | apt dist-upgrade --yes'"
}

variable "boot_command_arch" {
  type = list(string)
  default = [
    "<enter><wait60>",
    # Packer will try to get the SSH script locally first, and then will try (regardless of success)
    # to reach out to the internet to get the same script. Mitigates some weird, undiagnosed issue with
    # how Packer sets up VirtualBox VMs (since this is not a VBox problem when done manually)
    "curl --connect-timeout 5 --retry 1 --url http://{{ .HTTPIP }}:{{ .HTTPPort }}/arch/enable-ssh.sh --url https://gitlab.com/thebwitty/packer/-/raw/main/common/http/arch/enable-ssh.sh | bash",
    "<enter><wait5>"
  ]
}
variable "boot_wait_arch" {
  type    = string
  default = "5s"
}

variable "full_system_upgrade_command_arch" {
  type    = string
  default = "pacman -S --refresh --refresh --sysupgrade --noconfirm"
}

variable "virtualbox_firmware" {
  type    = string
  default = "efi"
}

variable "shared_folder_host_path" {
  type = string
  default = env("HOME")
}

# https://developer.hashicorp.com/packer/plugins/builders/virtualbox/iso#creating-an-efi-enabled-vm
variable "virtualbox_iso_interface" {
  type    = string
  default = "sata"
}

variable "http_directory" {
  type    = string
  default = "./common/http/"
}

variable "preeed_server_port_min" {
  type    = number
  default = 8500
}
variable "preeed_server_port_max" {
  type    = number
  default = 8505
}

variable "cpus" {
  type    = number
  default = 2
}
variable "cores" {
  type    = number
  default = 2
}
variable "memory" {
  type    = number
  default = 8192
}
variable "disk_size" {
  type    = number
  default = 40000
}
variable "ip_wait_timeout" {
  type    = string
  default = "30m"
}
variable "ip_settle_timeout" {
  type    = string
  default = "10s"
}
variable "ssh_timeout" {
  type    = string
  default = "30m"
}
variable "ssh_attempts" {
  type    = number
  default = 50
}
variable "shutdown_timeout" {
  type    = string
  default = "10m"
}
variable "vm_username" {
  type    = string
  default = "user"
}
variable "vm_password" {
  type      = string
  default   = "user"
  sensitive = true
}
