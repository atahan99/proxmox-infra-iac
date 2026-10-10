# 6: LAN and Tailscale only, behind Authelia

**Decision.** Apps are reachable from the LAN and over Tailscale only: no Cloudflare tunnels, no public DNS
records. Traefik serves them all with one Let's Encrypt wildcard certificate, issued through Cloudflare
DNS-01 with a token limited to that zone, and AdGuard's wildcard rewrite points the names at docker-apps.
The only forwarded port is Plex's. Authelia is the forward-auth in front of the apps and the OIDC provider
for those that support it.

**Why.** One login with 2FA instead of one per app.
Keycloak is too heavy for a 4-core N150; Pocket ID was the other candidate. Authelia was checked for
maintainer activity and bus factor.

**Cost.** Home Assistant, Plex, Immich and Frigate stay outside Authelia because their phone apps can't
log in through it. Access from outside needs Tailscale on the device.
