variable "node" {
  type    = string
  default = "pve"
}

# Site values come from homelab.env as TF_VAR_*.
variable "lan_cidr" {
  type = string
}

variable "gateway" {
  type = string
}

variable "dns_vip" {
  type        = string
  description = "AdGuard's keepalived VIP: the DNS server every guest uses unless it sets its own."
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Root authorized_keys for every LXC (the Mac's key)."
  default     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKRIGv3fe6IIGbX6t07MTKAQPkmd31Qlnx6MQe+RPlKx mac-homelab"]
}

# One entry per LXC, keyed by hostname.
# Not here on purpose (root@pam-only, so Ansible sets them over SSH): bind mounts,
# devN passthrough, raw lxc.* lines and feature flags other than nesting.
variable "lxcs" {
  type = map(object({
    vmid         = number
    os           = optional(string, "debian") # debian | ubuntu, see local.templates
    cores        = optional(number, 1)
    cpu_limit    = optional(number, 0) # cores worth of CPU time across all cores, 0 = no cap
    memory       = number              # MiB
    swap         = optional(number, 512)
    disk         = number # GiB, local-lvm
    mac          = string
    host         = number                # host number in var.lan_cidr: 122 = .122
    dns_gateway  = optional(bool, false) # resolve via the router instead of the VIP (AdGuard itself)
    unprivileged = optional(bool, true)
    onboot       = optional(bool, true)
    startup      = optional(number) # boot order, lower first
    protection   = optional(bool, false)
    tags         = optional(list(string), [])
  }))
}

variable "vms" {
  type = map(object({
    vmid       = number
    cores      = number
    memory     = number # MiB
    disk       = number # GiB
    mac        = string
    image      = string # file in local:import/, put there by Ansible (haos_image)
    startup    = optional(number)
    protection = optional(bool, false)
    tags       = optional(list(string), [])
  }))
  default = {}
}
