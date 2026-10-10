# 4: Apps deploy by pull from a `deploy` branch

Dockhand on docker-apps polls the repo every 5 minutes and redeploys a stack when its folder changes on
the `deploy` branch. docker-hw and kasm are managed through Hawser agents (kasm is monitor-only). Only
`make release` moves `deploy`: it checks with `gh` that the latest CI run on `main` is for that exact commit
and passed, then pushes `origin/main` to `deploy`. The `dockhand_config` role sets Dockhand up through its
HTTP API. Compose files stay plain, so `docker compose up -d` works without Dockhand.

The server accepts no inbound connections, so a push deploy would need an inbound path or deploy
credentials in GitHub. docker-hw is privileged, so a compose file that mounts the host is root on the
Proxmox host, whether it comes from a stolen GitHub token or a compromised Renovate. With this setup a
commit that failed CI never reaches the hosts.

Updates come from the hosted Mend Renovate app, installed on this repo only and configured in
`.github/renovate.json5`: pinned digests and action SHAs, a 3-day minimum release age, auto-merge only for
CI-only updates, majors behind Dependency Dashboard approval, database majors off, Immich images grouped.
It needs nothing hosted and no credentials in the repo, and it only opens PRs on `main`.

A deploy takes two steps, merge and release. `deploy` must exist before Dockhand's first sync, so
`make release` runs once before the first `make apps`. Reverting a stack is a revert commit on `main`
followed by `make release`. The host and guests stay a manual `make`. Branch protection on `deploy` would
close the remaining gap, a direct push with a stolen token.
