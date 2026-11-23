# 9: A nightly encrypted recovery bundle off-site

**Status.** Proposed. Supersedes [ADR 7](7-no-offsite-backup.md) once in place.

**Decision.** Every night the host builds one encrypted bundle and uploads it with rclone to Proton Drive or
Backblaze B2: the Immich `pg_dump`, the latest HA backup, the PBS and host config export, the Forgejo
repositories, the other apps' database dumps, and the keys a rebuild needs. Recovery point for that set:
1 day. The decryption key is kept outside the Proton Pass vault, for example on paper, because the vault
is one of the things a disaster can take with it.

**Why.** [ADR 7](7-no-offsite-backup.md) leaves Immich's database (albums, faces) and the app data on one
USB disk in the same house. Configuration and media can be rebuilt or downloaded again; that small set
can't. The guests' PBS backups stay local: too big to upload every night, and rebuildable from the repo.

**Cost.** An external account, a storage bill (B2) or a share of the Proton plan, and an offline key to
guard: lost, the bundle is useless; found, it opens everything in it. The upload job and its alerting are
one more thing to maintain, and a restore must be tested now and then to count.
