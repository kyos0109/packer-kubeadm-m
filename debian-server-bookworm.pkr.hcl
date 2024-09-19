packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
    git = {
      version = ">= 0.6.2"
      source  = "github.com/ethanmdavidson/git"
    }
  }
}

variable "iso_file" {
  type = string
}

variable "cloudinit_storage_pool" {
  type    = string
  default = "vm-data"
}

variable "cores" {
  type    = string
  default = "4"
}

variable "disk_format" {
  type    = string
  default = "raw"
}

variable "disk_size" {
  type    = string
  default = "80G"
}

variable "disk_storage_pool" {
  type    = string
  default = "vm-data"
}

variable "cpu_type" {
  type    = string
  default = "host"
}

variable "memory" {
  type    = string
  default = "8192"
}

variable "network_vlan" {
  type    = string
  default = ""
}

variable "machine_type" {
  type    = string
  default = ""
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_api_user" {
  type = string
}

variable "proxmox_host" {
  type = string
}

variable "proxmox_node" {
  type = string
}

variable "pwd" {
  default = env("PWD")
}

data "git-commit" "cwd-head" {}

locals {
  truncated_sha = substr(data.git-commit.cwd-head.hash, 0, 8)
  message       = replace(data.git-commit.cwd-head.message, "'", "")
  author        = data.git-commit.cwd-head.author
}

source "proxmox-iso" "debian" {
  proxmox_url              = "https://${var.proxmox_host}/api2/json"
  insecure_skip_tls_verify = true
  username                 = var.proxmox_api_user
  token                    = var.proxmox_api_token

  template_description = "Built from ${basename(var.iso_file)} on ${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())} \n\nGit commit: ${local.truncated_sha} \n\n Message: ${local.message}"
  node                 = var.proxmox_node
  network_adapters {
    bridge   = "vnet60"
    firewall = true
    model    = "virtio"
    vlan_tag = var.network_vlan
  }
  disks {
    disk_size    = var.disk_size
    format       = var.disk_format
    io_thread    = true
    storage_pool = var.disk_storage_pool
    type         = "scsi"
  }
  scsi_controller = "virtio-scsi-single"

  iso_file       = var.iso_file
  http_directory = "./"
  boot_wait      = "10s"
  boot_command   = ["<esc><wait>auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg debconf/frontend=noninteractive -- <enter>"]
  unmount_iso    = true

  cloud_init              = true
  cloud_init_storage_pool = var.cloudinit_storage_pool

  vm_name  = format("%s-%s" ,trimsuffix(basename(var.iso_file), ".iso"), "${basename(var.pwd)}")
  tags     = "debian;k8s"
  cpu_type = var.cpu_type
  os       = "l26"
  memory   = var.memory
  cores    = var.cores
  sockets  = "1"
  machine  = var.machine_type

  # Note: this password is needed by packer to run the file provisioner, but
  # once that is done - the password will be set to random one by cloud init.
  ssh_password = "packer"
  ssh_username = "root"
}

build {
  sources = ["source.proxmox-iso.debian"]

  provisioner "file" {
    destination = "/etc/cloud/cloud.cfg"
    source      = "cloud.cfg"
  }
}