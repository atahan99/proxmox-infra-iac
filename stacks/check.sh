#!/bin/bash
# Lint for the compose stacks (Trivy has no compose scanner). Every stack must render with
# `docker compose config`, pin every image by tag + digest, and none may run privileged, share the host's
# network or PIDs, add the escape capabilities, drop AppArmor, or mount the Docker socket or the folders
# holding it (except SOCKET_OK services: they exist to manage Docker).
set -euo pipefail
SOCKET_OK="socket-proxy/socket-proxy agents/socket-proxy agents/dozzle-agent dockhand/dockhand hawser/hawser"
# Dummy site values: Ansible writes the real ones into each stack's .env.
export DOMAIN=example.com TZ=UTC LAN_CIDR=192.0.2.0/24 LATITUDE=0 LONGITUDE=0
for v in DNS_VIP GATEWAY_IP PVE_IP DOCKER_HW_IP DOCKER_APPS_IP HA_IP PLEX_IP KASM_IP PBS_IP ADGUARD_IP \
  RPI3_IP PIKVM_IP MODEM_IP SWITCH_IP AP1_IP AP2_IP; do export "$v=192.0.2.1"; done
cd "$(dirname "$0")"
rc=0
for dir in */; do
  stack=${dir%/}
  [ -f "$stack/compose.yml" ] || continue
  json=$(cd "$stack" && docker compose config --format json) || { echo "FAIL $stack: compose config"; rc=1; continue; }
  fail() { echo "FAIL $stack: $1: $2"; ok=0; rc=1; }
  ok=1
  q() { jq -r --arg s "$stack" --arg ok " $SOCKET_OK " ".services | to_entries[] | select($1) | .key" <<<"$json"; }
  bad=$(q '.value.image | test("@sha256:[0-9a-f]{64}$") | not'); [ -z "$bad" ] || fail "image without digest" "$bad"
  bad=$(q '.value.privileged == true'); [ -z "$bad" ] || fail privileged "$bad"
  bad=$(q '.value.network_mode == "host" or .value.pid == "host"'); [ -z "$bad" ] || fail "host network/pid" "$bad"
  bad=$(q '[.value.cap_add[]? | ascii_upcase | ltrimstr("CAP_")] | any(. == "ALL" or . == "SYS_ADMIN" or . == "SYS_PTRACE" or . == "SYS_MODULE")')
  [ -z "$bad" ] || fail cap_add "$bad"
  bad=$(q '[.value.security_opt[]?] | any(test("unconfined"))'); [ -z "$bad" ] || fail "security_opt unconfined" "$bad"
  bad=$(q '.key as $k | ($ok | contains(" \($s)/\($k) ") | not) and ([.value.volumes[]?.source // empty] | any(endswith("docker.sock") or . == "/" or . == "/run" or . == "/var/run"))')
  [ -z "$bad" ] || fail "mounts the Docker socket (use socket-proxy)" "$bad"
  [ $ok -eq 0 ] || echo "ok   $stack"
done
exit $rc
