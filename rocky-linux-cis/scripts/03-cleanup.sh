#!/usr/bin/env bash
# Nettoyage avant création du template Proxmox
set -euo pipefail

echo "[03] Nettoyage de la VM..."

# Suppression des paquets temporaires
dnf clean all

# Nettoyage des journaux
find /var/log -type f -exec truncate -s 0 {} \;
rm -f /var/log/*.gz /var/log/*.[0-9] /var/log/*/*.[0-9]

# Suppression du fichier de log kickstart
rm -f /root/ks-post.log

# Suppression des historiques shell
unset HISTFILE
history -c
rm -f /root/.bash_history /home/deploy/.bash_history

# Suppression des clés SSH de la machine (regenerées au premier boot)
rm -f /etc/ssh/ssh_host_*

# Réinitialisation des identifiants machine (cloud-init / firstboot)
rm -f /etc/machine-id
touch /etc/machine-id

# Nettoyage tmp
rm -rf /tmp/* /var/tmp/*

# Suppression du sudoers sans mot de passe (sécurité post-build)
# À retirer si vous souhaitez garder le NOPASSWD pour Ansible
# rm -f /etc/sudoers.d/deploy

echo "[03] Nettoyage terminé. VM prête pour la création du template."

# Extinction propre — Packer détectera la déconnexion SSH
shutdown -h now
