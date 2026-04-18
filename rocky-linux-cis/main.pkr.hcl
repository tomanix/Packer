packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ─── Variables ────────────────────────────────────────────────────────────────

variable "proxmox_url" {
  type        = string
  description = "URL de l'API Proxmox (ex: https://proxmox.lan:8006/api2/json)"
}

variable "proxmox_username" {
  type        = string
  description = "Utilisateur Proxmox (ex: root@pam)"
}

variable "proxmox_password" {
  type        = string
  description = "Mot de passe Proxmox"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Nom du nœud Proxmox cible"
}

variable "proxmox_insecure_tls" {
  type        = bool
  description = "Ignorer les erreurs de certificat TLS"
  default     = false
}

variable "iso_file" {
  type        = string
  description = "Chemin ISO sur le stockage Proxmox (ex: local:iso/Rocky-9.x-x86_64-dvd.iso)"
}

variable "ssh_public_key_file" {
  type        = string
  description = "Chemin vers la clé publique SSH locale pour le provisionnement"
}

variable "ssh_private_key_file" {
  type        = string
  description = "Chemin vers la clé privée SSH locale pour Packer"
  default     = "~/.ssh/id_ed25519"
}

variable "vm_name" {
  type    = string
  default = "GOLD-ROCKY9"
}

variable "vm_id" {
  type        = number
  description = "ID de la VM dans Proxmox (doit être unique)"
  default     = 9000
}

# ─── Source Proxmox ISO ───────────────────────────────────────────────────────

source "proxmox-iso" "rocky9_cis" {
  # Connexion Proxmox
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = var.proxmox_insecure_tls

  # Identité de la VM
  vm_id   = var.vm_id
  vm_name = var.vm_name
  tags    = "gold;rocky9;cis2"

  # ISO Rocky Linux (déjà présent sur le stockage local)
  boot_iso {
    iso_file     = var.iso_file
    unmount      = true
  }

  # Ressources
  cpu_type = "host"
  cores    = 2
  sockets  = 1
  memory   = 8192
  os       = "l26"

  # Disque système 50 Go sur DATASTORE
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size    = "50G"
    storage_pool = "DATASTORE"
    type         = "scsi"
    format       = "raw"
    cache_mode   = "writeback"
  }

  # Réseau
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # SeaBIOS + i440FX (défaut Proxmox)
  bios = "seabios"

  # false pendant le build : l'agent n'est pas encore actif durant l'install.
  # Le service qemu-guest-agent est activé dans l'OS via le kickstart ;
  # il sera pleinement opérationnel une fois le template cloné et démarré.
  qemu_agent = false

  # Kickstart servi par un serveur HTTP sur le nœud Proxmox (192.168.1.81)
  # La VM peut toujours joindre son hyperviseur — évite les problèmes d'isolation WiFi.
  # Le serveur HTTP est démarré par build.sh avant le lancement de Packer.
  boot_wait = "15s"
  boot_command = [
    "<up><wait2>",
    "<tab><wait>",
    " inst.ks=http://192.168.1.81:8802/ks.cfg",
    "<enter><wait>"
  ]

  # Packer se connecte par mot de passe (la clé n'est pas encore dans la VM).
  # Le provisioner 01 dépose la clé, le provisioner 02 désactive ensuite le mot de passe.
  # Proxmox (192.168.1.81) est utilisé comme jump host car la machine Packer
  # (WiFi, 192.168.1.76) ne peut pas joindre directement la VM (isolation WiFi).
  communicator                 = "ssh"
  ssh_host                     = "192.168.1.110"
  ssh_username                 = "deploy"
  ssh_password                 = "deploy"
  ssh_timeout                  = "45m"
  ssh_handshake_attempts       = 50
  ssh_bastion_host             = "192.168.1.81"
  ssh_bastion_username         = "root"
  ssh_bastion_private_key_file = pathexpand("~/.ssh/id_ed25519")

  # Template final
  template_name        = var.vm_name
  template_description = "Rocky Linux 9 - CIS Level 2 - Built by Packer le {{isotime}}"
}

# ─── Build ────────────────────────────────────────────────────────────────────

build {
  name    = "gold-rocky9-cis2"
  sources = ["source.proxmox-iso.rocky9_cis"]

  # Copie de la clé publique SSH dans authorized_keys
  provisioner "file" {
    source      = pathexpand(var.ssh_public_key_file)
    destination = "/tmp/authorized_keys_deploy"
  }

  # Provisionnement principal
  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} bash {{ .Path }}'"
    scripts = [
      "${path.root}/scripts/01-install-authorized-key.sh",
      "${path.root}/scripts/02-cis-hardening.sh",
      "${path.root}/scripts/03-cleanup.sh",
    ]
  }
}
