output "public_ips" {
  description = "Публичные адреса интерфейсов управления."
  value       = { for name, vm in yandex_compute_instance.node : name => vm.network_interface[0].nat_ip_address }
}
output "private_ips" {
  description = "Внутренние адреса интерфейсов стенда."
  value = { for name, node in local.nodes : name => {
    management = "10.92.10.${node.host}"
    cluster    = name == "iscsi" ? null : "10.92.20.${node.host}"
    iscsi_a    = "10.92.30.${node.host}", iscsi_b = "10.92.40.${node.host}"
  } }
}
output "raid_disk_ids" {
  description = "Идентификаторы двух дисков RAID1."
  value       = { for name, disk in yandex_compute_disk.raid : name => disk.id }
}
