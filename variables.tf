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
  default     = "debian-cloud/debian-12"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. 10 is the minimum for the default Debian image."
  type        = number
  default     = 10
}

variable "boot_disk_type" {
  description = "Boot disk type. pd-standard is the cheapest."
  type        = string
  default     = "pd-standard"
}

variable "assign_external_ip" {
  description = "Whether to give the instance an ephemeral public IPv4 address. Without one (and without Cloud NAT on the network), the instance has no outbound internet access."
  type        = bool
  default     = false
}

variable "allow_iap_ssh" {
  description = "Whether to create a firewall rule allowing SSH from Identity-Aware Proxy's range, so the instance is reachable via `gcloud compute ssh --tunnel-through-iap` without a public IP."
  type        = bool
  default     = true
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
