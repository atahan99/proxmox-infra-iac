# 3: Ansible does what the OpenTofu token may not

OpenTofu runs with a least-privilege API token, and Proxmox keeps some settings away from any token:

- Bind mounts, `devN` passthrough, raw `lxc.*` lines and feature flags other than `nesting` are
  `root@pam` only (tokens get HTTP 403). The `lxc_devices` role writes them into
  `/etc/pve/lxc/<id>.conf` over SSH as root and restarts the containers whose config changed. OpenTofu
  ignores those attributes (`features`, `mount_point`, `device_passthrough`, `idmap`).
- `download_file` needs `Sys.Modify` on `/`, which would also let the token change node settings, and it
  can't unpack the HAOS `.qcow2.xz`. `pve_host` downloads the LXC templates with `pveam` (SHA-512 checked
  against Proxmox's signed index) and the HAOS image (SHA-256 pinned), and unpacks it into
  `local:import/`. OpenTofu only references the files.

The apply token has no `Sys.Modify` and no `Datastore.AllocateTemplate`. A guest is complete only after
`make guests`, which runs OpenTofu and then Ansible; after that, `tofu plan` shows no changes and a second
Ansible run changes nothing. Templates survive `tofu destroy`. Image versions are pinned in the Ansible
defaults and must match the tfvars.
