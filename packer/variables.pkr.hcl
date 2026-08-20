variable "image_version" {
  type        = string
  description = "Version de l'image, ex. 0.2.0 (sans le préfixe v)"
}

variable "iso_url" {
  type        = string
  description = "URL de l'ISO netinst Debian 12"
  default     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum SHA256 de l'ISO, à vérifier/mettre à jour à chaque changement de version Debian"
  default     = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

variable "ssh_password" {
  type      = string
  default   = "packer"
  sensitive = true
}

variable "disk_size_mb" {
  type        = number
  description = "Taille du disque en Mo — 20 Go, cohérent avec les prérequis mesurés de l'audit #40"
  default     = 20480
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "cpus" {
  type    = number
  default = 2
}
