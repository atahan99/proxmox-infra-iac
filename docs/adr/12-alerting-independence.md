# 12: Alerts and access that survive the host

**Status.** Partly accepted (the hang recovery, 2026-11-24), the rest proposed.

**Decision.** Accepted, in `ansible/roles/pve_host`: a hang reboots the host and leaves evidence. The
chipset watchdog (`iTCO_wdt`) is pinged by systemd (`RuntimeWatchdogSec=30s`); `kernel.panic=10`,
`softlockup_panic` and `hung_task_panic` (after 300 s) turn a stall into a panic and a reboot; the panic
text is kept in EFI pstore. Gatus on the RPi3 already watches the server from outside and alerts through
ntfy.sh.

Proposed: the host sends a heartbeat to an external dead-man's switch, which alerts when it stops, and the
RPi3 becomes a second Tailscale subnet router, so PiKVM stays reachable when the host is down.

**Why.** Grafana, ntfy and the Tailscale LXC run on the host and die with it: a stalled host can't report
itself, and remote access to PiKVM goes through the host's own subnet router. The daily stalls since
2026-10-21 needed a hands-on reset.

**Cost.** A watchdog reboot can hide a problem that a stalled host would have shown, hence pstore and the
logs in Loki. The heartbeat needs an external account; the second subnet router is one more device with
access to the LAN and must have its routes approved in the Tailscale admin.
