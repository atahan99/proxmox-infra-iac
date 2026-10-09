#!/usr/bin/env bash
# git -> HA, from the Mac: secrets.yaml (rendered from homelab.env, never written here) and
# homeassistant/config/ go to /config through the Terminal & SSH add-on (key auth), then HA's own
# config check and a restart. Files only in /config (UI state, HACS, themes) are left alone.
set -euo pipefail
ha=root@${HA_IP:?run through make ha-deploy (HA_IP comes from homelab.env)}
cd "$(dirname "$0")/config"

# ${VAR} from homelab.env (make runs this under pass-cli run); a missing one fails here, before HA is touched.
export HOMELAB_LAN_PREFIX=${HOMELAB_LAN_CIDR%.*/*}
secrets=$(python3 -c 'import os, re, sys
print(re.sub(r"\$\{(\w+)\}", lambda m: os.environ[m.group(1)], sys.stdin.read()), end="")' <secrets.yaml.tpl)
ssh "$ha" 'umask 077 && cat >/config/secrets.yaml' <<<"$secrets"
COPYFILE_DISABLE=1 tar --no-xattrs --exclude secrets.yaml.tpl -cf - . | ssh "$ha" 'tar -C /config -xf -'
ssh "$ha" 'ha core check && ha core restart'
