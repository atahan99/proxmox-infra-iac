# Proxmox host baseline (`pve_host` role)

Everything the host needs beyond a stock Proxmox install, as idempotent Ansible tasks. The
[community-scripts.org](https://community-scripts.org) post-install and host-management scripts are the
reference; their behaviour is re-implemented here and nothing from them is executed.

Run `make host-check` to see what the role would change (read-only), `make host` to apply it. The host's
address, NIC, MAC and USB disk UUID come from `homelab.env`
([ADR 2](adr/2-secrets-and-site-values.md)).

## What it configures

| Area | Setting | Why |
|---|---|---|
| Network | `vmbr0` static at `PVE_IP` with the NIC's MAC, the NIC (`PVE_NIC`) manual | The bridge port must not run DHCP; `/etc/hosts` must match a fixed IP |
| Apt | deb822 `debian.sources` with `non-free-firmware`, PVE no-subscription on, enterprise off, legacy `.list`/Ceph/pvetest files removed | Clean `apt update`, firmware available |
| Microcode | `intel-microcode` | Otherwise the N150 runs BIOS microcode only; needs one reboot |
| Updates | `unattended-upgrades` for Debian security only, no automatic reboot (the `common` role's baseline tasks, shared with every LXC) | Debian and Proxmox packages are upgraded together by hand, never automatically. An apt `#clear` override removes Debian's default "stable point releases" origin |
| Subscription pop-up | Patched once, plus an apt hook that re-patches after `proxmox-widget-toolkit` updates | |
| Single node | `pve-ha-lrm`, `pve-ha-crm`, `corosync` disabled | No cluster |
| Memory | `vm.swappiness = 10` | Avoids swapping while RAM is free |
| SSH | The operator key in root's `authorized_keys`; `sshd_config.d/10-homelab.conf` with `PermitRootLogin prohibit-password`, no password or keyboard-interactive login (same baseline as every LXC) | Root by key only; the root password stays for the web UI and console |
| Boot | Kernel command line: `intel_iommu=on iommu=pt`, USB quirks (no link power management for the Coral before and after its firmware load, no UAS for the Seagate disk), USB autosuspend off; `i915` loaded at boot | Stable Coral and USB disk, iGPU for Plex/Frigate/Immich |
| USB disk | `/mnt/external` in fstab by UUID, with `nofail`; mounted during the run too, and the play fails if the disk is missing | A missing disk must not block boot, but folders made later must land on the disk, not on the NVMe |
| Webcam | udev rule + `lxc-video-sync`: on every webcam add/remove, the video device nodes are re-created inside docker-hw | LXC only binds devices at container start; after a replug Frigate would see empty files |
| Templates | Debian 13 and Ubuntu 26.04 LXC templates via `pveam` (SHA-512 checked against Proxmox's signed index) | Done here, not by OpenTofu, so the API token needs no `Sys.Modify` |
| HAOS image | HAOS 18.3 `.qcow2.xz` downloaded, SHA-256 checked, unpacked into `local:import/`; `import` content enabled on storage `local` | OpenTofu imports it as VM 102's disk |
| OpenTofu user | `tofu@pve`, role `TofuApply`, ACLs for the user and both tokens | Idempotent; the tokens themselves are created by hand because their secrets must go to the vault |
| Monitoring | `monitoring@pve` read-only user, Scrutiny collector timer, Alloy (journal to Loki) | The exporter and Homepage tokens are made by hand, like OpenTofu's |

The PBS storage entry and the vzdump job (every 3 days) need PBS running, so the `pbs` role adds them.

## Weekly timers

| Timer | When | What |
|---|---|---|
| `homelab-lxc-fstrim` | Sun 04:00 | `pct fstrim` on every running LXC: LXC volumes on LVM-thin are otherwise never trimmed |
| `homelab-pbs-config-export` | Sun 06:15 | Streams CT 108's `/etc/proxmox-backup` to the NVMe (`/var/lib/vz/pbs-config`, 90 days). CT 108 is excluded from vzdump, so this is the only copy of its config. The archive must contain `datastore.cfg` or it isn't kept |
| `homelab-host-backup` | Sun 07:00 | `/etc` plus a consistent SQLite `.backup` of the Proxmox config database to `/mnt/external/Proxmox/host-config/` (12 kept, root-only: it contains `/etc/pve/priv`), then a second copy of the PBS export to the USB disk |

The PBS config is kept in two places: the NVMe copy survives a USB-disk failure and the USB copy survives
an NVMe failure.

## USB disk layout

```plain text
/mnt/external
├── Backups/        # PBS datastore. Mounted only into pbs; vetoed on the nas share
├── Proxmox/
│   ├── host-config/  # weekly host-config-YYYY-MM-DD.tar.gz
│   └── pbs-config/   # copy of the weekly PBS config export
└── ...             # media, photos (Immich), documents, downloads
```

Which guest sees which folder is in [security.md](security.md#privilege-model).

## Not taken from community-scripts

- Intel e1000e NIC fix: the NIC is an I226-V (`igc` driver).
- IP tags, startup dependency checks: tags and boot order are set by OpenTofu.
- Disk health tool: Scrutiny covers it. Netdata add-on: not used.
- Privilege converter: every guest except docker-hw is created unprivileged.
