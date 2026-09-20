variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud."
  type        = string
}

variable "folder_id" {
  description = "Идентификатор каталога для ресурсов DZ02."
  type        = string
}

variable "zone" {
  description = "Зона доступности."
  type        = string
  default     = "ru-central1-a"
}

variable "name_prefix" {
  description = "Префикс имён ресурсов DZ02."
  type        = string
  default     = "otus-dz02"
}

variable "ssh_public_key_path" {
  description = "Путь к отдельному публичному ключу DZ02."
  type        = string
  validation {
    condition     = can(regex("^ssh-ed25519 [A-Za-z0-9+/=]+", trimspace(file(pathexpand(var.ssh_public_key_path)))))
    error_message = "Укажите существующий публичный ключ OpenSSH ed25519."
  }
}

variable "ssh_allowed_cidr" {
  description = "Публичный IPv4-адрес администратора с маской /32."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.ssh_allowed_cidr)) && endswith(var.ssh_allowed_cidr, "/32")
    error_message = "Укажите один публичный IPv4-адрес с маской /32."
  }
}
