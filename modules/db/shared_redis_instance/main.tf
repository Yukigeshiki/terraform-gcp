// This module assumes that the project associated with `project_id` is a service project of the host project
// that owns the VPC network associated with `network_id`.

locals {

  services = [
    "servicenetworking.googleapis.com",
    "redis.googleapis.com",
  ]

  instance_name  = var.redis_config.instance_name
  memory_size_gb = var.redis_config.memory_size_gb
  region         = var.redis_config.region
  version        = var.redis_config.version
  auth_enabled   = var.redis_config.auth_enabled
}

resource "google_project_service" "services" {

  for_each = toset(local.services)
  project  = var.project_id
  service  = each.value
}

resource "google_redis_instance" "shared_redis_instance" {
  name           = local.instance_name
  tier           = "STANDARD_HA"
  memory_size_gb = local.memory_size_gb

  region                  = local.region
  location_id             = "${local.region}-a"
  alternative_location_id = "${local.region}-b"

  project            = var.project_id
  authorized_network = var.network_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  auth_enabled       = local.auth_enabled

  redis_version = local.version
  display_name  = title(join(" ", split("-", local.instance_name)))

  depends_on = [google_project_service.services]
  // NB: this resource also depends on Private Services Access in the host project
}
