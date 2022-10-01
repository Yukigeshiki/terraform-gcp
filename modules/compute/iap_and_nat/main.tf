locals {

  iap_firewall_rule_name        = "allow-ingress-from-iap"
  iap_firewall_rule_description = "Allows ssh (port 22) connections by using IAP TCP forwarding"
  cloud_nat_name                = "cloud-nat-${var.region}"
  nat_router_name               = "nat-router-${var.region}"
  nat_router_config_name        = "nat-router-config-${var.region}"
}

resource "google_compute_subnetwork" "cloud_nat_subnet" {

  name          = local.cloud_nat_name
  ip_cidr_range = var.subnetwork_ip_cidr_range
  region        = var.region
  network       = var.host_vpc_id
  project       = var.project_id
}

resource "google_compute_router" "nat_router" {

  name    = local.nat_router_name
  region  = google_compute_subnetwork.cloud_nat_subnet.region
  network = var.host_vpc_name
  project = var.project_id

  depends_on = [google_compute_subnetwork.cloud_nat_subnet]
}

resource "google_compute_router_nat" "nat_router_config" {

  name                               = local.nat_router_config_name
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [google_compute_router.nat_router]
}

resource "google_compute_firewall" "allow_ingress_from_iap" {

  name        = local.iap_firewall_rule_name
  description = local.iap_firewall_rule_description
  network     = var.host_vpc_name
  project     = var.project_id

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  priority      = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
