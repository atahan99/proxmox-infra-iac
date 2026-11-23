# 10: Keep the NVMe until it degrades, then replace it

**Status.** Proposed.

**Decision.** The Samsung 980 1 TB stays in service, watched by Scrutiny. It gets replaced when Media and
Data Integrity Errors rises above 3, Critical Warning is set, or Available Spare drops. PBS keeps a
backup of every guest on the USB disk, so losing the NVMe is a reinstall plus a restore
([install.md](../runbooks/install.md)). Capping the NVMe's power state (APST / `nvme_core.default_ps_max_latency_us`)
is to be tried to cut its heat.

**Why.** It has reported 3 media errors since 2026-10-19, unchanged since, which Scrutiny flags every day.
It runs hot: about 689,000 s in total in thermal throttle state 1, the controller sensor up to 97 °C, and
the NucBox has no room for a heatsink. A stable error count isn't failing yet, and replacing it now buys
little that the backups don't already cover.

**Cost.** No redundancy until then: the host has one disk, so a sudden failure means downtime and up to
the PBS recovery point of data on the NVMe. A lower power state may cost some disk speed. The daily
Scrutiny alert stays noise until the threshold is moved.
