# 7: No off-site backup yet

**Status.** Accepted, until [ADR 9](9-offsite-recovery-bundle.md) is in place and supersedes it.

**Decision.** There is no off-site copy. PBS, the host config backups and the app data share one USB disk.

**Why.** Configuration is rebuilt from the repo, the Immich originals also live in a cloud copy, and
other media can be downloaded again. Nothing on the disk is critical. What only that disk holds is
Immich's database (albums, faces) and the app data.

**Cost.** Losing the disk, or the house, loses that data. The planned fix is [ADR 9](9-offsite-recovery-bundle.md).
