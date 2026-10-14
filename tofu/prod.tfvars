# ENV=prod: the real server. `make apply/destroy ENV=prod` need CONFIRM=yes.
# IDs, MACs and host numbers match the OpenWrt reservations.

# Startup: DNS first, then backups/storage, Docker, the rest.
lxcs = {
  adguard-primary = {
    vmid        = 106
    cores       = 2
    memory      = 1024
    disk        = 12 # query log (14 days) ~4.6 GB
    mac         = "BC:24:11:23:89:8C"
    host        = 4
    dns_gateway = true # not itself: AdGuard resolves via the router
    startup     = 1
    protection  = true
    tags        = ["dns"]
  }
  pbs = {
    vmid       = 108
    cores      = 2
    memory     = 2048
    disk       = 16 # 6.5 GB used; the datastore is on the USB disk
    mac        = "BC:24:11:45:9A:94"
    host       = 132
    startup    = 2
    protection = true
    tags       = ["backup"]
  }
  nas = {
    vmid    = 100
    cores   = 2
    memory  = 1024
    swap    = 1024
    disk    = 8
    mac     = "BC:24:11:0A:4F:C8"
    host    = 180
    startup = 3
    tags    = ["storage"]
  }
  tailscale = {
    vmid    = 105
    cores   = 2
    memory  = 512
    disk    = 8
    mac     = "BC:24:11:C1:7E:51"
    host    = 121
    startup = 3
    tags    = ["network"]
  }
  docker-apps = {
    vmid    = 109
    cores   = 4
    memory  = 8192 # ~4.5 GB of apps + monitoring (Prometheus, Grafana, Loki)
    disk    = 80
    mac     = "BC:24:11:7E:29:D5"
    host    = 122
    startup = 4
    tags    = ["docker"]
  }
  docker-hw = {
    vmid         = 104
    cores        = 4
    memory       = 6144 # Frigate ~1.7 GB + Immich ~2 GB
    disk         = 50   # images; recordings and photos live on the USB disk
    mac          = "BC:24:11:A9:9C:57"
    host         = 120
    unprivileged = false # Coral whole-bus + webcam replug
    startup      = 5
    tags         = ["docker"]
  }
  plex = {
    vmid      = 101
    os        = "ubuntu"
    cores     = 2
    cpu_limit = 1 # Butler scans (loudness, credits) pin a core; GPU does real transcodes
    memory    = 2048
    disk      = 8
    mac       = "BC:24:11:3F:15:76"
    host      = 113
    startup   = 6
    tags      = ["media"]
  }
  kasm = {
    vmid    = 103
    cores   = 4
    memory  = 8192
    disk    = 120 # ~57 GB used
    mac     = "BC:24:11:78:BA:02"
    host    = 117
    startup = 7
    tags    = ["apps"]
  }
  security = {
    vmid    = 110
    cores   = 2
    memory  = 2048 # a scan peaks at ~1.5 GB (signature database); idle ~50 MB
    disk    = 8
    mac     = "BC:24:11:96:8A:94" # reserved on OpenWrt as "security"
    host    = 133
    startup = 7
    tags    = ["security"]
  }
}

vms = {
  haos = {
    vmid       = 102
    cores      = 2
    memory     = 4096
    disk       = 32
    mac        = "02:DB:79:95:60:BD"
    image      = "haos_ova-18.3.qcow2"
    startup    = 5
    protection = true
    tags       = ["homeassistant"]
  }
}
