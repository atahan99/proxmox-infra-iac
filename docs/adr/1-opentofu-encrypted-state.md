# 1: OpenTofu, with encrypted state in the repo

OpenTofu creates the guests through `bpg/proxmox`. Its state is committed to the repo, encrypted with
`pbkdf2` + `aes_gcm`, one workspace per environment. `enforced = true` makes OpenTofu refuse to write
plaintext state or plans, and `make lint` (also run in CI) fails on any `*.tfstate` without
`encrypted_data`. Saved plan files are gitignored.

OpenTofu encrypts state natively; Terraform would need sops, git-crypt or an encrypted remote backend. The
provider, HCL and workflow are the same in both, so moving back is a binary swap. Committing the state
avoids the other two options: a local state file makes the Mac a single point of failure, and an S3-style
backend is extra infrastructure for one operator.

The encrypted state is public with the repo. The passphrase is the vault item `opentofu`; to rotate it,
add a `fallback` block with the old key for one apply. If the state is lost, the guests have fixed IDs and
can be imported again.
