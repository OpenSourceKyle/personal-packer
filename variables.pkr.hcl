# ============================================================================
# PACKER VARIABLES
# https://www.packer.io/docs/templates/hcl_templates/variables
# ============================================================================

# --- ISO Configuration ---
variable "iso_arch" {
  type    = string
  default = "https://mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
}

variable "iso_arch_hash" {
  type    = string
  default = "file:https://mirrors.edge.kernel.org/archlinux/iso/latest/sha256sums.txt"
}

# --- Build Configuration ---
variable "output_location" {
  type    = string
  default = "output/"
}

variable "dont_display_gui" {
  type    = bool
  default = true
}

# --- Guest OS & Provisioning ---
variable "boot_command_arch" {
  type = list(string)
  default = [
    "<enter><wait60>",
    # This command now clears history (history -c) after running to prevent re-execution.
    "curl --connect-timeout 5 --retry 1 --url http://{{ .HTTPIP }}:{{ .HTTPPort }}/arch/enable-ssh.sh | bash",
    "<enter><wait5>"
  ]
}

variable "boot_wait_arch" {
  type    = string
  default = "5s"
}

variable "http_directory" {
  type    = string
  default = "./common/http/"
}

# --- Virtual Machine Hardware ---
variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = number
  default = 40000
}

# --- Communicator Settings (SSH) ---
variable "vm_username" {
  type    = string
  default = "vagrant"
}

variable "vm_password" {
  type      = string
  default   = "vagrant"
  sensitive = true
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
