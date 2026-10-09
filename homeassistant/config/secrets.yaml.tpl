# Rendered by `make ha-deploy` from homelab.env ($VARS) straight into /config/secrets.yaml on HA; never on
# disk here. docker_apps_ip: docker-apps' host number in tofu/prod.tfvars.
pc_mac: "${PC_MAC}"
pc_ip: "${PC_IP}"
docker_apps_ip: "${HOMELAB_LAN_PREFIX}.122"
