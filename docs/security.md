# Security

## Access

- No app is exposed to the internet. Apps are reached over the LAN or Tailscale under one Let's Encrypt
  wildcard certificate (Cloudflare DNS-01). No tunnels, no public DNS records pointing home.
- The one exception is Plex: the router forwards 32400 to its unprivileged LXC, outside Traefik. Plex's
  Traefik route strips the `Cookie` header, so Plex never sees the Authelia session cookie.
- Authelia handles login with 2FA, as forward-auth in front of the apps and as the OIDC provider for
  Dockhand, Grafana, Vikunja, Mealie, Memos, File Browser and Calibre-Web. The Authelia group `admins` is the
  admin in those apps. OIDC keys and client secrets are generated on docker-apps and never leave it.
- The server only connects out: Dockhand pulls from GitHub, Renovate and CI run on GitHub. GitHub holds no
  deploy credentials.
- A push to `main` deploys nothing. Only `make release` moves `deploy`, and only to a commit CI passed
  ([ADR 4](adr/4-pull-based-deploys.md)).
- SSH is key-only on the host and every LXC (`/etc/ssh/sshd_config.d/10-homelab.conf`). The Proxmox root
  password still works for the web UI and console.

## Privileges

- Every LXC is unprivileged except docker-hw, which needs the Coral and the webcam
  ([ADR 5](adr/5-docker-split.md)). nas, docker-apps and security map uid/gid 1000-1001 straight through,
  because the USB disk's files are owned by 1000/1001.
- The USB disk is mounted per folder:

  | Guest | Sees |
  |---|---|
  | docker-apps | `Books`, `Downloads`, `Movies`, `Shared`, `Torrents` (so File Browser sees only these) |
  | docker-hw | `FrigateNVR`, `Personal/Immich` |
  | pbs | `Backups` |
  | nas | Everything; `Backups` and `Proxmox` are vetoed on the share |
  | security | Everything, read-only |

- OpenTofu never gets root. It uses two API tokens: `tofu@pve!plan` (`PVEAuditor`) and `tofu@pve!apply`
  (role `TofuApply`: guest allocate and config, power, datastore space, network use, `Sys.Audit`; no
  users, ACLs, storage, node config or `Sys.Modify`). Root-only settings go through Ansible over SSH
  ([ADR 3](adr/3-root-only-steps-in-ansible.md)).
- Backups use `pve@pbs!vzdump`, which may only back up to the one datastore. The pbs role writes its secret
  straight into the host's root-only storage config.
- Docker socket: only Dockhand, Hawser and the Dozzle agent use the real socket. Traefik, Dozzle, Beszel
  and Alloy go through `wollomatic/socket-proxy`, which allows only those clients and only GET on `_ping`,
  `version`, `info`, `events`, `networks` and container list, inspect, logs and stats.
- Dockhand has its own network shared only with Traefik, so app containers can't reach its API.
- Apps that trust Authelia's identity headers (Forgejo, Linkding, Dozzle, FreshRSS, Beszel) trust them only
  from their own network, where Traefik is the only other member. FreshRSS and Beszel also sit on `proxy`
  for Homepage's widgets; a forged header from there gets a 403 or 401.
- Loki and Prometheus sit on a `monitoring` network that only Traefik, Grafana, Alloy and Homepage join.
- Every Docker daemon sets `no-new-privileges` (except kasm, whose workspace images use sudo).
- The Samba share has guest access off, and its user has no shell.

## Secrets

