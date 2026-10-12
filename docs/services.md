# Services

## Docker stacks

| Host | Group | Stacks |
|---|---|---|
| docker-hw | Hardware | frigate (+ MediaMTX for the webcam mic; Coral, webcam, iGPU), immich (iGPU machine learning; library and database on the USB disk) |
| docker-hw | Agents | socket-proxy, hawser, beszel-agent, dozzle-agent, alloy |
| docker-apps | Core, started by Ansible | socket-proxy, traefik, authelia, dockhand |
| docker-apps | Monitoring | monitoring (Prometheus, Grafana, Loki, Alloy, exporters for Proxmox, qBittorrent, AdGuard), beszel, dozzle, scrutiny, speedtest-tracker, librespeed, changedetection, ntfy, homepage |
| docker-apps | Media | calibre-web, metube, tautulli, vpn-services (Gluetun + qBittorrent + Speedtest Tracker through the VPN) |
| docker-apps | Productivity | mealie, freshrss, wallos, vikunja, memos, linkding |
| docker-apps | Tools | convertx, stirling-pdf, excalidraw, searxng, code-server, forgejo (+ Gitea Mirror), filebrowser, syncthing, rustdesk |

Plex, Kasm, AdGuard, PBS, Tailscale, Samba and ClamAV each have their own LXC; Home Assistant is a VM.

## Dockhand

Dockhand on docker-apps manages three environments: itself, docker-hw and kasm. It reaches the other two
through Hawser agents on port 2376 over TLS; each agent's key is made on its own host and Dockhand trusts
exactly that certificate. kasm is monitor-only, since Kasm manages its own containers.

The `dockhand_config` role sets Dockhand up through its API: admin, login, GitHub credential, repository
(branch `deploy`), and one git stack per entry in the inventory (`docker_apps_stacks` in
`group_vars/docker_apps.yml`, `[agents, frigate, immich]` for docker-hw). Each stack gets
`homelab_stack_env` as env vars.

Adding an app: a folder under `stacks/`, one line in `docker_apps_stacks`, `make apps ENV=prod` once to
register it. After that, a merge and `make release` redeploy it within 5 minutes.

## Stack conventions

- Every `compose.yml` works with plain `docker compose up -d`: absolute host paths, no manager-only
  features.
- Secrets come from `env_file: /opt/secrets/<stack>.env`, rendered by Ansible from
  `stacks/<stack>/secrets/*.tpl` (`KEY={{ pass://Homelab/<item>/<field> }}`).
- Site values are `${VAR}`. No compose file has a literal domain, timezone or IP.
- Data lives in `/opt/appdata/<stack>` or on `/mnt/external`, never in the repo.
- Web apps join the `proxy` network. Traefik labels set the hostname `<name>.<domain>` and the middlewares
  (headers, LAN/Tailscale allow-list, Authelia). Homepage entries are all in
  `stacks/homepage/config/services.yaml`.
- Apps that trust Authelia's `Remote-User` header (Dockhand, Forgejo, Gitea Mirror, Linkding, Dozzle) and code-server
  aren't on `proxy`. Each has its own network that only Traefik joins, so other containers can't forge the
  header. Their API and git routes that skip Authelia strip it.
- Images are pinned by tag and digest. `stacks/check.sh` enforces this and the other container rules
  ([security.md](security.md#scanning-and-supply-chain)).
- Prometheus, Grafana and Loki run as root in the container, because Docker creates their bind-mounted
  folders as root (the LXC is unprivileged). File Browser instead gets a one-shot `chown` init service.
- Forgejo: app data (`app.ini`, SQLite) in `/opt/appdata/forgejo`, the repositories only on the USB disk
  (`/mnt/external/Forgejo`, also on the Samba share). They are bare repos: `git clone` one straight from the
  share if Forgejo is down. Gitea Mirror creates a pull mirror per GitHub repo; Forgejo syncs them every 8h.
- code-server and File Browser don't mount `/opt`. Syncthing uses no relay.

## DNS (AdGuard)

- CT 106 holds the VIP (.5) as keepalived MASTER; the RPi3 is BACKUP and gets the config through
  adguardhome-sync.
- One wildcard rewrite: `*.<domain>` to docker-apps.
- Blocklists: HaGeZi Pro++, HaGeZi Threat Intelligence Feeds, HaGeZi Most Abused TLDs, Turkish ad hosts.
- Query log 14 days, no rate limit.
