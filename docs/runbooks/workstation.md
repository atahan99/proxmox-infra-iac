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

The RPi3 (`$RPI3_USER@$RPI3_IP`) and Home Assistant (the Terminal & SSH add-on's `authorized_keys` option)
are not managed: add the key there by hand.

### A second computer (Windows)

Only the Mac's key is in the repo. Another computer's key is added by hand, and a rebuilt guest comes
back without it (repeat steps 2 and 3).

1. Make the key in PowerShell. No passphrase, like the Mac's, so keep it to your own account:

   ```powershell
   ssh-keygen -t ed25519 -C "windows-homelab" -N '""' -f $env:USERPROFILE\.ssh\id_ed25519
   ```

2. The host takes keys only, so open password login for a moment, from the Mac:

   ```bash
   ssh root@$PVE_IP 'printf "PasswordAuthentication yes\nPermitRootLogin yes\n" > /etc/ssh/sshd_config.d/05-temp-password.conf && sshd -t && systemctl reload ssh'
   ```

   Then on Windows (`ssh-keygen -R` forgets a host key from before a rebuild):

   ```powershell
   ssh-keygen -R <PVE_IP>
   Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@<PVE_IP> "cat >> /root/.ssh/authorized_keys"
   ```

   And close it again, from the Mac:

   ```bash
   ssh root@$PVE_IP 'rm /etc/ssh/sshd_config.d/05-temp-password.conf && systemctl reload ssh && sshd -T | grep -i ^passwordauth'
   ```

   Expect `passwordauthentication no`.

3. Copy the key into every LXC (their root has no password, so this goes through `pct exec`), from the Mac:

   ```bash
   ssh root@$PVE_IP 'K=$(grep windows-homelab /root/.ssh/authorized_keys); for c in $(pct list | awk "NR>1{print \$1}"); do pct exec $c -- sh -c "grep -qxF \"$K\" /root/.ssh/authorized_keys || echo \"$K\" >> /root/.ssh/authorized_keys"; done'
   ```

4. RPi3 and Home Assistant: as above, by hand. On Windows, `ssh-keygen -R <ip>` for each guest the first
   time after a rebuild.

### XPipe

On each computer, add one identity (the person+ button next to "User identity"): user `root`, password
none, key-based authentication = key file `~/.ssh/id_ed25519` (`C:\Users\<you>\.ssh\id_ed25519` on
Windows). Make it local to that computer: the key path differs per machine. Pick it in every connection
and set the connection's own password and key fields to none. The RPi3 gets a second identity, user
`$RPI3_USER`, same key, with its password kept for sudo.

After a rebuild, delete XPipe entries left over from the old guests and refresh "Proxmox systems": a
stale entry holding an old VMID hides the new guest with that ID.

## First run

```bash
make init ENV=lab    # tofu init + lab workspace
make init ENV=prod   # prod workspace
make lint            # the same checks as CI
```
