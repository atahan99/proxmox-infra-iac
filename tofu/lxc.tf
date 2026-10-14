# Templates are downloaded by Ansible (pve_host).
locals {
  templates = {
    debian = "local:vztmpl/debian-13-standard_13.6-1_amd64.tar.zst"
    ubuntu = "local:vztmpl/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
  }
}

resource "proxmox_virtual_environment_container" "lxc" {
  for_each = var.lxcs

  node_name     = var.node
  vm_id         = each.value.vmid
  unprivileged  = each.value.unprivileged
  protection    = each.value.protection
  start_on_boot = each.value.onboot
  started       = true
  tags          = sort(concat(["tofu"], each.value.tags))

  dynamic "startup" {
    for_each = each.value.startup == null ? [] : [each.value.startup]
    content {
      order    = startup.value
      up_delay = 15
    }
  }

  initialization {
    hostname = each.key
    ip_config {
      ipv4 {
        address = "${cidrhost(var.lan_cidr, each.value.host)}/${split("/", var.lan_cidr)[1]}"
        gateway = var.gateway
      }
    }
    dns {
      servers = [each.value.dns_gateway ? var.gateway : var.dns_vip]
    }
    user_account {
      keys = var.ssh_public_keys
    }
  }

  cpu {
    cores = each.value.cores
    limit = each.value.cpu_limit
  }

  memory {
    dedicated = each.value.memory
    swap      = each.value.swap
  }

  disk {
    datastore_id = "local-lvm"
    size         = each.value.disk
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = each.value.mac
  }

  operating_system {
    template_file_id = local.templates[each.value.os]
    type             = each.value.os
  }

  # Every unprivileged guest sets nesting (systemd and Docker want it). Any feature on a privileged
  # guest, and the other features anywhere, are root@pam-only: Ansible (lxc_devices) sets those.
  dynamic "features" {
    for_each = each.value.unprivileged ? [1] : []
    content {
      nesting = true
    }
  }

  lifecycle {
    ignore_changes = [features, mount_point, device_passthrough, idmap]
  }
}
