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

variable "iso_win_10" {
  type    = string
  default = "http://download.microsoft.com/download/C/3/9/C399EEA8-135D-4207-92C9-6AAB3259F6EF/10240.16384.150709-1700.TH1_CLIENTENTERPRISEEVAL_OEMRET_X64FRE_EN-US.ISO"
}

variable "iso_win_10_checksum" {
  type    = string
  default = "sha1:56ab095075be28a90bc0b510835280975c6bb2ce"
}

variable "autounattend_win_10" {
  type    = string
  default = "./common/answer_files/10/autounattend.xml"
}

# --- Local Builds only ---

# Do NOT show GUI during OS installation (headless mode)
variable "dont_display_gui" {
  type    = bool
  default = true
}

# --- RECOMMENDED TO NOT CHANGE --- 

# Boot Command: https://www.debian.org/releases/stable/amd64/apbs02#preseed-aliases
variable "boot_command_debian_kali" {
  type = list(string)
  default = [
    "<esc><wait> ",
    "auto ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian_kali/preseed.cfg ",
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
    "curl --silent http://{{ .HTTPIP }}:{{ .HTTPPort }}/arch/enable-ssh.sh | bash -x",
    "<enter><wait5>"
  ]
}
variable "boot_wait_arch" {
  type    = string
  default = "5s"
}

variable "boot_command_win_10" {
  type = list(string)
  default = [
    "<wait1><enter><wait1>",
  ]
}
variable "boot_wait_win_10" {
  type    = string
  default = "1s"
}
variable "full_system_upgrade_command_arch" {
  type    = string
  default = "pacman -S --refresh --refresh --sysupgrade --noconfirm"
}

variable "virtualbox_firmware" {
  type    = string
  default = "efi"
}

variable "http_directory" {
  type    = string
  default = "./common/http"
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
