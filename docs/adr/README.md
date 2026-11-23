# Decision records

Each record states its status, the decision, why, and what it costs. A decision that replaces an earlier one gets a
new record.

| # | Decision |
|---|---|
| [1](1-opentofu-encrypted-state.md) | OpenTofu, with encrypted state in the repo |
| [2](2-secrets-and-site-values.md) | Secrets in a password manager, site values in `homelab.env` |
| [3](3-root-only-steps-in-ansible.md) | Ansible does what the OpenTofu token may not |
| [4](4-pull-based-deploys.md) | Apps deploy by pull from a `deploy` branch |
| [5](5-docker-split.md) | Two Docker hosts: privileged docker-hw, unprivileged docker-apps |
| [6](6-private-access-and-sso.md) | LAN and Tailscale only, behind Authelia |
| [7](7-no-offsite-backup.md) | No off-site backup yet (to be superseded by 9) |
| [8](8-memory-budget.md) | A memory budget under the host's 32 GB (proposed) |
| [9](9-offsite-recovery-bundle.md) | A nightly encrypted recovery bundle off-site (proposed) |
| [10](10-nvme-replacement.md) | Keep the NVMe until it degrades, then replace it (proposed) |
| [11](11-auto-merge-boundary.md) | No auto-merge for privileged and socket-holding services (proposed) |
| [12](12-alerting-independence.md) | Alerts and access that survive the host (partly proposed) |
