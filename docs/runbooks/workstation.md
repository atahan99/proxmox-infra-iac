# Workstation (Mac)

Everything runs from one Mac: OpenTofu, Ansible, the password manager CLI (`pass-cli`) and the linters.

## Tools

```bash
brew install opentofu ansible ansible-lint yamllint gitleaks trivy gh jq protonpass/tap/pass-cli
ansible-galaxy collection install -r ansible/requirements.yml
gh auth login   # make release reads the CI result with gh
```

CI installs the linters from `requirements-ci.txt` (pinned versions); `pip install -r requirements-ci.txt`
gives the Mac the same ones.

## Vault access token

The vault is read through a Proton Pass
[access token](https://proton.me/blog/pass-access-tokens) ([ADR 2](../adr/2-secrets-and-site-values.md)).

1. In Proton Pass: Settings → access tokens → new token, read-only, vault `Homelab` only, 1-year expiry.
   Leave "use for AI agent" off (it would require a reason for every read and break unattended runs).
2. Store it in the macOS Keychain. The command prompts for the value, so it never reaches shell history:

   ```bash
   security add-generic-password -a "$USER" -s proton-pass-pat -w
   ```

3. Check: `make login && pass-cli info && pass-cli vault list` shows the token name and only `Homelab`.

Sessions last 2 hours; every `make` target that needs secrets logs in again from the Keychain.

## Site values

Copy `homelab.env.example` to `homelab.env` (gitignored) and fill in your values; the example names every
variable. Secrets stay `pass://` references. Keep a copy in the vault as the Note `homelab-env`, and
restore the file from it on a new Mac. Every `make` target that runs tofu, Ansible or the HA scripts reads
it with `pass-cli run --env-file homelab.env`. Without it, OpenTofu stops on a missing variable and Ansible
stops with "... is not set: run through make".

## SSH key

```bash
ssh-keygen -t ed25519 -C "mac-homelab" -N "" -f ~/.ssh/id_ed25519
```

The public key goes into `ansible/inventory/group_vars/all.yml` (`ssh_authorized_keys`) and
`tofu/variables.tf` (`ssh_public_keys`). After a fresh Proxmox install, copy it to the host once
(`ssh-copy-id root@$PVE_IP`); from then on `pve_host` manages it, and password login over SSH is
turned off.

## First run

```bash
make init ENV=lab    # tofu init + lab workspace
make init ENV=prod   # prod workspace
make lint            # the same checks as CI
```
