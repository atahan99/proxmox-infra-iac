# 8: A memory budget under the host's 32 GB

**Status.** Proposed. The Grafana alert and some limits are in place.

**Decision.** The guests' RAM in `tofu/prod.tfvars` adds up to at most ~28 GB, leaving the host and its page
cache some room. Today it is 38.5 GB (10 LXCs 34.5 GB + HAOS 4 GB), 36.5 GB
once Kasm goes from 8 GB to 6 GB. Inside the Docker hosts, heavy containers get a `mem_limit` (Frigate,
Immich machine learning, Prometheus and Loki have one; Kasm workspaces don't yet), and the core services
(Traefik, Authelia, ntfy, Dockhand) get a negative `oom_score_adj`, so the OOM killer picks an app first.
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
