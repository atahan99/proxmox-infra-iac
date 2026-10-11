#!/usr/bin/env bash
# git -> Gatus on the RPi3, from the Mac (`make gatus-deploy`). Gatus doesn't run on the Proxmox server but on
# a separate device (the RPi3), so it can still alert when the whole server is down. Copies compose.yml and
# config.yaml to /opt/gatus on the Pi, renders .env from homelab.env and vault `gatus`, then starts it.
set -euo pipefail
pi=${RPI3_USER:?set RPI3_USER in homelab.env (your login on the Pi, key auth)}@${RPI3_IP:?run through make gatus-deploy}
cd "$(dirname "$0")"
ssh() { command ssh -o StrictHostKeyChecking=accept-new "$@"; }

export HOMELAB_LAN_PREFIX=${HOMELAB_LAN_CIDR%.*/*}
env=""
for v in HOMELAB_DOMAIN HOMELAB_TZ HOMELAB_LAN_PREFIX HOMELAB_GATEWAY HOMELAB_DNS_VIP PVE_IP HA_IP PIKVM_IP RPI3_IP MODEM_IP SWITCH_IP AP1_IP AP2_IP; do
  env+="$v=${!v:?$v is not set in homelab.env}"$'\n'
done
env+="NTFY_TOPIC=$(pass-cli item view pass://Homelab/gatus/NTFY_TOPIC)"$'\n'

ssh "$pi" 'mkdir -p /opt/gatus/data && umask 077 && cat >/opt/gatus/.env' <<<"$env"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - compose.yml config.yaml | ssh "$pi" 'tar -C /opt/gatus -xf -'
ssh "$pi" 'cd /opt/gatus && docker compose up -d --force-recreate'
