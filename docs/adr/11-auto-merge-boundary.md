# 11: No auto-merge for privileged and socket-holding services

**Status.** Proposed. Revises the auto-merge part of [ADR 4](4-pull-based-deploys.md).

**Decision.** Renovate keeps auto-merging green PRs, except for the images that can take over a host:
Hawser, Dockhand, socket-proxy, Traefik, Authelia, code-server, and everything on docker-hw (Frigate,
Immich). Their PRs wait for a manual merge.

**Why.** [ADR 4](4-pull-based-deploys.md) counts on the 3-day release age as a buffer, but
`minimumReleaseAgeBehaviour: "timestamp-optional"` in `.github/renovate.json5` lets images with no release
date (ghcr, lscr, the Forgejo registry) through right away; without it their updates would wait forever.
So a compromised image there can ship within minutes of its release. docker-hw (CT 104) is privileged, root
there is root on the host, and the services above hold a Docker socket or every login.

**Cost.** A few manual merges a week, and those images may lag behind their releases until someone looks.
