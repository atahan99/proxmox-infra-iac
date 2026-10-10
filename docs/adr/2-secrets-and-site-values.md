# 2: Secrets in a password manager, site values in `homelab.env`

**Decision.** Every secret is an item in one Proton Pass vault, `Homelab`. Git holds only references
(`pass://Homelab/<item>/<field>`), which `pass-cli run` and `pass-cli inject` resolve at deploy time with
an access token that is read-only, limited to that vault, and expires. Site values (domain, LAN, gateway,
coordinates, device addresses) aren't secret, but the repo is public, so they live in the gitignored
`homelab.env` next to the references. `homelab.env.example` documents every variable, and a copy of the
real file is the vault Note `homelab-env`.

**Why.** No secret or site address in the repo, and each secret rotates in one place. Any password manager
with vault-scoped CLI tokens would do; only the reference format and CLI calls would change.

**Cost.**

- A rebuild needs the vault reachable, hence break-glass access from other devices.
- Proton Pass's AI-agent token mode asks for a reason on every read, which breaks unattended runs, so
  it's off.
- A command run outside `make` needs the variables set by hand.
- CI has no `homelab.env`, so only a local `make lint` checks for leaked site values. CI still catches any
  `192.168.x.x`, and gitleaks scans the full history.

How the values reach each tool: [architecture.md](../architecture.md#config-and-secrets).
