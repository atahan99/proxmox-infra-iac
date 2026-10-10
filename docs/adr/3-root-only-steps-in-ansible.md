# 3: Ansible does what the OpenTofu token may not

**Decision.** OpenTofu runs with a least-privilege API token. Ansible, as root over SSH, does the parts
Proxmox doesn't allow any token to do:

- Bind mounts, `devN` passthrough, raw `lxc.*` lines and feature flags other than `nesting` are
  `root@pam` only (tokens get HTTP 403). `lxc_devices` writes them into `/etc/pve/lxc/<id>.conf` and
  restarts the containers whose config changed. OpenTofu ignores those attributes.
- Downloads: `download_file` needs `Sys.Modify` on `/`, which would also allow changing node settings,
  and it can't unpack the HAOS `.qcow2.xz`. `pve_host` downloads the templates and the image, checks them,
  and OpenTofu only references the files.

**Why.** The apply token has no `Sys.Modify` and no `Datastore.AllocateTemplate`, so a leaked token can't
reconfigure the node.

**Cost.** A guest is complete only after `make guests`, which runs both tools. Image versions are pinned
in the Ansible defaults and must match the tfvars.