- Secret values exist in plain text only in the vault and in root-only files on the target hosts. Git, CI
  and the docs hold `pass://` references ([architecture](architecture.md#config-and-secrets)).
- Site values aren't secret but stay out of the public repo, in the gitignored `homelab.env`. `make
  leak-check` fails on any `192.168.x.x` in a tracked file and, locally, on any `homelab.env` value of
  6+ characters ([ADR 2](adr/2-secrets-and-site-values.md)).
- The vault is read with a Proton Pass access token: read-only, `Homelab` vault only, one-year expiry,
  stored in the macOS Keychain.
- The Tailscale auth key passes through a root-only file in `/run` that exists only while `tailscale up`
  runs. Two bootstrap secrets do briefly appear on a command line: Kasm's throwaway install passwords and
  the PBS token in `pvesm add`.
- OpenTofu state is encrypted and committed ([ADR 1](adr/1-opentofu-encrypted-state.md)).
- Break-glass: the vault is reachable from the phone and another computer, and the account recovery phrase
  is kept offline.

## Credentials

Every item and field in the vault, and how to create each, is in
[credentials.md](runbooks/credentials.md). All of them are reviewed yearly, with the token expiries.

| Credential | Scope | Rotation |
|---|---|---|
| Proton Pass access token | `Homelab` vault, read-only | 1 year |
| `tofu@pve!plan` / `!apply` | `PVEAuditor` / `TofuApply` | 1 year; new after a reinstall |
| `monitoring@pve!exporter` / `!homepage` | `PVEAuditor` | 1 year; new after a reinstall |
| `pve@pbs!vzdump` | Backup to one datastore | Recreated by the pbs role |
| PBS Homepage token | Datastore audit | 1 year |
| Mac SSH key | Root on the host and LXCs | On device change |
| OpenTofu state passphrase | Decrypts the committed state | New key + `fallback` block |
| Cloudflare token | DNS edit on one zone | 1 year |
| GitHub tokens (Dockhand, Forgejo mirror) | This repo, contents read-only | 1 year at most |
| Renovate app | This repo | Uninstall to revoke |
| ntfy sender tokens (Grafana, Scrutiny, ClamAV, Proxmox host, PBS) | Write-only on `homelab-*`, one per sender | Per sender |
| Hawser tokens | Full Docker API on docker-hw or kasm, over TLS | On suspicion, both sides |
| Dozzle agent certificate | Reads docker-hw's container logs (mutual TLS) | On suspicion |
| Frigate RTSP login | Camera streams | On suspicion; update HA too |
| OIDC client secrets | Dockhand, Grafana, Vikunja, Mealie, Memos, File Browser, Calibre-Web login | Regenerated on reinstall |
| Tailscale auth key | First join only | Expires by itself |
| Service secrets (Authelia, databases, keepalived, admin logins) | One item per stack, rendered to `/opt/secrets/<stack>.env` | On suspicion |

## Scanning and supply chain

CI runs on every push and PR:

- gitleaks over the full history, `trivy config`, yamllint, ansible-lint (production profile),
  `tofu fmt` and `validate`, the encrypted-state check, `make leak-check`, HA's config check.
- `stacks/check.sh` renders every stack and fails on: an image without a digest, `privileged`, host
  network or PID namespace, `cap_add` of `ALL`, `SYS_ADMIN`, `SYS_PTRACE` or `SYS_MODULE`, an `unconfined`
  security option, or a Docker socket mount outside the socket proxies, the Dozzle agent, Dockhand and
  Hawser.

Supply chain:

- Actions pinned by SHA; linters pinned in `requirements-ci.txt`; gitleaks, OpenTofu and Trivy versions
  pinned in `ci.yml` and bumped by Renovate. The gitleaks download is checksum-verified.
- Renovate waits 3 days after a release, pins image digests, and raises OSV and GitHub vulnerability
  alerts.
- Apt signing keys (Docker, Tailscale, Plex) and the HAOS image are checked against pinned SHA-256 sums;
  LXC templates against Proxmox's signed index.
- Dockhand scans running images (Grype/Trivy).
- ClamAV runs on its own LXC with the USB disk read-only, so a scanner exploit can't change files. It
  skips `Backups`, `Proxmox`, `FrigateNVR`, `Personal/Immich` and files over 100 MB, never moves or deletes
  anything, and runs at half a core with 2 GB RAM. Detections go to ntfy `homelab-security`.

## Accepted trade-offs

- docker-hw is privileged, and shares a USB bus with the backup disk. Root there is root on the host.
  The N150 has one USB controller, so passing the whole bus for the Coral also exposes the backup disk.
  Accepted because docker-hw is reachable only from the LAN and Tailscale. The fix would be an
  unprivileged docker-hw that gets only the Coral's device node, re-injected when it re-enumerates (as
  `lxc-video-sync` does for the webcam).
- No host intrusion detection. An agent costs more CPU and RAM than one N150 with nothing exposed
  justifies.
- One node, so no high availability.
- No off-site backup ([ADR 7](adr/7-no-offsite-backup.md)). Recovery point: up to 3 days.
- The vault must be reachable for a rebuild, mitigated by break-glass access.
- Self-signed certificates aren't verified. OpenTofu, the Proxmox exporter and Homepage skip
  verification of the Proxmox API, and Traefik does the same towards the other self-signed UIs. Pinning their
  CAs would break on every reinstall.
- Home Assistant, Plex, Immich and Frigate have no Authelia in front, because their phone apps can't
  log in through it. They use their own logins, on LAN and Tailscale only.
- Home Assistant trusts docker-apps as its proxy, so a container there could forge
  `X-Forwarded-For`. HA bans an IP after 5 failed logins.
- The socket proxy's `inspect` returns environment variables, so a compromised Traefik, Dozzle, Beszel
  or Alloy could read other containers' env secrets.
- Dozzle trusts Authelia's `Remote-User` header and shares a network with Beszel and Alloy, which could
  forge it. They can already read the same data through the proxy, and Dozzle's actions and shell are off.
- AdGuard sync to the RPi3 is plain HTTP, so the replica's admin password crosses the LAN every
  5 minutes.
- Traefik's `/api/overview` (router, service and middleware counts) answers without login on the
  internal port 8080, for Homepage's widget. That port isn't published on the host.
- Dockhand's `/api/dashboard/stats` skips Authelia so Homepage's widget can read it with a Dockhand API
  token. It's the only Dockhand path without Authelia, read-only, and reachable from the LAN, Tailscale
  and containers on `proxy`.
- The repo is public: MACs, VMIDs, host numbers and the encrypted state are readable. None grants
  access.
- Passthrough (iGPU, Coral, webcam) can only be tested on the real server.
- Dockhand starts with login off until `dockhand_config` creates the admin seconds later in the same
  run. Only processes on docker-apps or someone past Authelia can reach it then, and if someone else
  created the admin first, the role's login fails.
