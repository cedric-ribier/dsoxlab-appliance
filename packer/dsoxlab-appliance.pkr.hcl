packer {
  required_plugins {
    virtualbox = {
      version = "~> 1"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

source "virtualbox-iso" "dsoxlab-runtime" {
  vm_name       = "dsoxlab-runtime-${var.image_version}"
  guest_os_type = "Debian_64"

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  cpus      = var.cpus
  memory    = var.memory_mb
  disk_size = var.disk_size_mb

  # Installation automatisée via preseed — http_directory sert le fichier
  # au VM pendant le boot de l'ISO netinst.
  http_directory = "http"

  boot_command = [
    "<esc><wait>",
    "install ",
    "auto=true priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "debian-installer=fr_FR.UTF-8 locale=fr_FR.UTF-8 ",
    "hostname=dsoxlab-runtime domain=local ",
    "keyboard-configuration/xkb-keymap=fr ",
    "<enter>"
  ]
  boot_wait = "5s"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"

  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Pas de démarrage automatique de service nécessitant /dev/kvm pendant
  # le build — voir PLAN.md §1.2. Le poste de build n'a pas forcément
  # la virtualisation imbriquée disponible.
  guest_additions_mode = "disable"

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--vram", "16"]
  ]

  vboxmanage_post = [
    ["modifyvm", "{{.Name}}", "--nic1", "bridged", "--bridgeadapter1", "${var.bridge_adapter}"],
    ["modifyvm", "{{.Name}}", "--nicpromisc1", "allow-all"]
  ] 

  export_opts = [
    "--manifest",
    "--vsys", "0",
    "--description", "dsoxlab runtime appliance ${var.image_version}",
    "--version", var.image_version
  ]
  format = "ova"
  output_directory = "output/dsoxlab-runtime-${var.image_version}"
}

build {
  name    = "dsoxlab-runtime"
  sources = ["source.virtualbox-iso.dsoxlab-runtime"]

  provisioner "file" {
    source      = "scripts/first-boot-provider-setup.sh"
    destination = "/tmp/first-boot-provider-setup.sh"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | sudo -S -E {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "DSOXLAB_PROVIDERS=${var.providers}"
    ]
    scripts = [
      "scripts/01-base.sh",
      "scripts/02-uv-dsoxlab.sh",
      "scripts/03-terraform-ansible.sh",
      "scripts/04-providers.sh",
      "scripts/06-verify.sh",
      "scripts/05-cleanup.sh",
    ]
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "output/dsoxlab-runtime-${var.image_version}/SHA256SUMS"
  }

  post-processor "manifest" {
    output     = "output/dsoxlab-runtime-${var.image_version}/manifest.json"
    strip_path = true
  }
}
