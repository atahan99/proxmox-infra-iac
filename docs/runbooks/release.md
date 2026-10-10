# Release

Shipping a change to the real server. Find what changed; a change touching several rows runs each, top
to bottom.

| What changed | Ship with | Applied by |
|---|---|---|
| A git stack in `stacks/` | Merge, `make release` | Dockhand, within 5 minutes |
| A core stack (traefik, authelia, dockhand, socket-proxy, hawser) or any `*.tpl` | Merge, `make release`, `make apps ENV=prod` | Ansible |
| A guest role or the inventory | `make config ENV=prod` | Ansible |
| The host (`pve_host`) | `make host ENV=prod` | Ansible; some changes need a reboot |
| Guests in `tofu/` | `make guests ENV=prod CONFIRM=yes` | OpenTofu, then `lxc_devices` |
| Home Assistant YAML | `make ha-deploy` | HA restarts |

## Before

- [ ] CI is green on the commit (`make release` refuses otherwise).
- [ ] Renovate PRs: read the release notes of anything beyond a patch or digest bump.
- [ ] Any new secret is in the vault (`make apps` stops on a missing item or field).
- [ ] Ansible: the dry run shows only what you expect (`make host-check`, `make devices-check ENV=prod`,
      `make config-check ENV=prod`).
- [ ] OpenTofu: `make plan ENV=prod` shows no unexpected replace (`-/+`). A replace deletes the guest's
      disk; adguard-primary, pbs and HAOS refuse it.
- [ ] Risky changes (host, a guest's disk, a database major): fresh PBS backup of the guests involved.
- [ ] New things: try them on CT 990 first ([lab-testing.md](lab-testing.md)).

## After

- [ ] The stack's containers are running and healthy in Dockhand.
- [ ] `https://<name>.<domain>` loads through Authelia, and its Homepage widget is green.
- [ ] No new errors in Grafana (Loki) for 15 minutes, no ntfy alert.
- [ ] Host or guest changes: the matching `-check` target or `make plan` now shows nothing.

## Roll back

Roll back when a container restart-loops or stays unhealthy, a login or route that worked fails, or a
widget or Grafana panel loses its data.

| What | How |
|---|---|
| Git stack | Revert on `main`, wait for CI, `make release`. An older image doesn't undo a database migration: restore the stack's data from PBS |
| Core stack, role, host | Revert, re-run the same `make` target |
| Guest replaced by mistake | Restore it from PBS ([install.md](install.md#restore-every-guest-from-pbs)) |
| New kernel breaks passthrough | `make pin-kernel VERSION=<previous>`, reboot |
