output "project_id" {
  value = google_project.host_project.project_id
}

output "vpc_network_id" {
  value = google_compute_network.host_vpc.id
}

output "vpc_network_name" {
  value = google_compute_network.host_vpc.name
}
