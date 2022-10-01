output "subnetwork_region" {
  value = google_compute_subnetwork.cloud_nat_subnet.region
}

output "subnetwork_self_link" {
  value = google_compute_subnetwork.cloud_nat_subnet.self_link
}
