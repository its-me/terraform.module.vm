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

variable "allow_http_https" {
  description = "Whether to create a firewall rule opening TCP 80 and 443 to the internet. Only useful with a public IP; TLS is terminated on the instance itself."
  type        = bool
  default     = false
}

variable "allow_iap_ssh" {
  description = "Whether to create a firewall rule allowing SSH from Identity-Aware Proxy's range, so the instance is reachable via `gcloud compute ssh --tunnel-through-iap` without a public IP."
  type        = bool
  default     = true
}

variable "ssh_source_ranges" {
  description = "IPv4 CIDR ranges allowed to SSH (TCP 22) straight to the instance's public IP, e.g. [\"0.0.0.0/0\"] for anywhere or [\"203.0.113.4/32\"] for one address. Empty (the default) creates no rule. Only useful with a public IP; logins still go through OS Login."
  type        = list(string)
  default     = []
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
