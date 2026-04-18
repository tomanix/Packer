# ─── Proxmox ──────────────────────────────────────────────────────────────────
proxmox_url          = "https://192.168.1.81:8006/api2/json"
proxmox_username     = "root@pam"
proxmox_password     = "root"
proxmox_node         = "pve"
proxmox_insecure_tls = true

# ─── ISO ──────────────────────────────────────────────────────────────────────
# Ajuster le nom exact de l'ISO présent dans Proxmox → Datacenter > Storage > local > ISO Images
iso_file = "local:iso/Rocky-9.7-x86_64-minimal.iso"

# ─── VM ───────────────────────────────────────────────────────────────────────
vm_name = "GOLD-ROCKY9"
vm_id   = 9000

# ─── SSH ──────────────────────────────────────────────────────────────────────
ssh_public_key_file  = "~/.ssh/id_ed25519.pub"
ssh_private_key_file = "~/.ssh/id_ed25519"
