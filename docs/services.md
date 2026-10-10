# Services

## Docker stacks

| Host | Group | Stacks |
|---|---|---|
| docker-hw (CT 104, privileged) | Hardware | frigate (+ mic; Coral, webcam, sound, iGPU), immich (iGPU machine learning; library and database on the USB disk) |
| docker-hw | Agents | socket-proxy, hawser, beszel-agent, dozzle-agent, alloy |
| docker-apps (CT 109) | Core (bootstrapped by Ansible) | socket-proxy, traefik, authelia, dockhand |
| docker-apps | Monitoring | monitoring (prometheus + grafana + exporters for Proxmox, qBittorrent, AdGuard; loki + alloy), beszel, dozzle, scrutiny, speedtest-tracker, librespeed, changedetection, ntfy, homepage |
| docker-apps | Media | calibre-web (Calibre-Web Automated), metube, tautulli, vpn-services (gluetun + qBittorrent + speedtest through the VPN, with port sync) |
| docker-apps | Productivity | mealie, freshrss, wallos, vikunja, memos, linkding |
| docker-apps | Tools | convertx, stirling-pdf, excalidraw, searxng, code-server, forgejo, filebrowser, syncthing, rustdesk |

Plex, Kasm, AdGuard, PBS, Tailscale, Samba and ClamAV (security) each have their own LXC, and Home Assistant is
a VM.

Dockhand itself is configured as code. The `dockhand_config` role uses its HTTP API to create the admin,
enable login, add the GitHub credential and the repository (branch `deploy`), and create every git stack
listed in the inventory. docker-apps' list is `docker_apps_stacks` in `group_vars/docker_apps.yml`; each
stack gets the site values (`homelab_stack_env`) as env vars. Adding an app takes a folder under `stacks/`
and one list entry. From then on, a merge to `main` followed by `make release` redeploys it within
5 minutes ([ADR 4](adr/4-pull-based-deploys.md)).

Dockhand on docker-apps manages three environments: docker-apps (local), docker-hw (Hawser agent) and
kasm (Hawser, monitor-only: Kasm manages its own containers and upgrades). Hawser runs in standard mode:
Dockhand connects to port 2376 over TLS with the host's token, the key is made on that host, and Dockhand
trusts exactly its certificate. Ansible starts Hawser (`core_stacks` with `core_stacks_names: [hawser]`),
and Dockhand then deploys docker-hw's stacks (agents, frigate, immich) through it. The environments and
their stacks come from the inventory (`dockhand_config_remotes` on docker-apps, each host's own
`dockhand_config_stacks`).

## Conventions

- Every `compose.yml` deploys with plain `docker compose up -d`: absolute host paths, secrets via
  `env_file: /opt/secrets/<stack>.env`, no manager-only features. That file comes from
  `stacks/<stack>/secrets/<stack>.env.tpl` (lines like `KEY={{ pass://Homelab/<item>/<field> }}`), filled in
  by Ansible with `pass-cli inject`. A stack can have several (one per container, or a config file).
- Site values (domain, timezone, LAN range, host and device IPs) are `${VAR}` in compose files, from the
  stack's `.env` or Dockhand's env vars. No compose file carries a literal domain, timezone or site IP.
- One stack is one folder. Data lives in `/opt/appdata/<stack>` or on `/mnt/external`, never in the repo.
  On docker-apps only `Books`, `Downloads`, `Movies`, `Shared` and `Torrents` exist under `/mnt/external`;
  on docker-hw only `FrigateNVR` and `Personal/Immich`.
- Web services join the shared `proxy` network. Traefik labels declare the hostname `<name>.<domain>` and
  the middlewares (headers, LAN/Tailscale allow-list, Authelia). Homepage entries live in one file,
  `stacks/homepage/config/services.yaml`, with widget secrets as `HOMEPAGE_VAR_*` from the vault.
- Bind-mounted data folders are created by Docker as root, so images that run as a fixed non-root user
  (Prometheus, Grafana, Loki) run as root in the container instead; the LXC is unprivileged.
- Apps that trust Authelia's `Remote-User` header (Dockhand, Forgejo, Linkding, Dozzle), and code-server
  (a shell with only Authelia in front), are not on `proxy`. Each has its own network that Traefik joins
  (created by `core_stacks`), so app containers can't reach them to fake the header. Dozzle also sits on
  `socket-proxy` with Beszel and Alloy ([security.md](security.md#accepted-trade-offs)). Their API/git
  routes that skip Authelia strip the header (`api-bypass`).
- Loki and Prometheus are on the `monitoring` network only ([security.md](security.md#privilege-model)).
- Images that must run as a fixed non-root uid with a bind-mounted data folder get a one-shot `<stack>-init`
  service (busybox `chown`) instead of root (File Browser).
- Images are pinned to a version tag and digest, and Renovate bumps them. `stacks/check.sh` enforces that
  and the other container rules ([security.md](security.md#scanning-and-supply-chain)).
- `no-new-privileges` is set daemon-wide (`/etc/docker/daemon.json`), so compose files don't repeat it.
- code-server and File Browser don't mount `/opt`; Syncthing uses no relay.

## DNS (AdGuard)

- CT 106 is keepalived MASTER for the VIP (.5); the RPi3 is BACKUP and receives the config through
  adguardhome-sync.
- One wildcard rewrite: `*.<domain>` → docker-apps.
- Blocklists: HaGeZi Pro++, HaGeZi TIF, Most Abused TLDs, a Turkish ad list. Query log
  14 days, rate limit off.
