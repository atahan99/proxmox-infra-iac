# 4: Apps deploy by pull from a `deploy` branch

**Decision.** Dockhand on docker-apps polls the repo every 5 minutes and redeploys a stack when its folder
changes on the `deploy` branch, on docker-apps directly and on docker-hw through Hawser. When CI passes on
a push to `main`, the `release` workflow fast-forwards `deploy` to that exact commit. `make release` does
the same by hand: it checks with `gh` that the latest CI run on `main` passed for that commit, then pushes
`origin/main` to `deploy`. Compose files stay plain, so `docker compose up -d` works without Dockhand.

**Why.** The server accepts no inbound connections, so a push deploy would need an inbound path or
deploy credentials for the server in GitHub. Here GitHub only moves a branch, and nothing that failed CI
gets onto the hosts.

Renovate (hosted Mend app, this repo only) opens the update PRs: pinned digests and action SHAs, a
3-day minimum release age, majors behind Dependency Dashboard approval, database majors off, Immich images
grouped. Auto-merge when CI is green: GitHub Actions minor and patch, Docker image patch versions and the
weekly digest group. Image minors, majors and providers stay manual.

**Cost.** An auto-merged Renovate PR ships with no human step, docker-hw included (privileged LXC: a
compose file that mounts the host is root on Proxmox). The 3-day release age and CI are the only buffers;
`gh workflow disable release` pauses shipping, `make release` still works. Changes that need
`make apps ENV=prod` first (a new external network, a `*.tpl` secret) must get it before the merge.

A GitHub ruleset lets only repo admins and deploy keys update `deploy` and blocks force pushes and
deletion (on `main` too), so Renovate can't move it directly. The workflow's write deploy key is a secret of
the `release` environment, which only jobs on `main` can use: a workflow edited on a PR branch can't read
it. So moving `deploy` takes a commit on `main` that passed CI, or a stolen token of the admin account,
which bypasses the ruleset. `deploy` must exist before Dockhand's first sync, so `make release` runs once
before the first `make apps`.
