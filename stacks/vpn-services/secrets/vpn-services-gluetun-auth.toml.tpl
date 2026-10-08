# gluetun's control server: a read-only API key (for a status widget); every other route stays denied.
[[roles]]
name = "readonly"
routes = ["GET /v1/publicip/ip", "GET /v1/portforward", "GET /v1/vpn/status"]
auth = "apikey"
apikey = "{{ pass://Homelab/gluetun-api/password }}"
