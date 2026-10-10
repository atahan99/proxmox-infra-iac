# 1: OpenTofu, with encrypted state in the repo

**Decision.** OpenTofu creates the guests through `bpg/proxmox`. Its state is committed, encrypted with
`pbkdf2` + `aes_gcm`, one workspace per environment. `enforced = true` makes OpenTofu refuse to write
plaintext state or plans, and `make lint` fails on any `*.tfstate` without `encrypted_data`.

**Why.** OpenTofu encrypts state natively; Terraform would need sops, git-crypt or an encrypted remote
backend. A local state file would make the Mac a single point of failure, and an S3-style backend is extra
infrastructure for one person. The provider and HCL are the same in both tools, so switching back is a
binary swap.

**Cost.** The encrypted state is public. The passphrase (vault item `opentofu`) can't be changed in place:
add the new key with the old one as a `fallback` block for one apply. If the state is lost, the guests
have fixed IDs and can be imported again.
