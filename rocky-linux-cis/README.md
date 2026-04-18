# Template GOLD-ROCKY9 — Rocky Linux 9 CIS Level 2

Template Packer pour créer une image "Gold" Rocky Linux 9 durcie CIS Level 2 sur Proxmox VE.

---

## Prérequis

| Outil | Version minimale |
|-------|-----------------|
| Packer | 1.10+ |
| Plugin Proxmox | 1.1.8+ |
| Proxmox VE | 7.x / 8.x |

```bash
# Vérifier Packer
packer version

# Installer le plugin Proxmox (fait automatiquement par packer init)
packer plugins install github.com/hashicorp/proxmox
```

---

## 1. Préparation de l'ISO dans Proxmox

### 1.1 Télécharger l'ISO Rocky Linux 9

Depuis [https://rockylinux.org/download](https://rockylinux.org/download), télécharger :
`Rocky-9.x-x86_64-dvd.iso`

### 1.2 Uploader l'ISO dans Proxmox

**Via l'interface web :**
1. Datacenter → Storage → **local** → ISO Images
2. Cliquer **Upload**
3. Sélectionner le fichier `.iso`

**Via CLI (depuis le nœud Proxmox) :**
```bash
# Depuis votre machine locale
scp Rocky-9.5-x86_64-dvd.iso root@<IP_PROXMOX>:/var/lib/vz/template/iso/

# Vérifier la présence
ssh root@<IP_PROXMOX> "ls /var/lib/vz/template/iso/"
```

### 1.3 Vérifier le nom exact de l'ISO

Dans Proxmox, noter le nom **exact** de l'ISO (sensible à la casse).  
Il sera renseigné dans `variables.pkrvars.hcl` sous la forme :
```
iso_file = "local:iso/Rocky-9.5-x86_64-dvd.iso"
```

---

## 2. Préparation du mot de passe de l'utilisateur deploy

Le fichier `http/ks.cfg` contient un hash SHA-512 du mot de passe.  
Regénérer le hash avec la commande suivante (à exécuter sur Linux) :

```bash
python3 -c "import crypt; print(crypt.crypt('deploy', crypt.mksalt(crypt.METHOD_SHA512)))"
```

Remplacer la valeur `$6$rounds=4096$deploy$placeholder_replace_me` dans `http/ks.cfg` :

```
user --name=deploy --password=<HASH_GÉNÉRÉ> --iscrypted --groups=wheel
```

---

## 3. Configuration de Packer

### 3.1 Copier le fichier de variables

```bash
cd rocky-linux-cis/
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

### 3.2 Éditer les variables

```hcl
# variables.pkrvars.hcl
proxmox_url          = "https://192.168.1.1:8006/api2/json"  # IP de votre Proxmox
proxmox_username     = "root@pam"
proxmox_password     = "MOT_DE_PASSE_PROXMOX"
proxmox_node         = "pve"                                   # nom du nœud
proxmox_insecure_tls = true                                    # false si certificat valide

iso_file             = "local:iso/Rocky-9.5-x86_64-dvd.iso"  # nom exact de l'ISO

vm_name              = "GOLD-ROCKY9"
vm_id                = 9000                                    # doit être unique dans Proxmox

ssh_public_key_file  = "~/.ssh/id_rsa.pub"                    # clé publique locale
```

### 3.3 Clé SSH

S'assurer d'avoir une paire de clés SSH :

```bash
# Si elle n'existe pas encore
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

La clé **publique** (`~/.ssh/id_rsa.pub`) sera copiée dans la VM.  
La clé **privée** (`~/.ssh/id_rsa`) sera utilisée par Packer pour se connecter.

### 3.4 Vérifier la connectivité réseau

Packer doit pouvoir atteindre :
- L'API Proxmox (`https://<IP>:8006`) depuis la machine qui lance Packer
- La VM en cours de build via SSH (`192.168.1.110:22`)
- La VM doit pouvoir atteindre le serveur HTTP temporaire de Packer (port 8802)

> **Important :** Adapter `http_port_min`/`http_port_max` dans `main.pkr.hcl` si le port 8802
> est occupé, et s'assurer que le pare-feu local autorise ce port entrant depuis la VM.

---

## 4. Build du template

### 4.1 Initialiser le plugin Proxmox

```bash
cd rocky-linux-cis/
packer init .
```

### 4.2 Valider la configuration

```bash
packer validate -var-file=variables.pkrvars.hcl .
```

### 4.3 Lancer le build

```bash
packer build -var-file=variables.pkrvars.hcl .
```

**Avec logs détaillés :**
```bash
PACKER_LOG=1 packer build -var-file=variables.pkrvars.hcl . 2>&1 | tee packer-build.log
```

### 4.4 Déroulement du build

```
1. Packer crée une VM temporaire dans Proxmox
2. Monte l'ISO Rocky Linux
3. Démarre un serveur HTTP local (port 8802) pour servir le kickstart
4. Envoie les commandes clavier au GRUB pour passer le chemin du kickstart
5. L'installeur Rocky Linux s'exécute automatiquement (~10-15 min)
6. Packer se connecte en SSH à 192.168.1.110
7. Copie la clé SSH publique
8. Exécute les scripts de provisionnement :
   - 01 : installation de la clé SSH
   - 02 : durcissement CIS Level 2
   - 03 : nettoyage + shutdown
9. Proxmox convertit la VM en template
```

---

## 5. Utilisation du template

### 5.1 Vérifier la présence du template dans Proxmox

Dans l'interface Proxmox : le template apparaît avec l'icône de template (cadenas).  
Il est visible sous le nœud, avec le nom `GOLD-ROCKY9` et l'ID `9000`.

### 5.2 Cloner le template pour créer une VM

**Via l'interface Proxmox :**
1. Clic droit sur `GOLD-ROCKY9` → **Clone**
2. Mode : **Full Clone** (recommandé)
3. Renseigner le nom et l'ID de la nouvelle VM
4. Démarrer la VM

**Via CLI (API Proxmox / qm) :**
```bash
# Sur le nœud Proxmox
qm clone 9000 101 --name "ma-vm" --full --storage DATASTORE
qm start 101
```

**Via Terraform (exemple) :**
```hcl
resource "proxmox_vm_qemu" "ma_vm" {
  name        = "ma-vm"
  target_node = "pve"
  clone       = "GOLD-ROCKY9"
  full_clone  = true

  cores   = 2
  sockets = 1
  memory  = 4096

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}
```

### 5.3 Connexion SSH à la VM clonée

```bash
ssh -i ~/.ssh/id_rsa deploy@<IP_DE_LA_VM>
```

---

## Architecture réseau de la VM Gold

| Paramètre | Valeur |
|-----------|--------|
| Adresse IP | 192.168.1.110/24 |
| Passerelle | 192.168.1.254 |
| DNS | 8.8.8.8, 8.8.4.4 |
| Hostname | gold-rocky9 |

> Lors du clonage, il faudra reconfigurer l'IP statique si plusieurs VMs
> sont déployées depuis ce template.

---

## Partitionnement CIS Level 2

| Point de montage | Taille | Options |
|-----------------|--------|---------|
| /boot/efi | 512 Mo | — |
| /boot | 1 Go | — |
| / | 10 Go | — |
| /tmp | 2 Go | nodev, nosuid, noexec |
| /var | 8 Go | — |
| /var/log | 4 Go | nodev, nosuid, noexec |
| /var/log/audit | 4 Go | nodev, nosuid, noexec |
| /var/tmp | 2 Go | nodev, nosuid, noexec |
| /home | reste (~17 Go) | nodev, nosuid |
| swap | 2 Go | — |

---

## Dépannage

### Packer ne peut pas accéder au kickstart

Vérifier que le port 8802 est ouvert sur la machine qui lance Packer :
```bash
# Linux
sudo ufw allow 8802/tcp
# ou
sudo firewall-cmd --add-port=8802/tcp --temporary
```

### Timeout SSH

- Vérifier que la VM a bien démarré et a l'IP `192.168.1.110`
- Augmenter `ssh_timeout` dans `main.pkr.hcl` (ex: `"45m"`)
- Vérifier les logs dans l'interface console Proxmox

### L'ISO n'est pas trouvée

Vérifier le nom exact :
```bash
ssh root@<IP_PROXMOX> "pvesm list local | grep iso"
```

### Rebuild du template

Si le template existe déjà (VM ID 9000), le supprimer avant de relancer :
```bash
# Sur le nœud Proxmox
qm destroy 9000 --destroy-unreferenced-disks 1
```

---

## Sécurité

- `variables.pkrvars.hcl` est ignoré par git (contient les mots de passe)
- L'authentification SSH par mot de passe est **désactivée** dans le template
- L'utilisateur root ne peut pas se connecter en SSH
- SELinux est en mode **Enforcing**
- Firewalld est actif, seul le port SSH est ouvert
