locals {

  services = [
    "compute.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
  ]

  cr_alert_channel_members = var.cr_alert_channel_members
  // can be a group (eg. "group:group@...") or a single user (eg. "user:user@...")
  cr_service_owner         = var.cr_service_owner

  log_archive_filter           = "resource.type = \"cloud_run_revision\""
  log_archive_location         = var.log_archive_location
  // depending on log retention policy
  log_archive_retention_policy = var.log_archive_retention_policy
}

// Get random project ID integer
resource "random_integer" "rint" {

  min = 100000
  max = 999999
}

resource "google_project" "cloud_run_project" {

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
  project  = google_project.cloud_run_project.project_id
  service  = each.value

  depends_on = [google_project.cloud_run_project]
}

resource "google_compute_shared_vpc_service_project" "ftm_service" {

  host_project    = var.host_project_id
  service_project = google_project.cloud_run_project.project_id

  depends_on = [google_project_service.services]
}

module "project_core_service_accounts" {

  source = "../../../iam/core_service_accounts"

  project_id     = google_project.cloud_run_project.project_id
  project_number = google_project.cloud_run_project.number

  depends_on = [google_project_service.services]
}

module "service_owner" {

  source = "../../../iam/service_owner"

  project_id               = google_project.cloud_run_project.project_id
  cr_service_owner         = local.cr_service_owner
  cr_alert_channel_members = local.cr_alert_channel_members

  depends_on = [google_project.cloud_run_project]
}

module "project_log_archive" {

  source = "../../../operations/log_archive"

  project_id                   = google_project.cloud_run_project.project_id
  project_name                 = "${var.project_name}-${random_integer.rint.result}"
  log_filter                   = local.log_archive_filter
  log_archive_location         = local.log_archive_location
  log_archive_retention_policy = local.log_archive_retention_policy

  depends_on = [google_project.cloud_run_project]
}

// Add the serverless-robot-prod SA to the Serverless Robot Group with the VPC Access User role assigned
// This is to give Cloud Run access to the Serverless VPC Connector
resource "google_cloud_identity_group_membership" "serverless_robot_group_membership" {

  group = var.serverless_robot_prod_group_id

  preferred_member_key {
    id = "service-${google_project.cloud_run_project.number}@serverless-robot-prod.iam.gserviceaccount.com"
  }
  roles {
    name = "MEMBER"
  }

  depends_on = [google_project_service.services]
}

module "backend_security_policies" {

  source = "../../../network/backend_security_policies"

  project_id = google_project.cloud_run_project.project_id

  depends_on = [google_project_service.services]
}
