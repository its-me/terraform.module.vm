locals {
  network_tag  = var.name
  region       = join("-", slice(split("-", var.zone), 0, 2))
  subnet_parts = regex("projects/([^/]+)/regions/([^/]+)/subnetworks/([^/]+)$", var.subnet_id)

  # Identity-Aware Proxy's TCP forwarding range, for `gcloud compute ssh --tunnel-through-iap`.
  iap_range         = "35.235.240.0/20"
  ssh_source_ranges = concat(var.allow_iap_ssh ? [local.iap_range] : [], var.ssh_source_ranges)

  external_ipv4 = var.static_external_ip || var.assign_external_ip
  external_ipv6 = var.external_ipv6 && local.external_ipv4

  # A firewall rule can't mix IPv4 and IPv6 source ranges, so each gets its own rule.
  ssh_ipv4_ranges = [for r in local.ssh_source_ranges : r if !strcontains(r, ":")]
  ssh_ipv6_ranges = [for r in local.ssh_source_ranges : r if strcontains(r, ":")]

  # ICMPv6 has no protocol name in GCP firewall rules, only its IP protocol number (58).
  firewall_rules = merge(
    length(local.ssh_ipv4_ranges) > 0 ? {
      ssh = { protocol = "tcp", ports = ["22"], source_ranges = local.ssh_ipv4_ranges }
    } : {},
    length(local.ssh_ipv6_ranges) > 0 ? {
      ssh-ipv6 = { protocol = "tcp", ports = ["22"], source_ranges = local.ssh_ipv6_ranges }
    } : {},
    var.allow_http_https ? {
      http-https = { protocol = "tcp", ports = ["80", "443"], source_ranges = ["0.0.0.0/0"] }
    } : {},
    var.allow_http_https && local.external_ipv6 ? {
      http-https-ipv6 = { protocol = "tcp", ports = ["80", "443"], source_ranges = ["::/0"] }
    } : {},
    var.allow_icmp ? {
      icmp = { protocol = "icmp", ports = null, source_ranges = ["0.0.0.0/0"] }
    } : {},
    var.allow_icmp && local.external_ipv6 ? {
      icmp-ipv6 = { protocol = "58", ports = null, source_ranges = ["::/0"] }
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

resource "google_compute_address" "ipv6" {
  count = var.static_external_ip && local.external_ipv6 ? 1 : 0

  name               = "${var.name}-ipv6"
  project            = var.project_id
  region             = local.region
  address_type       = "EXTERNAL"
  ip_version         = "IPV6"
  ipv6_endpoint_type = "VM"
  subnetwork         = var.subnet_id
  labels             = var.labels
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
    stack_type = local.external_ipv6 ? "IPV4_IPV6" : "IPV4_ONLY"

    dynamic "access_config" {
      for_each = local.external_ipv4 ? [1] : []
      content {
        nat_ip = one(google_compute_address.this[*].address)
      }
    }

    dynamic "ipv6_access_config" {
      for_each = local.external_ipv6 ? [1] : []
      content {
        network_tier  = "PREMIUM"
        external_ipv6 = one(google_compute_address.ipv6[*].address)
        # external_ipv6_prefix_length is left to GCP's default (/96): setting it
        # forces the instance to be replaced when IPv6 is added to an existing VM.
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

# Scheduled snapshots of the boot disk. Attached as a separate resource rather than via
# boot_disk.initialize_params.resource_policies, which would rebuild an existing VM.
resource "google_compute_resource_policy" "snapshots" {
  count = var.snapshot_schedule != null ? 1 : 0

  name    = "${var.name}-snapshots"
  project = var.project_id
  region  = local.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = var.snapshot_schedule.days_in_cycle
        start_time    = var.snapshot_schedule.start_time
      }
    }

    retention_policy {
      max_retention_days    = var.snapshot_schedule.retention_days
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      storage_locations = var.snapshot_schedule.storage_locations
      labels            = var.labels
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "snapshots" {
  count = var.snapshot_schedule != null ? 1 : 0

  name    = google_compute_resource_policy.snapshots[0].name
  project = var.project_id
  zone    = var.zone
  disk    = reverse(split("/", google_compute_instance.this.boot_disk[0].source))[0]
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
    protocol = each.value.protocol
    ports    = each.value.ports
  }
}
