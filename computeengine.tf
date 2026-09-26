locals {
  network_tag = var.name
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

data "google_compute_subnetwork" "this" {
  self_link = var.subnet_id
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
      for_each = var.assign_external_ip ? [1] : []
      content {}
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

  metadata = {
    enable-oslogin = "TRUE"
  }
}

resource "google_compute_firewall" "iap_ssh" {
  count = var.allow_iap_ssh ? 1 : 0

  name          = "${var.name}-allow-iap-ssh"
  project       = var.project_id
  network       = data.google_compute_subnetwork.this.network
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [local.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
