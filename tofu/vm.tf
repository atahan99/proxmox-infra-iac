# HAOS. The qcow2 image is downloaded, checked and unpacked into local:import/ by
# Ansible (haos_image): HAOS ships as .qcow2.xz, which download_file can't unpack.
resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.vms

  node_name     = var.node
  vm_id         = each.value.vmid
  name          = each.key
  machine       = "q35"
  bios          = "ovmf"
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true
  started       = true
  protection    = each.value.protection
  tags          = sort(concat(["tofu"], each.value.tags))

  dynamic "startup" {
    for_each = each.value.startup == null ? [] : [each.value.startup]
    content {
      order    = startup.value
      up_delay = 15
    }
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  efi_disk {
    datastore_id = "local-lvm"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    import_from  = "local:import/${each.value.image}"
    size         = each.value.disk
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac
  }

  serial_device {} # HAOS console via `qm terminal`

  operating_system {
    type = "l26"
  }

  # HAOS updates itself; a newer image name in tfvars must never re-import the disk.
  lifecycle {
    ignore_changes = [disk[0].import_from]
  }
}
