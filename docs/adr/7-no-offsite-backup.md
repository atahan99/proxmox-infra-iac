# 7: No off-site backup yet

There is no off-site copy. PBS, the host config backups and the app data share one USB disk, so losing that
disk (or the house) loses Immich albums and faces and the app data. Configuration is rebuilt from the repo,
and media has separate backups.

When it is added, it will be an off-site copy of the backups on that disk. A design exists: an encrypted
recovery bundle (database dumps, HA backup, host and PBS config, keys) uploaded with rclone to Proton
Drive.
