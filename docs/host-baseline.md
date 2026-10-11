# Proxmox host baseline

The `pve_host` role: everything the host needs beyond a stock Proxmox install. The
[community-scripts.org](https://community-scripts.org) post-install scripts were the reference; their
behaviour is re-implemented as Ansible tasks and none of their code runs.

`make host-check` shows what would change, `make host` applies it. The host's address, NIC, MAC and USB
disk UUID come from `homelab.env`.

| Area | Setting | Why |
|---|---|---|
| Network | `vmbr0` static at `PVE_IP` with the NIC's MAC; the NIC itself manual | The bridge port must not run DHCP |
| Apt | deb822 sources with `non-free-firmware`, no-subscription repo on, enterprise off, legacy and Ceph files removed | Clean `apt update`, firmware available |
| Microcode | `intel-microcode` | Otherwise the N150 runs the BIOS microcode; needs one reboot |
| Updates | unattended-upgrades for Debian security only, no reboot (shared `common` baseline) | Proxmox and Debian packages are upgraded together, by hand |
| Subscription pop-up | Patched, and re-patched by an apt hook after `proxmox-widget-toolkit` updates | |
| Single node | `pve-ha-lrm`, `pve-ha-crm`, `corosync` off | No cluster |
| Memory | `vm.swappiness = 10` | No swapping while RAM is free |
| SSH | The Mac's key for root; `PermitRootLogin prohibit-password`, no password login | The root password stays for the web UI and console |
| Boot | `intel_iommu=on iommu=pt`; no USB link power management for the Coral, no UAS for the Seagate disk, USB autosuspend off; `i915` at boot | Stable Coral and USB disk; iGPU for Plex, Frigate, Immich |
| USB disk | `/mnt/external` in fstab by UUID with `nofail`; the run fails if the disk is missing | A missing disk mustn't block boot, and folders must land on the disk, not the NVMe |
| Webcam | udev rule + `lxc-video-sync` re-create the video devices in docker-hw on every replug | LXC binds devices only at start, so Frigate would see dead nodes |
| Templates | Debian 13 and Ubuntu 26.04 via `pveam`, checked against Proxmox's signed index | So the OpenTofu token needs no `Sys.Modify` ([ADR 3](adr/3-root-only-steps-in-ansible.md)) |
| HAOS image | HAOS 18.3 downloaded, SHA-256 checked, unpacked into `local:import/` | OpenTofu imports it as VM 102's disk |
| OpenTofu user | `tofu@pve`, role `TofuApply`, ACLs | The tokens are made by hand, since their secret must go to the vault |
| Monitoring | `monitoring@pve` (read-only), Scrutiny collector, Alloy (journal to Loki), Beszel agent (same as the LXCs) | |
| Alerts | `ntfy` webhook target and a matcher for warnings and errors (failed backups); `homelab-backup-age` and `homelab-pending-updates` timers; any failed timer job (these included) sends its last log lines | Backups and manual upgrades must not fail or wait silently. The PBS role adds the same webhook in PBS |

The pbs role adds the PBS storage and the backup job, since they need PBS running.

## Timers

| Timer | When | What |
|---|---|---|
| `homelab-lxc-fstrim` | Sun 04:00 | `pct fstrim` on every running LXC. LVM-thin volumes are otherwise never trimmed |
| `homelab-pbs-config-export` | Sun 06:15 | CT 108's `/etc/proxmox-backup` to `/var/lib/vz/pbs-config` (90 days). CT 108 isn't in vzdump, so this is its only config backup. Kept only if it contains `datastore.cfg` |
| `homelab-host-backup` | Sun 07:00 | `/etc` and a SQLite `.backup` of the Proxmox config DB to `/mnt/external/Proxmox/host-config/` (12 kept, root-only: it includes `/etc/pve/priv`), then a copy of the PBS export |
| `homelab-backup-age` | Daily 09:00 | ntfy alert for any guest in an enabled backup job whose newest backup is over 4 days old (or no job at all). Guests tagged `lab` are skipped |
| `homelab-pending-updates` | Mon 09:00 | One ntfy message listing the pending upgrades on the host and every running LXC |

The PBS config ends up on both disks, so either one can fail. All other jobs are in
[architecture.md](architecture.md#schedules).

## USB disk

```plain text
/mnt/external
├── Backups/          # PBS datastore; only pbs sees it
├── Proxmox/
│   ├── host-config/  # weekly host-config-YYYY-MM-DD.tar.gz
│   └── pbs-config/   # copy of the weekly PBS config export
└── ...               # media, photos (Immich), documents, downloads
```

Which guest sees which folder: [security.md](security.md#privileges).

## Left out from community-scripts

- e1000e NIC fix: this NIC is an I226-V (`igc`).
- IP tags and startup checks: OpenTofu sets tags and boot order.
- Disk health tool: Scrutiny covers it.
- Privilege converter: every guest except docker-hw is created unprivileged.
