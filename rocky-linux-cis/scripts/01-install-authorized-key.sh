#!/usr/bin/env bash
set -euo pipefail

# Installe la clé publique SSH copiée par Packer dans /tmp
DEPLOY_HOME="/home/deploy"
AUTH_KEYS="${DEPLOY_HOME}/.ssh/authorized_keys"

install -o deploy -g deploy -m 600 /tmp/authorized_keys_deploy "${AUTH_KEYS}"
rm -f /tmp/authorized_keys_deploy

echo "[01] Clé SSH installée pour l'utilisateur deploy."
