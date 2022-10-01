locals {

  services = [
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
  ]

  // all user emails can be found in the terraform.tfvars file in the dev env
  alert_channel_members = tomap({
    "Laurence Sonnenberg" = "laurence@robothouse.io",
  })

  // for private services access
  private_ip_alloc_name = "private-services-access-ip-alloc"

  // for serverless vpc connector
  northamerica_northeast1_subnet_name = "vpc-conn-northamerica-northeast1"
  vpc_conn_namerica_neast1_name       = "vpc-conn-namerica-neast1"

  // for host network access vm
  host_network_access_sa_id   = "host-network-access-sa"
  host_network_access_sa_name = "Host Network Access Service Account"
  host_network_access_vm_name = "host-network-access-vm"
}

// Get random project ID integer
resource "random_integer" "rint" {

  min = 100000
  max = 999999
}

resource "google_project" "host_project" {

  name                = var.project_name
  project_id          = "${var.project_name}-${random_integer.rint.result}"
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  labels              = {}

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }
}

resource "google_project_service" "services" {

  for_each = toset(local.services)
  project  = google_project.host_project.project_id
  service  = each.value

  depends_on = [google_project.host_project]
}

// vpcaccess service depends on compute service
resource "google_project_service" "vpc_access_service" {

  project = google_project.host_project.project_id
  service = "vpcaccess.googleapis.com"

  depends_on = [google_project_service.services]
}

resource "google_compute_network" "host_vpc" {
  provider = google-beta

  name                    = "host-vpc"
  project                 = google_project.host_project.project_id
  auto_create_subnetworks = true

  depends_on = [google_project_service.services]
}

resource "google_compute_shared_vpc_host_project" "shared_vpc" {

  project = google_project.host_project.project_id

  depends_on = [google_compute_network.host_vpc]
}

resource "google_monitoring_notification_channel" "alert_notification_channels" {

  for_each     = local.alert_channel_members
  project      = google_project.host_project.project_id
  display_name = each.key

  type = "email"

  labels = {
    email_address = each.value
  }
}

//---------------------------------------------------------------------------// private services access
// This is used to connect resources (eg. Redis, Cloud SQL) to the shared VPC
resource "google_compute_global_address" "private_ip_alloc" {
  provider = google-beta

  project       = google_project.host_project.project_id
  name          = local.private_ip_alloc_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.host_vpc.id

  depends_on = [google_project_service.vpc_access_service]
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  network                 = google_compute_network.host_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  depends_on = [google_compute_global_address.private_ip_alloc]
}
//---------------------------------------------------------------------------//

//---------------------------------------------------------------------------// serverless vpc connector
// This is so serverless applications (eg. Cloud Run instances) can access internal resources (eg. Redis) on
// the shared VPC
resource "google_compute_subnetwork" "northamerica_northeast1_subnet" {
  provider = google-beta

  name          = local.northamerica_northeast1_subnet_name
  ip_cidr_range = "10.2.0.0/28"
  region        = "northamerica-northeast1"
  network       = google_compute_network.host_vpc.id
  project       = google_project.host_project.project_id

  depends_on = [google_compute_network.host_vpc]
}

resource "google_vpc_access_connector" "vpc_conn_namerica_neast1" {
  provider = google-beta

  // region shortened in name to namerica-neast1 to fit the ID required pattern: ^[a-z][-a-z0-9]{0,23}[a-z0-9]$
  name          = local.vpc_conn_namerica_neast1_name
  region        = google_compute_subnetwork.northamerica_northeast1_subnet.region
  machine_type  = var.vpc_access_conn_machine_type
  min_instances = var.vpc_access_conn_min_instances
  max_instances = var.vpc_access_conn_max_instances
  project       = google_project.host_project.project_id

  subnet {
    name = google_compute_subnetwork.northamerica_northeast1_subnet.name
  }

  lifecycle {
    ignore_changes = [
      network,
      max_throughput,
    ]
  }

  depends_on = [google_project_service.vpc_access_service, google_compute_subnetwork.northamerica_northeast1_subnet]
}
//---------------------------------------------------------------------------//

//---------------------------------------------------------------------------// host network access vm
// This VM (and it's accompanying components) provides authorised users with the ability to ssh in and gain CLI
// access to resources on the environment's shared network - eg. shared Redis instances
module "iap_and_nat" {

  source = "../../compute/iap_and_nat"

  host_vpc_id              = google_compute_network.host_vpc.id
  host_vpc_name            = google_compute_network.host_vpc.name
  project_id               = google_project.host_project.project_id
  subnetwork_ip_cidr_range = "10.3.0.0/28"
  region                   = "us-central1"

  depends_on = [google_compute_network.host_vpc]
}

resource "google_service_account" "host_network_access_sa" {

  account_id   = local.host_network_access_sa_id
  display_name = local.host_network_access_sa_name
  project      = google_project.host_project.project_id

  depends_on = [google_project.host_project]
}

resource "google_compute_instance" "host_network_access_vm" {

  name         = local.host_network_access_vm_name
  machine_type = "f1-micro"
  zone         = "${module.iap_and_nat.subnetwork_region}-a"
  project      = google_project.host_project.project_id

  tags = ["host-network-access"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/debian-11-bullseye-v20220920"
    }
  }

  network_interface {
    network    = google_compute_network.host_vpc.name
    subnetwork = module.iap_and_nat.subnetwork_self_link
  }

  service_account {
    email  = google_service_account.host_network_access_sa.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    ignore_changes = [
      metadata,
    ]
  }

  depends_on = [google_service_account.host_network_access_sa, module.iap_and_nat]
}
//---------------------------------------------------------------------------//
