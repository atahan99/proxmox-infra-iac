terraform {
  required_version = ">= 1.10"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.116.0"
    }
  }

  # State and plans are always encrypted; OpenTofu refuses to write plaintext.
  # Passphrase: Proton Pass Homelab/opentofu (TF_VAR_state_passphrase via homelab.env).
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method   = method.aes_gcm.main
      enforced = true
    }
    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}

variable "state_passphrase" {
  type      = string
  sensitive = true
}

variable "pve_ip" {
  type = string
}

# API token comes from PROXMOX_VE_API_TOKEN (Makefile), the rest from homelab.env.
provider "proxmox" {
  endpoint = "https://${var.pve_ip}:8006/"
  # ponytail: PVE still serves its self-signed cert, so verification is off and a LAN MITM could
  # read the API token. Upgrade path (pve_host role): ACME DNS-01 cert for pve.<domain>
  # via the Cloudflare token, then point the endpoint at that name and drop this line.
  insecure = true
}
