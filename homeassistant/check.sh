#!/usr/bin/env bash
# HA's own config check (`check_config`) on homeassistant/config/, with a dummy secrets.yaml that has
# the same keys as secrets.yaml.tpl. Needs Docker: runs in CI; locally with Docker running.
set -euo pipefail
image=homeassistant/home-assistant:2026.9.4@sha256:3e6710a7ab2a61311d9d899b719f6c3657791c63e8f4942cec4ebc42401d6b76

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cp -R "$(dirname "$0")/config/." "$dir"
mkdir -p "$dir/themes" # filled by HACS on the real instance
sed -n -e 's/^\([a-z0-9_]*_ip\):.*/\1: "192.0.2.1"/p' -e 's/^\([a-z0-9_]*_mac\):.*/\1: "00:00:5e:00:53:00"/p' \
  "$dir/secrets.yaml.tpl" >"$dir/secrets.yaml"
# check_config exits 0 when only an integration's config is invalid (it reports "Failed config" /
# "Successful config (partial)"), so the output decides too.
out=$(docker run --rm -v "$dir:/config" "$image" python -m homeassistant --script check_config --config /config) || { echo "$out"; exit 1; }
echo "$out"
! grep -qE 'Failed config|General Errors|\(partial\)' <<<"$out"
