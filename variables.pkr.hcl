# https://www.packer.io/docs/templates/hcl_templates/variables
# packer validate .

variable "iso_kali" {
  type    = list(string)
  default = ["kali-linux-2021.3-installer-amd64.iso", "https://cdimage.kali.org/kali-2021.3/kali-linux-2021.3-installer-amd64.iso"]
}
variable "iso_kali_vsphere" {
  type    = list(string)
  default = ["[ISO] kali-linux-2021.3-installer-amd64.iso"]
}
variable "iso_kali_hash" {
  type    = string
  default = "sha256:3a199fce1220a09756159682ed87ca16f7735f50dcde4403dc0c60525f90c756"
}
variable "iso_debian" {
  type    = list(string)
  default = ["debian-10.10.0-amd64-xfce-CD-1.iso", "https://cdimage.debian.org/cdimage/release/10.10.0/amd64/iso-cd/debian-10.10.0-amd64-xfce-CD-1.iso"]
}
variable "iso_debian_vsphere" {
  type    = list(string)
  default = ["[ISO] debian-10.10.0-amd64-xfce-CD-1.iso"]
}
variable "iso_debian_hash" {
  type    = string
  default = "sha256:24fee00ed402c4a82cfec535870ab2359ec12a7dd4eed89c98fd582bc7cf3b25"
}

# --- Remote Builds only (vSphere) ---

variable "vsphere_hostname" {
  type    = string
  default = "sa-vcenter01.mlb.rii.io"
}
variable "vsphere_host" {
  type    = string
  default = "10.10.90.10"
}
variable "vsphere_cluster" {
  type    = string
  default = "RII"
}
variable "vsphere_datastore" {
  type    = string
  default = "synology01"
}
variable "vsphere_vm_path" {
  # This is the location on the vSphere server
  type    = string
  default = "Dev_Engineering/GOLD_IMAGES_by_Packer"
}
variable "vsphere_network" {
  type = string
  # NOTE: this network can access the Internet and internal RII services
  default = "cyber.lab.1851"
}
variable "preseed_server_ip" {
  # Due to network limitations, this var_preseed_server IP address
  # needs to host the preseeds from within the vSphere network (e.g. "cyber.lab.1850")
  type    = string
  default = "10.10.151.250"
}

# --- Local Builds only (VMware Workstation) ---

# Do NOT show VMware Workstation during OS installation (headless mode)
variable "dont_display_gui" {
  type    = bool
  default = true
}

# --- RECOMMENDED TO NOT CHANGE --- 

variable "vsphere_user" {
  type = string
  # default = "<USERNAME>"
}
variable "vsphere_password" {
  type      = string
  sensitive = true
  # default = "<PASSWORD>"
}

# Boot Command: https://www.debian.org/releases/stable/amd64/apbs02#preseed-aliases
variable "boot_command_debian_kali" {
  type = list(string)
  default = ["<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian_kali/preseed.cfg debian-installer=en_US locale=en_US kbd-chooser/method=us console-keymaps-at/keymap=us keyboard-configuration/xkb-keymap=us",
  "<enter><wait>"]
}
variable "boot_wait_debian_kali" {
  type    = string
  default = "8s"
}

variable "full_system_upgrade_command_debian_kali" {
  type    = string
  default = "export DEBIAN_FRONTEND=noninteractive ; echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections ; sudo bash -c 'apt update -y && apt upgrade -y'"
}

variable "http_directory" {
  type    = string
  default = "./common/http"
}

variable "preeed_server_port_min" {
  type    = number
  default = 8000
}
variable "preeed_server_port_max" {
  type    = number
  default = 8005
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
  default = "20m"
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
