
#
# VyOS v_0.1
#

#
# PROVIDER
#

terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "0.6.14"
    }
  }
}

provider "libvirt" {
  uri = "qemu+tcp://root@${var.qemu_host}/system"
}


#
# VARS
#

# libvirt
variable "qemu_host" {}

# vm
variable "vm_name" {}
variable "vm_mem" { default = 2048 }
variable "vm_cpu" { default = 2 }

# base
variable "img_url" {}

# qemu
variable "volume_path_img" { default = "/data/img" }
variable "volume_path_pool" { default = "/data/pool" }

# network
variable "mgmt_ipaddress" {}
variable "mgmt_gateway" {}
variable "mgmt_interface" { default = "eth0" }

variable "network_interface" {
  type = map
  default = {
    "net0" = "br3472"
    "net1" = "br2255"
    "net2" = "br2255"
  }
}


#
# RESOURCE
#

# pool
resource "libvirt_pool" "vyos" {
  name = var.vm_name
  type = "dir"
  path = "${var.volume_path_pool}/${var.vm_name}"
}

# volume
resource "libvirt_volume" "vyos" {
  name   = var.vm_name
  source = var.img_url
  pool   = libvirt_pool.vyos.name
}


#
# CLOUD-INIT
#

# network_config
data "template_file" "network" {
  template = file("${path.module}/cloud_init/network.cfg")
}

# user_data
data "template_file" "user_data" {
  template = file("${path.module}/cloud_init/user_data.cfg")
  vars = {
    hostname        = var.vm_name
    mgmt_ipaddress  = var.mgmt_ipaddress
    mgmt_gateway    = var.mgmt_gateway
    mgmt_interface  = var.mgmt_interface
  }
}

# vyos
resource "libvirt_cloudinit_disk" "vyos" {
  name           = "cloud_vyos.iso"
  network_config = data.template_file.network.rendered
  user_data      = data.template_file.user_data.rendered
  pool           = libvirt_pool.vyos.name
}


#
# DOMAIN
#

# vyos
resource "libvirt_domain" "vyos" {
  name   = var.vm_name
  memory = var.vm_mem
  vcpu   = var.vm_cpu

  cloudinit = libvirt_cloudinit_disk.vyos.id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.vyos.id
  }

  dynamic "network_interface" {
    for_each = var.network_interface
    content {
      bridge = network_interface.value
    }
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}


#
# OUTPUT
#
output "mgmt_ipaddress" {
  value = var.mgmt_ipaddress
}
