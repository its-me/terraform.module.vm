variable "project_id" {
  description = "GCP project ID the instance lives in."
  type        = string
}

variable "zone" {
  description = "GCP zone for the instance (e.g. \"me-west1-a\")."
  type        = string
}

variable "name" {
  description = "Name of the Compute Engine instance. Also used for its service account and firewall rule."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to attach the instance to (e.g. module.network.subnet_id from terraform.module.network)."
  type        = string
}

variable "machine_type" {
  description = "Machine type. e2-micro (2 shared vCPUs, 1 GB) is the smallest available."
  type        = string
  default     = "e2-micro"
}

variable "boot_disk_image" {
  description = "Boot disk image or image family (project/family)."
  type        = string
  default     = "debian-cloud/debian-13"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. 10 is the minimum for the default Debian 13 image."
  type        = number
  default     = 10
}

variable "boot_disk_type" {
  description = "Boot disk type. pd-standard is the cheapest."
  type        = string
  default     = "pd-standard"
}

variable "assign_external_ip" {
  description = "Whether to give the instance an ephemeral public IPv4 address, which changes on stop/start. Without a public IP (and without Cloud NAT on the network), the instance has no outbound internet access. Ignored when static_external_ip = true."
  type        = bool
  default     = false
}

variable "static_external_ip" {
  description = "Whether to reserve a static public IPv4 address for the instance, so DNS can point straight at it without a load balancer. Takes precedence over assign_external_ip."
  type        = bool
  default     = false
}

variable "external_ipv6" {
  description = "Whether a VM with a public IPv4 (static_external_ip or assign_external_ip) also gets a public IPv6 address, static when static_external_ip = true. Requires a dual-stack subnet with external IPv6 (terraform.module.network's external_ipv6). allow_http_https then opens 80/443 to ::/0 as well."
  type        = bool
  default     = true
}

variable "allow_http_https" {
  description = "Whether to create a firewall rule opening TCP 80 and 443 to the internet. Only useful with a public IP; TLS is terminated on the instance itself."
  type        = bool
  default     = false
}

variable "allow_icmp" {
  description = "Whether to create firewall rules allowing ICMP (ping) from the internet, over IPv4 and, when the instance has a public IPv6, ICMPv6. Only useful with a public IP."
  type        = bool
  default     = false
}

variable "allow_iap_ssh" {
  description = "Whether to create a firewall rule allowing SSH from Identity-Aware Proxy's range, so the instance is reachable via `gcloud compute ssh --tunnel-through-iap` without a public IP."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "IPv4 CIDR ranges allowed to SSH (TCP 22) straight to the instance's public IP, e.g. [\"0.0.0.0/0\"] for anywhere or [\"203.0.113.4/32\"] for one address. IPv6 ranges (e.g. [\"::/0\"]) are allowed too and get their own rule. Empty (the default) creates no rule. Only useful with a public IP."
  type        = list(string)
  default     = []
}

variable "ssh_keys" {
  description = "Map of Linux username -> SSH public key (e.g. \"ssh-ed25519 AAAA... me@laptop\") to install on the instance. Setting any turns OS Login off and blocks project-wide metadata keys, so only these keys (and IAP-tunnelled logins using them) work; each user is created with sudo by the guest agent. Empty (the default) keeps OS Login, where access follows IAM roles instead."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for user in keys(var.ssh_keys) : can(regex("^[a-z_][a-z0-9_-]{0,31}$", user))])
    error_message = "ssh_keys usernames must be valid Linux usernames: lowercase letters, digits, '_' or '-', starting with a letter or '_', at most 32 characters."
  }

  validation {
    condition     = alltrue([for key in values(var.ssh_keys) : can(regex("^(ssh-|ecdsa-|sk-)[^ ]+ [A-Za-z0-9+/=]+", key))])
    error_message = "ssh_keys values must be OpenSSH public keys, e.g. \"ssh-ed25519 AAAA... comment\"."
  }
}

variable "deletion_protection" {
  description = "Whether to block deletion of the instance."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels applied to the instance and its boot disk."
  type        = map(string)
  default     = {}
}
