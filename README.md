# Proxmox Infra

Infrastructure as code for a single-node Proxmox VE homelab: 10 guests and about 40 services, rebuilt from
this repo, a password manager vault and a data restore.

- OpenTofu (`bpg/proxmox`) creates the LXCs and the Home Assistant VM, with encrypted state in the repo.
- Ansible configures the host, the root-only container settings and every guest.
- Docker stacks deploy from `stacks/` through Dockhand, which pulls a `deploy` branch that only moves after
  CI passes.
- Secrets live in a password manager vault (Proton Pass, read with a vault-scoped, read-only
  [access token](https://proton.me/blog/pass-access-tokens)); the repo holds `pass://` references. Site
  values (domain, addresses) live in the gitignored `homelab.env`, documented by `homelab.env.example`,
  and reach every `make` target as environment variables ([ADR 2](docs/adr/2-secrets-and-site-values.md)).
- CI (GitHub Actions) lints, validates, and scans for secrets and misconfigurations. It never deploys.

Start with [docs/architecture.md](docs/architecture.md); the full index is in [docs/](docs/README.md).
Shipping a change: [runbooks/release.md](docs/runbooks/release.md).

## Commands

| Command | What |
|---|---|
| `make init ENV=lab\|prod` | `tofu init` + workspace |
| `make lint` | Everything CI runs, plus `make leak-check` against your `homelab.env` |
| `make plan ENV=...` | `tofu plan` with the read-only token |
| `make apply ENV=...` | `tofu apply` with the apply token (asks first) |
| `make guests ENV=...` | `make apply`, then the root-only container config |
| `make destroy ENV=...` | Remove the environment's guests |
| `make host-check` / `make host` | Host baseline: diff only / apply |
| `make devices-check ENV=...` | Diff of the root-only container config |
| `make config-check ENV=...` / `make config ENV=...` | Guest roles: diff only / apply |
| `make apps ENV=...` | Core stacks, stack secrets, Dockhand's setup |
| `make release` | Move the `deploy` branch to `origin/main`, only if CI on that commit is green |
| `make ha-check` / `make ha-deploy` | Home Assistant config: check / copy to the VM and restart |
| `make pin-kernel VERSION=...` / `make unpin-kernel` | When a new kernel breaks something |

`ENV=lab` is the default. `apply` and `destroy` with `ENV=prod` need `CONFIRM=yes`. Every target that
needs site values or secrets runs under `pass-cli run --env-file homelab.env`, so copy
`homelab.env.example` to `homelab.env` and fill it in first
([workstation](docs/runbooks/workstation.md#site-values)).

## Known trade-offs

Single node, no off-site backup, a privileged container for the Coral and webcam, the password manager
required for a rebuild, Proxmox API certificate not verified. Details and reasons are in
[docs/security.md](docs/security.md#accepted-trade-offs).

## Tech stack

### Platform and IaC

| | Tool | Role here |
|---|---|---|
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/proxmox-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/proxmox.svg" alt="Proxmox VE" width="20" height="20"></picture> | [Proxmox VE](https://www.proxmox.com/en/products/proxmox-virtual-environment/overview) | Hypervisor for the 10 LXCs and the Home Assistant VM |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/opentofu.svg" alt="OpenTofu" width="20" height="20"> | [OpenTofu](https://opentofu.org) | Creates the guests via `bpg/proxmox`; state encrypted in the repo |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/ansible-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/ansible.svg" alt="Ansible" width="20" height="20"></picture> | [Ansible](https://www.ansible.com) | Host baseline, root-only container settings, every guest's setup |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/debian-linux.svg" alt="Debian" width="20" height="20"> | [Debian](https://www.debian.org) | OS of every LXC except Plex |
| <img src="https://svgl.app/library/ubuntu.svg" alt="Ubuntu" width="20" height="20"> | [Ubuntu](https://ubuntu.com) | OS of the Plex LXC |
| <img src="https://svgl.app/library/docker.svg" alt="Docker" width="20" height="20"> | [Docker](https://www.docker.com) | Engine and Compose on docker-apps and docker-hw |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/dockhand.png" alt="Dockhand" width="20" height="20"> | [Dockhand](https://dockhand.pro) | Deploys `stacks/` as git stacks from the `deploy` branch |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/dockhand.png" alt="Hawser" width="20" height="20"> | [Hawser](https://github.com/Finsys/hawser) | Dockhand agent on docker-hw and Kasm (TLS, port 2376) |
| <img src="https://svgl.app/library/home-assistant.svg" alt="Home Assistant" width="20" height="20"> | [Home Assistant](https://www.home-assistant.io) | HAOS VM; config as code in `homeassistant/` |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/proxmox-backup-server-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/proxmox-backup-server.svg" alt="Proxmox Backup Server" width="20" height="20"></picture> | [Proxmox Backup Server](https://www.proxmox.com/en/products/proxmox-backup-server/overview) | Guest backups, datastore on the USB disk |

### Automation, CI and secrets

| | Tool | Role here |
|---|---|---|
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://svgl.app/library/github_dark.svg"><img src="https://svgl.app/library/github_light.svg" alt="GitHub" width="20" height="20"></picture> | [GitHub](https://github.com) | Hosts the repo; Dockhand pulls the `deploy` branch from it |
| <img src="https://cdn.simpleicons.org/githubactions" alt="GitHub Actions" width="20" height="20"> | [GitHub Actions](https://github.com/features/actions) | CI: `make lint` and `make ha-check`; never deploys |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/renovate.svg" alt="Renovate" width="20" height="20"> | [Renovate](https://docs.renovatebot.com) | Bumps image tags and digests, providers, actions, CI tools |
| <img src="https://github.com/gitleaks.png?size=40" alt="Gitleaks" width="20" height="20"> | [Gitleaks](https://gitleaks.io) | Secret scan of the git history |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/trivy.png" alt="Trivy" width="20" height="20"> | [Trivy](https://trivy.dev) | Misconfiguration scan (`trivy config`) |
| <img src="https://cdn.simpleicons.org/yaml" alt="yamllint" width="20" height="20"> | [yamllint](https://github.com/adrienverge/yamllint) | YAML lint |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/ansible-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/ansible.svg" alt="ansible-lint" width="20" height="20"></picture> | [ansible-lint](https://ansible.readthedocs.io/projects/lint/) | Lints the roles and playbooks |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/proton-pass.svg" alt="Proton Pass" width="20" height="20"> | [Proton Pass](https://proton.me/pass) | Vault for every secret; `pass-cli` resolves `pass://` references at deploy time |

### Networking and security

| | Tool | Role here |
|---|---|---|
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/traefik.svg" alt="Traefik" width="20" height="20"> | [Traefik](https://traefik.io/traefik) | Reverse proxy for every app, wildcard TLS |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/authelia.svg" alt="Authelia" width="20" height="20"> | [Authelia](https://www.authelia.com) | Single sign-on via forward-auth |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/lets-encrypt.svg" alt="Let's Encrypt" width="20" height="20"> | [Let's Encrypt](https://letsencrypt.org) | Wildcard certificate for `*.<domain>` |
| <img src="https://svgl.app/library/cloudflare.svg" alt="Cloudflare" width="20" height="20"> | [Cloudflare](https://www.cloudflare.com) | DNS for the domain; DNS-01 challenge with a single-zone token |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/tailscale-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/tailscale.svg" alt="Tailscale" width="20" height="20"></picture> | [Tailscale](https://tailscale.com) | Remote access: subnet router and exit node |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/adguard-home.svg" alt="AdGuard Home" width="20" height="20"> | [AdGuard Home](https://adguard.com/en/adguard-home/overview.html) | LAN DNS, blocklists, wildcard rewrite to docker-apps |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/keepalived.png" alt="keepalived" width="20" height="20"> | [keepalived](https://www.keepalived.org) | DNS virtual IP, fails over to the RPi3 |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/gluetun.svg" alt="Gluetun" width="20" height="20"> | [Gluetun](https://github.com/qdm12/gluetun) | VPN client in front of qBittorrent, with port sync |
| <img src="https://svgl.app/library/docker.svg" alt="Socket Proxy" width="20" height="20"> | [Socket Proxy](https://github.com/wollomatic/socket-proxy) | Filtered Docker API for Traefik, Dozzle, Beszel and Alloy |
| <img src="https://github.com/Cisco-Talos.png?size=40" alt="ClamAV" width="20" height="20"> | [ClamAV](https://www.clamav.net) | Scheduled scans of the USB disk, mounted read-only |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/samba-server.svg" alt="Samba" width="20" height="20"> | [Samba](https://www.samba.org) | SMB share of the USB disk for the Windows PC |

### Observability

| | Tool | Role here |
|---|---|---|
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/prometheus.svg" alt="Prometheus" width="20" height="20"> | [Prometheus](https://prometheus.io) | Metrics, with exporters for Proxmox, qBittorrent and AdGuard |
| <img src="https://svgl.app/library/grafana.svg" alt="Grafana" width="20" height="20"> | [Grafana](https://grafana.com/oss/grafana/) | Dashboards, log search and alerts |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/loki.svg" alt="Loki" width="20" height="20"> | [Loki](https://grafana.com/oss/loki/) | Log store, 30 days |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/alloy.svg" alt="Alloy" width="20" height="20"> | [Alloy](https://grafana.com/oss/alloy-opentelemetry-collector/) | Ships container and journal logs to Loki |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/beszel-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/beszel.svg" alt="Beszel" width="20" height="20"></picture> | [Beszel](https://beszel.dev) | Lightweight host and container stats |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/dozzle.svg" alt="Dozzle" width="20" height="20"> | [Dozzle](https://dozzle.dev) | Live container log tail |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/scrutiny-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/scrutiny.svg" alt="Scrutiny" width="20" height="20"></picture> | [Scrutiny](https://github.com/AnalogJ/scrutiny) | Disk SMART health |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/speedtest-tracker.png" alt="Speedtest Tracker" width="20" height="20"> | [Speedtest Tracker](https://github.com/alexjustesen/speedtest-tracker) | Scheduled speed tests through the VPN |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/librespeed-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/librespeed.svg" alt="LibreSpeed" width="20" height="20"></picture> | [LibreSpeed](https://github.com/librespeed/speedtest) | LAN speed test |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/changedetection.svg" alt="changedetection.io" width="20" height="20"> | [changedetection.io](https://changedetection.io) | Website change alerts |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/ntfy.svg" alt="ntfy" width="20" height="20"> | [ntfy](https://ntfy.sh) | Push notifications for every alert |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/homepage.png" alt="Homepage" width="20" height="20"> | [Homepage](https://gethomepage.dev) | Start page with service widgets |

### Media and home

| | Tool | Role here |
|---|---|---|
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/plex-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/plex.svg" alt="Plex" width="20" height="20"></picture> | [Plex](https://www.plex.tv) | Media server with iGPU transcoding |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/tautulli.svg" alt="Tautulli" width="20" height="20"> | [Tautulli](https://tautulli.com) | Plex stats |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/calibre-web.svg" alt="Calibre-Web Automated" width="20" height="20"> | [Calibre-Web Automated](https://github.com/crocodilestick/Calibre-Web-Automated) | E-book library |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/metube.svg" alt="MeTube" width="20" height="20"> | [MeTube](https://github.com/alexta69/metube) | Video downloader (yt-dlp web UI) |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/qbittorrent.svg" alt="qBittorrent" width="20" height="20"> | [qBittorrent](https://www.qbittorrent.org) | Torrents, only through Gluetun |
| <picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/frigate-light.svg"><img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/frigate.svg" alt="Frigate" width="20" height="20"></picture> | [Frigate](https://frigate.video) | NVR with Coral object detection |
| <img src="https://github.com/bluenviron.png?size=40" alt="MediaMTX" width="20" height="20"> | [MediaMTX](https://github.com/bluenviron/mediamtx) | Publishes the webcam microphone over RTSP for Frigate |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/immich.svg" alt="Immich" width="20" height="20"> | [Immich](https://immich.app) | Photo library with iGPU machine learning |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/kasm-workspaces.svg" alt="Kasm Workspaces" width="20" height="20"> | [Kasm Workspaces](https://kasm.com) | Browser-based desktops and apps |

### Productivity

| | Tool | Role here |
|---|---|---|
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/mealie.svg" alt="Mealie" width="20" height="20"> | [Mealie](https://mealie.io) | Recipes and meal plans |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/freshrss.svg" alt="FreshRSS" width="20" height="20"> | [FreshRSS](https://freshrss.org) | RSS reader |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/wallos.png" alt="Wallos" width="20" height="20"> | [Wallos](https://wallosapp.com) | Subscription tracker |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/vikunja.svg" alt="Vikunja" width="20" height="20"> | [Vikunja](https://vikunja.io) | Tasks and projects |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/memos.svg" alt="Memos" width="20" height="20"> | [Memos](https://usememos.com) | Notes |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/linkding.svg" alt="linkding" width="20" height="20"> | [linkding](https://linkding.link) | Bookmarks |

### Tools

| | Tool | Role here |
|---|---|---|
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/convertx.png" alt="ConvertX" width="20" height="20"> | [ConvertX](https://github.com/C4illin/ConvertX) | File converter |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/stirling-pdf.svg" alt="Stirling-PDF" width="20" height="20"> | [Stirling-PDF](https://www.stirlingpdf.com) | PDF tools |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/excalidraw.svg" alt="Excalidraw" width="20" height="20"> | [Excalidraw](https://excalidraw.com) | Whiteboard |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/searxng.svg" alt="SearXNG" width="20" height="20"> | [SearXNG](https://docs.searxng.org) | Metasearch engine |
| <img src="https://svgl.app/library/vscode.svg" alt="code-server" width="20" height="20"> | [code-server](https://github.com/coder/code-server) | VS Code in the browser |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/forgejo.svg" alt="Forgejo" width="20" height="20"> | [Forgejo](https://forgejo.org) | Git server |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/filebrowser-quantum.svg" alt="File Browser Quantum" width="20" height="20"> | [File Browser Quantum](https://github.com/gtsteffaniak/filebrowser) | Web file manager |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/syncthing.svg" alt="Syncthing" width="20" height="20"> | [Syncthing](https://syncthing.net) | File sync between devices |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/rustdesk.svg" alt="RustDesk" width="20" height="20"> | [RustDesk](https://rustdesk.com) | Remote desktop ID and relay server |

### Databases

| | Tool | Role here |
|---|---|---|
| <img src="https://svgl.app/library/postgresql.svg" alt="PostgreSQL" width="20" height="20"> | [PostgreSQL](https://www.postgresql.org) | Immich's database (with VectorChord) |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/valkey.svg" alt="Valkey" width="20" height="20"> | [Valkey](https://valkey.io) | Immich's cache and job queue |
| <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/influxdb.svg" alt="InfluxDB" width="20" height="20"> | [InfluxDB](https://www.influxdata.com) | Scrutiny's metrics store |
