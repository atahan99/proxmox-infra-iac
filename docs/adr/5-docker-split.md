# 5: Two Docker hosts: privileged docker-hw, unprivileged docker-apps

docker-hw (CT 104, privileged) runs only Frigate and Immich. docker-apps (CT 109, unprivileged, uid/gid
1000-1001 mapped) runs everything else, including Traefik, Authelia and Dockhand.

Frigate needs the Coral TPU, which comes back with a new device id after its firmware loads, and a webcam
that survives replugging. Immich uses the iGPU. Nothing else needs hardware.

docker-hw is an accepted risk: root there is effectively root on the host, and passing the whole USB bus
for the Coral also exposes the backup disk on the same controller. Nothing on docker-hw is reachable from
the internet. A later option is an unprivileged docker-hw with per-device passthrough.
