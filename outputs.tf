output "name" {
  description = "Name of the instance."
  value       = google_compute_instance.this.name
}

output "zone" {
  description = "Zone of the instance."
  value       = google_compute_instance.this.zone
}

output "internal_ip" {
  description = "Internal IPv4 address of the instance."
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "external_ip" {
  description = "Public IPv4 address (static or ephemeral), or null if the instance has none."
  value       = try(google_compute_instance.this.network_interface[0].access_config[0].nat_ip, null)
}

output "service_account_email" {
  description = "Email of the instance's dedicated service account."
  value       = google_service_account.this.email
}
