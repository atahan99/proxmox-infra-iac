# Documentation

| Document | What it covers |
|---|---|
| [architecture.md](architecture.md) | Guests, layers and tools, repo layout, site values, request/log/notification flows, how changes get deployed |
| [security.md](security.md) | Access model, privilege model, secrets, every credential with its scope and rotation, accepted trade-offs |
| [host-baseline.md](host-baseline.md) | What the `pve_host` role does to the Proxmox host, and why |
| [services.md](services.md) | Stacks per Docker host and their conventions |
| [home-assistant-as-code.md](home-assistant-as-code.md) | How the Home Assistant VM is split into code, secrets, UI state and backups |
| [adr/](adr/) | Decision records: why the repo is built this way |
| [runbooks/workstation.md](runbooks/workstation.md) | Setting up the Mac that runs everything |
| [runbooks/lab-testing.md](runbooks/lab-testing.md) | Testing changes: check-mode dry runs against the host and the throwaway CT 990 |
| [runbooks/release.md](runbooks/release.md) | Shipping a change: which `make` target, checks before and after, when and how to roll back |
| [runbooks/credentials.md](runbooks/credentials.md) | Every vault item and field, creating and rotating tokens and keys |
| [runbooks/install.md](runbooks/install.md) | Fresh install from this repo: which steps are `make` and which are manual, first logins, verifying, restoring from PBS |

Diagrams are Mermaid, which GitHub renders inline.
