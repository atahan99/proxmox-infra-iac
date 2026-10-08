#!/bin/sh
# Run by the linuxserver image at every start (/custom-cont-init.d), so the WebUI login is set from code
# on a fresh install and after a restore:
# - the login from /opt/secrets/vpn-services-qbittorrent.env (Proton Pass item `qbittorrent`);
# - no login for clients on localhost, so gluetun's port-forwarding command (127.0.0.1, same network) can
#   set the listening port. Only gluetun and the speedtest share that network.
conf=/config/qBittorrent/qBittorrent.conf

set_pref() { # key, value: replace the line, or add it under [Preferences]
  if grep -q "^$1=" "$conf"; then
    sed -i "s|^$1=.*|$1=$2|" "$conf"
  else
    sed -i "s|^\[Preferences\]\$|[Preferences]\n$1=$2|" "$conf"
  fi
}

mkdir -p "${conf%/*}"
[ -f "$conf" ] || printf '[Preferences]\n' >"$conf"
grep -q '^\[Preferences\]' "$conf" || printf '\n[Preferences]\n' >>"$conf"
set_pref 'WebUI\\LocalHostAuth' false
if [ -n "$QBT_WEBUI_PASSWORD_PBKDF2" ]; then
  set_pref 'WebUI\\Username' "${QBT_WEBUI_USERNAME:-admin}"
  set_pref 'WebUI\\Password_PBKDF2' "\"$QBT_WEBUI_PASSWORD_PBKDF2\""
fi
chown -R abc:abc /config/qBittorrent
