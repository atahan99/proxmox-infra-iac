# 8: A memory budget under the host's 32 GB

**Status.** The guard inside docker-apps and Kasm at 6 GB are accepted and in place (2026-11-24); the
~28 GB budget is proposed.

**Decision.** The guests' RAM in `tofu/prod.tfvars` adds up to at most ~28 GB, leaving the host and its page
cache some room. It is 36.5 GB now (10 LXCs 32.5 GB + HAOS 4 GB; Kasm went from 8 GB to 6 GB). Inside
docker-apps:
- Every app service sets `oom_score_adj: 500`, so when the LXC runs out the OOM killer takes an app, never
  Traefik, Authelia, ntfy or Dockhand. A negative value would be simpler but an unprivileged LXC silently
  turns it into 0.
- The core services set `mem_reservation` (cgroup `memory.low`), so their memory isn't reclaimed when the
  LXC is short.
- Apps whose jobs spike set a `mem_limit` (ConvertX, code-server, changedetection, MeTube, Calibre-Web,
  Mealie, File Browser; Stirling-PDF, SearXNG, Prometheus and Loki already had one), so they die alone.
On docker-hw, Frigate and Immich already have limits; Kasm workspaces have none yet.
Grafana alerts when a guest uses over 90% of its memory for 15 minutes (`guest-memory-high` in
`stacks/monitoring/grafana/provisioning/alerting/ntfy.yml`).

**Why.** An LXC's memory is a ceiling, not a reservation, so the overcommit only hurts when several guests
are busy at once. That happened on 2026-11-05: docker-hw thrashed its page cache at its 6 GB limit and the
whole host stalled. A container that dies at its own limit is a smaller failure than a guest, or the host,
going into reclaim.

Splitting docker-apps into a core LXC and an apps LXC was considered and rejected for now: the ~30 apps
routed by Docker labels would need Traefik file routes, the apps that trust Authelia's headers (Forgejo,
FreshRSS, Beszel) rely on a private Docker network shared only with Traefik and would be reachable on the
LAN, all their data would move, and a second Docker host costs more RAM.

**Cost.** About 10 GB of guest RAM has to go, so some guests get less headroom than they have now, and a
limit set too low restarts an app under load. The limits are guesses to be checked against Grafana.
