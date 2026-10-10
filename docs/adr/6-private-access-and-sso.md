# 6: LAN and Tailscale only, behind Authelia

Apps are reachable from the LAN and over Tailscale only: no Cloudflare tunnels and no public DNS records.
Traefik serves all of them with one Let's Encrypt wildcard certificate for `*.<domain>`, issued through
Cloudflare DNS-01 with a token limited to that zone. AdGuard's wildcard rewrite points the names at
docker-apps. The only forwarded port is Plex's, to its own unprivileged LXC.

Authelia sits in front of the apps as Traefik forward-auth (except Home Assistant, Plex, Immich and
Frigate, whose phone apps can't log in through it) and is the OIDC provider for apps that support it, so there is one login with 2FA instead of one per app. Keycloak is too heavy for a 4-core N150; Pocket
ID was also considered. Authelia was checked for maintainer activity and bus factor. Its JWT, session and
storage encryption secrets are in the vault; the OIDC keys and client secrets are generated on docker-apps
and never leave it.
