# 5: Two Docker hosts: privileged docker-hw, unprivileged docker-apps

**Decision.** docker-hw (CT 104, privileged) runs only Frigate and Immich. docker-apps (CT 109,
unprivileged) runs everything else, including Traefik, Authelia and Dockhand.

**Why.** Frigate needs the Coral, which comes back with a new device id after its firmware loads, and a
webcam that survives replugging. Immich uses the iGPU. Nothing else needs hardware, so nothing else should
share the privileged container.

**Cost.** Root on docker-hw is root on the host, and passing the whole USB bus for the Coral also exposes
the backup disk on the same controller. Accepted because docker-hw isn't reachable from the internet.
The way out is an unprivileged docker-hw with per-device passthrough.
