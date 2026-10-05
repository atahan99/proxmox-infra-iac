# ENV=lab: only the throwaway test container. Never touches the real guests (own workspace + state).

lxcs = {
  iac-test = {
    vmid       = 990
    cores      = 2
    memory     = 6144                # all docker-apps stacks at once (prod: 8192)
    disk       = 50                  # enough for all docker-apps stacks at once (prod: 80)
    mac        = "BC:24:11:68:87:5F" # not in the OpenWrt reservations
    host       = 90                  # outside the DHCP pool
    onboot     = false
    protection = false
    tags       = ["lab"]
  }
}
