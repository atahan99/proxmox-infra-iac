# Lab testing

Changes are tested against the server without touching the real guests:

| Test | Command | Touches |
|---|---|---|
| Lint and validate | `make lint` | Nothing (also runs in CI) |
| Host role diff | `make host-check` | Nothing: Ansible check mode against the real host |
| Container config diff | `make devices-check ENV=prod` | Nothing: what `lxc_devices` would change on the running containers |
| Guest config diff | `make config-check ENV=prod` | Nothing: check mode of the guest roles on the running containers, through the host (`pct exec`) |
| Guest plan | `make plan ENV=prod` | Nothing: read-only token; compares with the prod state (empty before the first install, so a full create) |
| Test container | `make guests ENV=lab`, then `make destroy ENV=lab` | Only CT 990 (.90) |

## CT 990

- Defined in `tofu/lab.tfvars`; its root-only config (tun, fuse, keyctl, uid mapping: docker-apps minus the USB disk) is in
  `ansible/inventory/lab.yml`.
- It has its own MAC, an IP outside the DHCP pool, no deletion protection and no autostart.
- Its host key changes on every rebuild. It is trusted on first use into `.lab_known_hosts`, which
  `make apply`/`destroy ENV=lab` resets. Lab-only secrets (the Samba and AdGuard passwords, the ntfy
  sender tokens) are random and kept in gitignored `.lab-secrets/` files; real passwords never go into the
  lab.
- The lab reads the same `homelab.env` as prod. In `homelab_stack_env` every guest IP falls back to
  CT 990's own address, since the lab has none of those guests.
- AdGuard is tested on it without keepalived and sync (it must never take the real DNS VIP or push to the
  RPi3). Its upstreams can't be tested there: the router redirects every LAN device's port-53 traffic to
  AdGuard except AdGuard's own addresses (.4, .3), so plain DNS from .90 goes nowhere. Local answers (the
  wildcard rewrite) and the web login are tested.
- Apps on it use the test domain `lab.<domain>`, reached from the Mac via `/etc/hosts` or
  `curl --resolve`. Dockhand on CT 990 follows the `deploy` branch like prod, so a stack change reaches it
  only after CI passes and `make release`.

`make apply` / `make destroy` ask for confirmation; `ENV=prod` also needs `CONFIRM=yes`.
