terraform {
  required_version = ">= 1.8, < 2.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "= 0.228.0"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

locals {
  nodes = {
    iscsi = { host = 10, role = "iscsi" }
    gfs1  = { host = 11, role = "gfs" }
    gfs2  = { host = 12, role = "gfs" }
    gfs3  = { host = 13, role = "gfs" }
  }

  networks = {
    management = { cidr = "10.92.10.0/24" }
    cluster    = { cidr = "10.92.20.0/24" }
    iscsi_a    = { cidr = "10.92.30.0/24" }
    iscsi_b    = { cidr = "10.92.40.0/24" }
  }
}

resource "yandex_vpc_network" "lab" {
  name = "${var.name_prefix}-network"
}

resource "yandex_vpc_subnet" "lab" {
  for_each       = local.networks
  name           = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  zone           = var.zone
  network_id     = yandex_vpc_network.lab.id
  v4_cidr_blocks = [each.value.cidr]
}

resource "yandex_vpc_security_group" "lab" {
  name       = "${var.name_prefix}-sg"
  network_id = yandex_vpc_network.lab.id

  ingress {
    description    = "SSH с адреса администратора"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description       = "Обмен данными между узлами стенда"
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Репозитории пакетов и обновления"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_disk" "raid" {
  for_each = toset(["raid1", "raid2"])
  name     = "${var.name_prefix}-${each.key}"
  type     = "network-hdd"
  zone     = var.zone
  size     = 8
}

resource "yandex_compute_instance" "node" {
  for_each = local.nodes

  name        = "${var.name_prefix}-${each.key}"
  hostname    = each.key
  zone        = var.zone
  platform_id = "standard-v3"

  labels = {
    project = "otus-dz02"
    role    = each.value.role
  }

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 15
      type     = "network-hdd"
    }
  }

  dynamic "secondary_disk" {
    for_each = each.key == "iscsi" ? yandex_compute_disk.raid : {}
    content {
      disk_id     = secondary_disk.value.id
      auto_delete = false
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lab["management"].id
    ip_address         = "10.92.10.${each.value.host}"
    nat                = true
    security_group_ids = [yandex_vpc_security_group.lab.id]
  }

  dynamic "network_interface" {
    for_each = each.key == "iscsi" ? [] : [1]
    content {
      subnet_id          = yandex_vpc_subnet.lab["cluster"].id
      ip_address         = "10.92.20.${each.value.host}"
      security_group_ids = [yandex_vpc_security_group.lab.id]
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lab["iscsi_a"].id
    ip_address         = "10.92.30.${each.value.host}"
    security_group_ids = [yandex_vpc_security_group.lab.id]
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lab["iscsi_b"].id
    ip_address         = "10.92.40.${each.value.host}"
    security_group_ids = [yandex_vpc_security_group.lab.id]
  }

  metadata = {
    user-data = "#cloud-config\n${yamlencode({
      users = [{
        name                = "otus"
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = ["ALL=(ALL) NOPASSWD:ALL"]
        lock_passwd         = true
        ssh_authorized_keys = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
      }]
      ssh_pwauth   = false
      disable_root = true
    })}"
  }
}
