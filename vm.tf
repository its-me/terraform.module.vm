locals {
  network_tag  = var.name
  region       = join("-", slice(split("-", var.zone), 0, 2))
  subnet_parts = regex("projects/([^/]+)/regions/([^/]+)/subnetworks/([^/]+)$", var.subnet_id)

  # Identity-Aware Proxy's TCP forwarding range, for `gcloud compute ssh --tunnel-through-iap`.
  iap_range         = "35.235.240.0/20"
  ssh_source_ranges = concat(var.allow_iap_ssh ? [local.iap_range] : [], var.ssh_source_ranges)

  firewall_rules = merge(
    length(local.ssh_source_ranges) > 0 ? {
      ssh = { ports = ["22"], source_ranges = local.ssh_source_ranges }
    } : {},
    var.allow_http_https ? {
      http-https = { ports = ["80", "443"], source_ranges = ["0.0.0.0/0"] }
    } : {},
  )
}

# Dedicated service account instead of the default compute SA, which has project Editor.
resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = "${var.name}-sa"
  display_name = "${var.name} Compute Engine instance"
}

resource "google_project_iam_member" "this" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_compute_address" "this" {
  count = var.static_external_ip ? 1 : 0

  name    = "${var.name}-ip"
  project = var.project_id
  region  = local.region
  labels  = var.labels
}

# subnet_id may be an ID (projects/P/regions/R/subnetworks/N) or a self link, so
# look the subnet up by its parts rather than by self_link, which rejects IDs.
data "google_compute_subnetwork" "this" {
  project = local.subnet_parts[0]
  region  = local.subnet_parts[1]
  name    = local.subnet_parts[2]
}

resource "google_compute_instance" "this" {
  name                = var.name
  project             = var.project_id
  zone                = var.zone
  machine_type        = var.machine_type
  deletion_protection = var.deletion_protection
  tags                = [local.network_tag]
  labels              = var.labels

  boot_disk {
    initialize_params {
      image  = var.boot_disk_image
      size   = var.boot_disk_size_gb
      type   = var.boot_disk_type
      labels = var.labels
    }
  }

  network_interface {
    subnetwork = var.subnet_id

    dynamic "access_config" {
      for_each = var.static_external_ip || var.assign_external_ip ? [1] : []
      content {
        nat_ip = one(google_compute_address.this[*].address)
      }
    }
  }

  service_account {
    email  = google_service_account.this.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = length(var.ssh_keys) > 0 ? {
    enable-oslogin         = "FALSE"
    block-project-ssh-keys = "TRUE"
    ssh-keys               = join("\n", [for user, key in var.ssh_keys : "${user}:${trimspace(key)}"])
    } : {
    enable-oslogin = "TRUE"
  }
}

resource "google_compute_firewall" "this" {
  for_each = local.firewall_rules

  name          = "${var.name}-allow-${each.key}"
  project       = var.project_id
  network       = data.google_compute_subnetwork.this.network
  direction     = "INGRESS"
  source_ranges = each.value.source_ranges
  target_tags   = [local.network_tag]

  allow {
    protocol = "tcp"
    ports    = each.value.ports
  }
}
