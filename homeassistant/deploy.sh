#!/usr/bin/env bash
# git -> HA, from the Mac: secrets.yaml (rendered from homelab.env, never written here) and
# homeassistant/config/ go to /config through the Terminal & SSH add-on (key auth), then HA's own
# config check and a restart. Files only in /config (UI state, HACS, themes) are left alone.
set -euo pipefail
ha=root@${HA_IP:?run through make ha-deploy (HA_IP comes from homelab.env)}
cd "$(dirname "$0")/config"
# First contact after a rebuild: trust the add-on's new host key (like Ansible's accept-new for the LXCs).
# Every ssh below feeds data on stdin, so an interactive host-key prompt there would hang.
ssh() { command ssh -o StrictHostKeyChecking=accept-new "$@"; }

# ${VAR} from homelab.env (make runs this under pass-cli run); a missing one fails here, before HA is touched.
export HOMELAB_LAN_PREFIX=${HOMELAB_LAN_CIDR%.*/*}
secrets=$(python3 -c 'import os, re, sys
print(re.sub(r"\$\{(\w+)\}", lambda m: os.environ[m.group(1)], sys.stdin.read()), end="")' <secrets.yaml.tpl)
ssh "$ha" 'umask 077 && cat >/config/secrets.yaml' <<<"$secrets"
COPYFILE_DISABLE=1 tar --no-xattrs --exclude secrets.yaml.tpl -cf - . | ssh "$ha" 'tar -C /config -xf -'
# HA keeps its proxy settings in .storage/http (UI), which wins over the YAML `http:` block once it exists
# (it comes back with the backup, still naming the old proxy). Set Traefik's address there, with Core stopped.
proxy=${HOMELAB_LAN_PREFIX}.122/32 # docker-apps, as docker_apps_ip in secrets.yaml.tpl
ssh "$ha" 'ha core check'
ssh "$ha" "f=/config/.storage/http
if [ -f \$f ] && [ \"\$(jq -c '.data.stable | [.trusted_proxies, .login_attempts_threshold]' \$f)\" != '[[\"$proxy\"],5]' ]; then
  ha core stop && jq '.data.stable.trusted_proxies = [\"$proxy\"] | .data.stable.login_attempts_threshold = 5' \$f >\$f.new && mv \$f.new \$f && ha core start
else
  ha core restart
fi"
