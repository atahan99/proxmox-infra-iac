# 2: Secrets in a password manager, site values in `homelab.env`

Every secret is an item in one password manager vault, `Homelab`. Git holds references, never values. A
CLI resolves them at deploy time with an access token that is read-only, limited to that vault and
expires. The implementation is Proton Pass: its [access tokens](https://proton.me/blog/pass-access-tokens)
give the token, references look like `pass://Homelab/<item>/<field>`, and `pass-cli inject`/`run`
resolve them. Another password manager with vault-scoped CLI tokens would work the same way; only the
reference format and the CLI calls would change.

Site values (domain, LAN CIDR, gateway, DNS VIP, timezone, coordinates, addresses of devices outside the
repo) are not secret, but the repo is public. They live as plain text in a gitignored `homelab.env`, next
to the secret references. `homelab.env.example` documents every variable, and a copy of the real file is
kept in the vault as the Note `homelab-env`.

The Makefile runs tofu, Ansible, `ha-deploy` and `pin-kernel` under `pass-cli run --env-file homelab.env`.
Ansible reads the variables once, in `group_vars/all.yml` and `host_vars/pve.yml`, and gives every Docker
stack the same `homelab_stack_env`, as its `.env` (core stacks) or as Dockhand env vars (git stacks). Guest
IPs are host numbers in `HOMELAB_LAN_CIDR`; MACs and VMIDs stay in `tofu/*.tfvars` and the inventory, since
they grant no access. `make leak-check`, part of `make lint`, fails on any `192.168.x.x` in a tracked file
and on any plain `homelab.env` value of 6+ characters. gitleaks scans the full history.

The repo holds no secrets and no site addresses, and each secret rotates in one place. A rebuild needs the
password manager reachable, so it has break-glass access from other devices. Proton Pass's AI-agent token
mode asks for a reason on every read and would break unattended runs, so it is off. A command run outside
`make` needs these variables set by hand, and CI has no `homelab.env`, so only a local `make lint` checks
the plain values.
