# Release

Checklists for shipping a change to the real server. Pick the row that matches what changed; a change
that touches several rows runs each of them, top to bottom.

| What changed | Ships with | Who restarts what |
|---|---|---|
| A git stack in `stacks/` (anything in `docker_apps_stacks`, or agents, frigate, immich) | Merge, `make release` | Dockhand, within 5 minutes |
| A core stack (traefik, authelia, dockhand, socket-proxy, hawser) or a stack secret (`*.tpl`) | Merge, `make release`, `make apps ENV=prod` | Ansible |
| A guest role (`ansible/roles/*`, inventory) | `make config ENV=prod` | Ansible |
| The host (`pve_host`) | `make host ENV=prod` | Ansible; some changes need a reboot |
| Guests in OpenTofu (`tofu/`) | `make guests ENV=prod CONFIRM=yes` | OpenTofu, then `lxc_devices` |
| Home Assistant YAML | `make ha-deploy` | HA restarts |

## Before

- [ ] CI is green on the commit (`make release` refuses otherwise; for the others, check GitHub Actions).
- [ ] Renovate PRs: read the release notes of anything that isn't a patch or digest bump.
- [ ] A secret the change needs is in the vault (`make apps` stops on a missing item or field).
- [ ] Ansible changes: the dry run shows only what you expect (`make host-check`, `make devices-check
      ENV=prod`, `make config-check ENV=prod`).
- [ ] OpenTofu changes: `make plan ENV=prod` shows no replace (`-/+`) of a guest you didn't mean to
      recreate. A replace deletes the guest's disk; the protected guests (adguard-primary, pbs, HAOS)
      refuse it.
- [ ] Risky changes (host, a guest's disk, a database major): a fresh PBS backup of the guests involved.
- [ ] Anything new to try first: `make guests ENV=lab` and the stack on CT 990
      ([lab-testing.md](lab-testing.md)).

## After

- [ ] The stack's containers are running and healthy in Dockhand (or `docker compose ps` on the host).
- [ ] Its `https://<name>.<domain>` loads through Authelia, and its Homepage widget is green.
- [ ] No new errors for the stack in Grafana (Loki) over the next 15 minutes; no ntfy alert.
- [ ] Host or guest changes: `make host-check` / `make config-check ENV=prod` / `make plan ENV=prod` now
      show no changes.

## Roll back when

- A container restarts in a loop or stays unhealthy.
- A login (Authelia, an app's own) or a route that worked before fails.
- A Homepage widget or a Grafana panel loses its data after the change.

How:

- Git stack: revert the commit on `main`, wait for CI, `make release`. A database migration that already
  ran isn't undone by an older image; restore the stack's data from its guest's PBS backup.
- Core stack, role or host: revert, then re-run the same `make` target.
- Guest replaced by mistake: restore it from PBS ([install.md](install.md#restore-every-guest-from-pbs)).
- New kernel breaks passthrough: `make pin-kernel VERSION=<previous>`, reboot.
