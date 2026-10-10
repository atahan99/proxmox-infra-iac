# 7: No off-site backup yet

**Decision.** There is no off-site copy. PBS, the host config backups and the app data share one USB disk.

**Why.** Configuration is rebuilt from the repo, the Immich originals also live in a cloud copy, and
other media can be downloaded again. Nothing on the disk is critical. What only that disk holds is
Immich's database (albums, faces) and the app data.

**Cost.** Losing the disk, or the house, loses that data. The planned fix is an encrypted recovery bundle
(database dumps, HA backup, host and PBS config, keys) uploaded with rclone to Proton Drive.
