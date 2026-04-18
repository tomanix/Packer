#!/usr/bin/env bash

PROXMOX_HOST="root@192.168.1.81"
PROXMOX_KS_DIR="/tmp/packer-ks"
PROXMOX_KS_PORT="8802"

stop_http() {
  echo ">>> Arrêt du serveur HTTP sur Proxmox..."
  ssh "${PROXMOX_HOST}" "pkill -f 'http.server ${PROXMOX_KS_PORT}' || true" 2>/dev/null || true
}
trap stop_http EXIT

echo ">>> Copie du kickstart sur Proxmox..."
ssh "${PROXMOX_HOST}" "mkdir -p ${PROXMOX_KS_DIR}"
scp http/ks.cfg "${PROXMOX_HOST}:${PROXMOX_KS_DIR}/ks.cfg"

echo ">>> Arrêt d'un éventuel serveur résiduel..."
ssh "${PROXMOX_HOST}" "pkill -f 'http.server ${PROXMOX_KS_PORT}' || true" 2>/dev/null || true
sleep 2

echo ">>> Démarrage du serveur HTTP (port ${PROXMOX_KS_PORT})..."
ssh "${PROXMOX_HOST}" \
  "nohup python3 -m http.server ${PROXMOX_KS_PORT} --directory ${PROXMOX_KS_DIR} \
   >/tmp/packer-ks.log 2>&1 </dev/null &"
sleep 3

echo ">>> Vérification..."
if ! ssh "${PROXMOX_HOST}" "curl -sf http://localhost:${PROXMOX_KS_PORT}/ks.cfg >/dev/null"; then
  echo "ERREUR : serveur HTTP inaccessible sur Proxmox"
  ssh "${PROXMOX_HOST}" "cat /tmp/packer-ks.log" || true
  exit 1
fi
echo "    OK — http://192.168.1.81:${PROXMOX_KS_PORT}/ks.cfg"

echo ">>> Build Packer..."
packer build -on-error=abort -var-file=variables.pkrvars.hcl .
