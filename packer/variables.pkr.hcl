variable "image_version" {
  type        = string
  description = "Version de l'image, ex. 0.2.0 (sans le préfixe v)"
}

variable "iso_url" {
  type        = string
  description = "URL de l'ISO netinst Debian 12 — chemin d'archive immuable (pas 'current/', qui glisse vers la nouvelle stable et casse le build sans prévenir, comme observé le 20/08/2026 quand trixie a remplacé bookworm sous current/)"
  default     = "https://cdimage.debian.org/cdimage/archive/12.15.0/amd64/iso-cd/debian-12.15.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum SHA256 — à mettre à jour manuellement et délibérément à chaque bump de version, pas de suivi automatique de current/"
  default     = "file:https://cdimage.debian.org/cdimage/archive/12.15.0/amd64/iso-cd/SHA256SUMS"
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
  description = "Taille du disque en Mo — 20 Go, prérequis minimum mesuré par l'audit #40"
  default     = 20480
}

variable "memory_mb" {
  type        = number
  description = "RAM en Mo — 8 Go, prérequis minimum mesuré par l'audit #40. Ne pas fixer plus haut sans savoir si ce sont les specs de l'appliance distribuée (l'environnement d'accueil final décide de ce qu'il peut réellement allouer, pas la machine de build)."
  default     = 8192
}

variable "cpus" {
  type        = number
  description = "vCPU — 4, prérequis minimum mesuré par l'audit #40"
  default     = 4
}

variable "bridge_adapter" {
  type        = string
  description = "Interface réseau physique de la machine de BUILD à utiliser pour le pont réseau (ex. 'en0' sur Mac Wi-Fi) — n'a pas d'incidence sur l'appliance exportée elle-même (l'utilisateur final choisit sa propre interface à l'import), sert seulement à ce que VirtualBox accepte la config au moment du build. Vérifier avec `VBoxManage list bridgedifs`."
  default     = "en0"
}

variable "providers" {
  type        = string
  description = "Providers de virtualisation à embarquer : 'none' (shell-only), 'incus', 'kvm', ou 'all' — permet de mesurer le poids réel de chaque combinaison avant de trancher (voir PLAN.md, section mesures)"
  default     = "all"
}
