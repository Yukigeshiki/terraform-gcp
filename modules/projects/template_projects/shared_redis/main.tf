locals {

  services = [
    "compute.googleapis.com",
  ]

  log_archive_filter           = "resource.type = \"redis_instance\""
  log_archive_location         = var.log_archive_location
  // depending on log retention policy
  log_archive_retention_policy = var.log_archive_retention_policy
}

// Get random project ID integer
resource "random_integer" "rint" {

  min = 100000
  max = 999999
}

resource "google_project" "shared_redis_project" {

  name                = var.project_name
  project_id          = "${var.project_name}-${random_integer.rint.result}"
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  labels              = {}
}

resource "google_project_service" "services" {

  for_each = toset(local.services)
  project  = google_project.shared_redis_project.project_id
  service  = each.value

  // container service api is enabled by default with redis and is dependent on compute service api
  disable_dependent_services = true

  depends_on = [google_project.shared_redis_project]
}

resource "google_compute_shared_vpc_service_project" "shared_redis_service" {

  host_project    = var.host_project_id
  service_project = google_project.shared_redis_project.project_id

  depends_on = [google_project_service.services]
}

module "shared_redis" {

  source = "../../../db/shared_redis_instance"

  project_id      = google_project.shared_redis_project.project_id
  host_project_id = var.host_project_id
  network_id      = var.network_id
  redis_config    = var.redis_config

  depends_on = [google_compute_shared_vpc_service_project.shared_redis_service]
}

module "project_log_archive" {

  source = "../../../operations/log_archive"

  project_id                   = google_project.shared_redis_project.project_id
  project_name                 = var.project_name
  log_filter                   = local.log_archive_filter
  log_archive_location         = local.log_archive_location
  log_archive_retention_policy = local.log_archive_retention_policy

  depends_on = [google_project.shared_redis_project]
}
