# Packer Templates — Proxmox VE

Dépôt de templates HashiCorp Packer pour la création d'images "Gold" sur Proxmox VE.

## Structure du dépôt

```
Packer/
├── README.md                        ← ce fichier
└── rocky-linux-cis/                 ← Template Rocky Linux 9 CIS Level 2
    ├── main.pkr.hcl                 ← Définition Packer (source + build)
    ├── variables.pkrvars.hcl        ← Variables sensibles (ignoré par git)
    ├── variables.pkrvars.hcl.example← Exemple à copier
    ├── .gitignore
    ├── http/
    │   └── ks.cfg                   ← Fichier Kickstart (partitionnement CIS)
    └── scripts/
        ├── 01-install-authorized-key.sh
        ├── 02-cis-hardening.sh      ← Durcissement CIS Level 2
        └── 03-cleanup.sh            ← Nettoyage avant snapshot
```

## Ajouter un nouveau template

Créer un sous-dossier avec la même structure :

```
Packer/
└── <nom-du-template>/
    ├── main.pkr.hcl
    ├── variables.pkrvars.hcl.example
    ├── http/
    └── scripts/
```

---

Pour le détail du template Rocky Linux 9 CIS Level 2, voir [rocky-linux-cis/README.md](rocky-linux-cis/README.md).
