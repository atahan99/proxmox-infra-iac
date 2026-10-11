# Credentials

Every secret is an item in the Proton Pass vault `Homelab`
([ADR 2](../adr/2-secrets-and-site-values.md)). The repo reads them as `pass://Homelab/<item>/<field>`,
so item titles and field names must match exactly. Scopes and rotation: [security.md](../security.md#credentials).

## Field names

- Login items have built-in `username`, `email` and `password` fields; a reference ending in one of those
  reads the built-in field. `email` and `username` are different fields.
- Any other name (`api_key`, `token_grafana`, `docker-hw`, ...) is a custom field, matched by its exact
  lowercase name. Login items can carry custom fields too; items with only custom fields can be Other
  items.
- Don't use the API Credential, Database, Server, SSH key or WiFi templates, or the Password type: they
  name their own fields ("API Key", "Password") and the references won't match.
- A missing item or field fails the command that reads it.

## Filling the vault for a fresh install

A rebuild starts every app empty except Wallos, Home Assistant and the data on the USB disk, so most values
can be new. Three kinds need care:

| Kind | Items |
|---|---|
| Must match data that survives the rebuild | `immich/db_password` (database on the USB disk); `frigate/mqtt_user`, `mqtt_password` (HA's broker comes back from its backup) |
| Made before the rebuild, still valid after | `immich/api_key`, `homeassistant/homepage_token` (create it before the last HA backup), `tailscale-api/password` |
| `changeme` until the app runs | `changedetection`, `mealie`, `plex`, `tautulli`, `freshrss`, `pbs-homepage`, `proxmox-exporter`, `proxmox-homepage`, `tailscale-api/device_id` |

A placeholder doesn't stop `make apps`; a missing field does. After the rebuild, fill in the real values
and run `make apps ENV=prod` again. They only feed Homepage widgets and the Proxmox exporter.

## Items

| Item | Fields | Proton Pass type | Used by | Where to get it |
|---|---|---|---|---|
| `homelab-env` | The whole `homelab.env` as the note | Note | Nothing reads it; the copy to restore `homelab.env` on a new Mac | Your filled-in `homelab.env` ([workstation.md](workstation.md#site-values)); update it whenever the file changes |
| `opentofu` | `password` | Login | `homelab.env` (`TF_VAR_state_passphrase`) | Generate: 40+ characters, no quotes or backslashes. Never change in place (see below) |
| `proxmox-tofu-plan` | `password` (`tofu@pve!plan=<secret>`) | Login | Makefile (`PROXMOX_VE_API_TOKEN`, `make plan`) | `pveum user token add` on the host (below) |
| `proxmox-tofu-apply` | `password` (`tofu@pve!apply=<secret>`) | Login | Makefile (`make apply`, `guests`, `destroy`) | As above |
| `cloudflare-dns` | `password` | Login | `stacks/traefik/secrets/traefik.env.tpl` | Cloudflare, below |
| `github-dockhand` | `password` | Login | `dockhand_config` (Dockhand's git sync) | GitHub → Settings → Developer settings → Fine-grained token: this repo only, Contents read-only, ≤ 1 year |
| `proxmox-exporter` | `password` (secret only, no token id) | Login | `stacks/monitoring/secrets/monitoring-pve-exporter.env.tpl` | Placeholder until the host is rebuilt. After `make host`: `pveum user token add monitoring@pve exporter --privsep 1 --expire ...` (the role prints the command) |
| `proxmox-homepage` | `password` (secret only) | Login | `stacks/homepage/secrets/homepage.env.tpl` | Placeholder until the host is rebuilt, then `pveum user token add monitoring@pve homepage --privsep 1 --expire ...` |
| `pbs-homepage` | `username` (token id), `password` | Login | `homepage.env.tpl` | Placeholder until PBS is rebuilt. PBS → Configuration → Access Control → API Token (`username` is the token id, e.g. `root@pam!homepage`), then DatastoreAudit on the datastore and Audit on `/system` (the widget reads the node status too) |
| `pbs` | `password` | Login | `ansible/roles/pbs` (PBS root web login) | Generate |
| `adguard` | `username` (must be `admin`), `password`, `keepalived_auth_pass`, `replica_username`, `replica_password` | Login + custom fields | `adguard` role (login name fixed to `admin`, reads only the others); `homepage.env.tpl` and `monitoring-adguard-exporter.env.tpl` (all five) | Generate; keepalived: generate, at most 8 characters (`openssl rand -hex 4`); `replica_*`: the RPi3 AdGuard login |
| `samba` | `username`, `password` | Login | `samba` role | Generate (the Windows PC logs in with it) |
| `tailscale` | `password` (the auth key) | Login | `tailscale` role, first join only | Tailscale admin → Settings → Keys → Auth keys → Generate auth key (`tskey-auth-...`): reusable off, ephemeral off, pre-approved on. Right before `make config` (it is single-use and expires) |
| `tailscale-api` | `password`, `device_id` | Login + custom field | `homepage.env.tpl` | `password`: Tailscale admin → Settings → Keys → API access tokens → Generate access token (`tskey-api-...`, at most 90 days); an account token, valid across rebuilds. `device_id`: Machines → the `tailscale` machine → ID; it changes with every rebuild (the container joins as a new machine), so a placeholder until then |
| `vpn-services` | `password` (WireGuard `PrivateKey`) | Login | `stacks/vpn-services/secrets/vpn-services.env.tpl` | account.protonvpn.com → WireGuard configuration with NAT-PMP on |
| `kasm-vpn` | `password` (WireGuard `PrivateKey`), `note` (the rest of the `.conf`) | Login | Nothing reads it: typed into Kasm → Admin → Egress once, then lives in Kasm's database | account.protonvpn.com → WireGuard configuration, a second one (not `vpn-services`' key: one key, one tunnel), NAT-PMP off |
| `gluetun-api` | `password` | Login | `vpn-services-gluetun-auth.toml.tpl`, `homepage.env.tpl` | `openssl rand -hex 32` |
| `qbittorrent` | `username`, `password` | Login | `core_stacks` (hashed for qBittorrent), `homepage.env.tpl`, qBittorrent exporter | Generate |
| `speedtest-vpn` | `email`, `password`, `app_key` | Login + custom field | `vpn-services-speedtest.env.tpl` | `echo "base64:$(openssl rand -base64 32)"` for `app_key` |
| `speedtest` | `email`, `password`, `app_key` | Login + custom field | `speedtest-tracker.env.tpl` | `app_key`: `echo "base64:$(openssl rand -base64 32)"`; never change it, it encrypts the database |
| `authelia` | `username`, `password`, `jwt_secret`, `session_secret`, `storage_encryption_key` | Login + custom fields | `authelia.env.tpl`, `core_stacks` (the user), `linkding.env.tpl` | `username`/`password`: your single sign-on login; Ansible creates the Authelia user from them (a rebuild starts Authelia empty, so 2FA is set up again). Secrets: `openssl rand -hex 32` each |
| `dockhand` | `username`, `password`, `api_key` | Login + custom field | `dockhand_config` (local admin for the API); `api_key`: `homepage.env.tpl` (Dockhand widget) | Generate. `api_key`: Dockhand → API tokens, after the first `make apps` (until then a placeholder) |
| `hawser` | `docker-hw`, `kasm` | Other | `ansible/inventory/prod.yml`, `dockhand_config` | `openssl rand -hex 24` each |
| `dozzle` | `cert`, `key` (multi-line PEM) | Other | `stacks/dozzle/secrets/*.pem.tpl`, `stacks/agents/secrets/*.pem.tpl` | `docker run --rm -v "$PWD":/out amir20/dozzle generate-certs --cert-out /out/dozzle_cert.pem --key-out /out/dozzle_key.pem`, paste both, delete the files. Check the line breaks survived: `pass-cli item view pass://Homelab/dozzle/cert \| openssl x509 -noout -enddate` |
| `ntfy` | `username`, `password`, `token_grafana`, `token_scrutiny`, `token_clamav`, `token_pve`, `token_pbs` | Login + custom fields | `core_stacks`, `ntfy.env.tpl`, `monitoring-grafana.env.tpl`, `scrutiny.env.tpl`, `clamav` role, `pve_host` and `pbs` (Proxmox and PBS webhooks, host check scripts) | `username`/`password`: the phone's login. Tokens, one per sender (`tk_` + 29 lowercase letters or digits): `echo tk_$(LC_ALL=C tr -dc a-z0-9 </dev/urandom \| head -c 29)` |
| `grafana` | `username`, `password` | Login | `monitoring-grafana.env.tpl`, `homepage.env.tpl` | Generate |
| `homeassistant` | `homepage_token`, `samurai_mac` | Login + custom fields | `homepage.env.tpl`; `homelab.env` (`PC_MAC` for `make ha-deploy`) | `homepage_token`: HA → Profile → Security → long-lived token. Tokens are part of HA's backup: one made before the last backup still works after the restore. `samurai_mac`: the PC's MAC for Wake-on-LAN |
| `beszel` | `username`, `password`, `hub_key` (multi-line private key), `hub_pubkey` | Login + custom fields | `homepage.env.tpl`; `hub_key`: `stacks/beszel/secrets/beszel_key.pem.tpl`; `hub_pubkey`: the `common` role and both `beszel-agent.env.tpl` | Generate. Beszel logs in with an email, so `username` holds the email; create that login on Beszel's first-run screen. Key pair: `ssh-keygen -t ed25519 -N '' -C beszel -f beszel_hub`, `hub_key` = the file, `hub_pubkey` = the `.pub` line, then delete both files. A new pair needs `make config` and `make apps` so every agent gets the new public key |
| `changedetection` | `api_key` | Other | `homepage.env.tpl` | Placeholder until the rebuild, then changedetection → Settings → API |
| `plex` | `token` | Other | `homepage.env.tpl` | Plex Web → Get Info → View XML → `X-Plex-Token`, or on the host: `pct exec 101 -- grep -o 'PlexOnlineToken="[^"]*' '/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml'`. New after claiming the fresh server |
| `tautulli` | `api_key` | Other | `homepage.env.tpl` | Placeholder until the rebuild, then Tautulli → Settings → Web Interface → API key |
| `frigate` | `username`, `password`, `mqtt_user`, `mqtt_password`, `rtsp_user`, `rtsp_password` | Login + custom fields | `stacks/frigate/secrets/frigate.env.tpl` (MQTT, RTSP), `homepage.env.tpl` (viewer login) | MQTT: the login of HA's broker (Mosquitto add-on → Configuration → `logins`); it must match, since HA is restored from its backup. Viewer: generate, then create that user in Frigate → Settings → Users once Frigate runs. RTSP: generate, then set the same login in HA's Frigate integration |
| `immich` | `api_key`, `db_password` | Login + custom fields | `homepage.env.tpl`, `immich.env.tpl`, `immich-db.env.tpl` | `db_password`: must match the database on the USB disk, so copy it from the running server: `pct exec 104 -- docker exec immich_postgres printenv POSTGRES_PASSWORD` (generate only for a brand-new Immich). `api_key`: Immich → Account Settings → API Keys → New API Key with only `server.statistics`; it survives a rebuild |
| `freshrss` | `username`, `api_password` | Login + custom field (`api_password`, not the built-in password) | `homepage.env.tpl` | Placeholder until the rebuild, then FreshRSS → Settings → Profile → API password |
| `mealie` | `api_key` | Other | `homepage.env.tpl` | Placeholder until the rebuild, then Mealie → profile → API Tokens |
| `vikunja` | `jwt_secret` | Other | `vikunja.env.tpl` | `openssl rand -hex 32` |
| `convertx` | `jwt_secret` | Other | `convertx.env.tpl` | `openssl rand -hex 32` |
| `searxng` | `secret_key` | Other | `searxng.env.tpl` | `openssl rand -hex 32` |
| `filebrowser` | `password` | Login (username admin) | `filebrowser.env.tpl` | Generate |

Outside `pass://`:

| Credential | Where it lives |
|---|---|
| Vault access token (read-only, `Homelab` vault) | macOS Keychain, service `proton-pass-pat` ([workstation.md](workstation.md)) |
| Mac SSH key `mac-homelab` | `~/.ssh`; public key in `group_vars/all.yml` and `tofu/variables.tf` |
| Proxmox root password | Vault, `proxmox-root` (Login) |
| GitHub token for the Forgejo pull mirror | Vault, `github-forgejo` (Login, `password`): fine-grained, the mirrored repos only, Contents read-only, at most 1 year. Pasted into each mirror in Forgejo |
| Proton account recovery phrase | Offline |
| Gatus' ntfy.sh topic | Gatus' `.env` on the RPi3 (outside the repo) |

Generated, nothing to store: the PBS backup token `pve@pbs!vzdump`, Authelia's OIDC client secrets,
Hawser TLS keys, Kasm's install passwords, Forgejo's own secrets, and the qBittorrent and ntfy password hashes.

## Rotating a credential

Create the new one, update the vault item, re-run its consumer (`make apps`, the role, or nothing for
OpenTofu tokens), check it works, then revoke the old one.

## Proxmox tokens for OpenTofu

`make host` creates the user `tofu@pve`, the role `TofuApply` and all ACLs. The tokens are created by hand
because Proxmox shows their secret only once and it has to go into the vault. On the host:

```bash
pveum user token add tofu@pve plan --privsep 1 --expire $(date -d '+1 year' +%s) --comment "tofu plan, read-only"
pveum user token add tofu@pve apply --privsep 1 --expire $(date -d '+1 year' +%s) --comment "tofu apply"
```

Store each as a Login item `proxmox-tofu-plan` / `proxmox-tofu-apply` with the password
`tofu@pve!<name>=<secret>`, then run `make host` again to add the token ACLs. Check:

```bash
pveum user token permissions tofu@pve plan    # only *.Audit
```

After a Proxmox reinstall both tokens must be created again. The monitoring tokens (`proxmox-exporter`, `proxmox-homepage`) store the secret alone, without the
`monitoring@pve!<name>=` prefix: the token id is set in the stacks.

## Cloudflare DNS token (Traefik)

Cloudflare → My Profile → API Tokens → "Edit zone DNS" template. Permissions `Zone · Zone · Read` and
`Zone · DNS · Edit`, zone resources: only the homelab zone, no IP filter, TTL start today and end in one
year (a start date in the future makes the token valid but unusable). Item: `cloudflare-dns`.

## OpenTofu state passphrase

Item `opentofu`: 40+ characters, no quotes or backslashes (they break the encryption config). Never change
it in place: add the new key and keep the old one as `fallback` until the state is re-encrypted.
