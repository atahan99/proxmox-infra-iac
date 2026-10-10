# 4: Apps deploy by pull from a `deploy` branch

**Decision.** Dockhand on docker-apps polls the repo every 5 minutes and redeploys a stack when its folder
changes on the `deploy` branch, on docker-apps directly and on docker-hw through Hawser. Only
`make release` moves `deploy`: it checks with `gh` that the latest CI run on `main` passed for that exact
commit, then pushes `origin/main` to `deploy`. Compose files stay plain, so `docker compose up -d` works
without Dockhand.

**Why.** The server accepts no inbound connections, so a push deploy would need an inbound path or
deploy credentials in GitHub. And docker-hw is privileged: a compose file that mounts the host is root on
Proxmox. With this setup, neither a stolen GitHub session nor a compromised Renovate can get a commit
onto the hosts without me, and nothing that failed CI gets there.

Renovate (hosted Mend app, this repo only) opens the update PRs: pinned digests and action SHAs, a
3-day minimum release age, majors behind Dependency Dashboard approval, database majors off, Immich images
grouped. Auto-merge when CI is green: GitHub Actions minor and patch, Docker image patch versions and the
weekly digest group. That's safe because merging deploys nothing; `make release` still decides what ships.
Image minors, majors and providers stay manual.

**Cost.** Every deploy takes two steps, merge and release. `deploy` must exist before Dockhand's first
sync, so `make release` runs once before the first `make apps`. A GitHub ruleset lets only repo admins
update `deploy` and blocks force pushes and deletion (on `main` too), so Renovate or any other non-admin
can't move it. A stolen token of the admin account still could: it acts as the admin and bypasses the
ruleset.
