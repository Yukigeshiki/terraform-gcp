provider "google" {
  user_project_override = true
  billing_project       = var.project
}

provider "google-beta" {
  project = var.project
}

// Get billing account ID
data "google_billing_account" "my_billing_account" {

  display_name = "My Billing Account"
  open         = true
}

locals {

  env         = "prod"
  org         = "robothouse.io"
  folder_name = "production"

  billing_acc_id = data.google_billing_account.my_billing_account.id

  eng_group_key              = "eng@${local.org}"
  eng_el_group_key           = "eng-el@${local.org}"
  cloudops_group_key         = "cloudops@${local.org}"
  serverless_robot_group_key = "serverless-sa-prod@${local.org}"
  serverless_robot_group_id  = "<serverless-robot-group-id>"  // prod group ID TODO: Fetch this as data at runtime

  logging_sink_bucket = "aggregated-logging-sink-bucket"

  eng_group_folder_permissions    = [
    "roles/browser",
    "roles/monitoring.viewer",
    "roles/logging.viewer",
    "roles/logging.viewAccessor",
    "roles/cloudbuild.builds.viewer",
    "roles/run.viewer",
    "roles/errorreporting.viewer",
    "roles/redis.viewer",
  ]
  eng_el_group_folder_permissions = [
    "roles/viewer",
    "roles/iap.tunnelResourceAccessor",
    "roles/iam.serviceAccountUser",
  ]
  cloudops_folder_permissions     = [
    "roles/viewer",
    "roles/compute.loadBalancerAdmin",
    "roles/monitoring.admin",
    "roles/logging.admin",
    "roles/errorreporting.admin",
    "roles/secretmanager.admin",
    "roles/cloudbuild.builds.editor",
    "roles/cloudscheduler.admin",
    "roles/run.admin",
    "roles/compute.securityAdmin",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/iap.tunnelResourceAccessor",
    "roles/iam.serviceAccountUser",
  ]

  // project names
  host_project_name          = "vpc-host-${local.env}"
  project1_project_name      = "project1-${local.env}"
  shared_redis_project1_name = "shared-redis-${local.env}"
}

// Get org ID
data "google_organization" "org" {

  domain = local.org
}

// Create top level folder
resource "google_folder" "env_folder" {

  display_name = local.folder_name
  parent       = data.google_organization.org.name

  depends_on = [data.google_organization.org]
}

//---------------------------------------------------------------------------// group permissions for folder
resource "google_folder_iam_member" "eng_group_folder_permissions" {

  folder   = google_folder.env_folder.folder_id
  for_each = toset(local.eng_group_folder_permissions)
  role     = each.value

  member = "group:${local.eng_group_key}"

  depends_on = [google_folder.env_folder]
}

resource "google_folder_iam_member" "eng_el_group_folder_permissions" {

  folder   = google_folder.env_folder.folder_id
  for_each = toset(local.eng_el_group_folder_permissions)
  role     = each.value

  member = "group:${local.eng_el_group_key}"

  depends_on = [google_folder.env_folder]
}

resource "google_folder_iam_member" "cloudops_group_folder_permissions" {

  folder   = google_folder.env_folder.folder_id
  for_each = toset(local.cloudops_folder_permissions)
  role     = each.value

  member = "group:${local.cloudops_group_key}"

  depends_on = [google_folder.env_folder]
}
//---------------------------------------------------------------------------//

// Create host project with shared VPC and Serverless VPC connector
module "host_project" {

  source = "../../modules/projects/host_project"

  folder_id                     = google_folder.env_folder.folder_id
  billing_account               = local.billing_acc_id
  project_name                  = local.host_project_name
  vpc_access_conn_machine_type  = "f1-micro" // https://cloud.google.com/compute/vm-instance-pricing
  vpc_access_conn_min_instances = 2
  vpc_access_conn_max_instances = 8

  depends_on = [google_folder.env_folder, data.google_billing_account.my_billing_account]
}

// Host project permissions for serverless-robot group
// This is to allow service projects (those which own the serverless-robot service accounts in the group) to gain
// access to the VPC Connector
resource "google_project_iam_member" "serverless_robot_group_host_permissions" {

  project = module.host_project.project_id
  role    = "roles/vpcaccess.user"

  member = "group:${local.serverless_robot_group_key}"

  depends_on = [module.host_project]
}

//---------------------------------------------------------------------------// folder logging sink
// create aggregated logging sink for env folder
// - the logging bucket (aggregated-logging-sink-bucket) was created manually as Terraform currently does not have an
//   API to create logging buckets
resource "google_logging_folder_sink" "aggregated_logging_sink" {

  name        = "aggregated-logging-sink"
  folder      = google_folder.env_folder.name
  destination = "logging.googleapis.com/projects/${module.host_project.project_id}/locations/global/buckets/${local.logging_sink_bucket}"
  filter      = "resource.type = \"cloud_run_revision\" OR resource.type = \"redis_instance\""

  // include all child folders
  include_children = true

  depends_on = [module.host_project]
}

// give the logging sink writer identity access to the logs storage bucket
resource "google_project_iam_binding" "log_writer" {

  project = module.host_project.project_id
  role    = "roles/logging.bucketWriter"

  members = [
    google_logging_folder_sink.aggregated_logging_sink.writer_identity,
  ]

  depends_on = [google_logging_folder_sink.aggregated_logging_sink]
}
//---------------------------------------------------------------------------//

module "project_1" {

  source = "../../modules/projects/template_projects/cloud_run"

  project_name                   = local.project1_project_name
  billing_account                = local.billing_acc_id
  folder_id                      = google_folder.env_folder.folder_id
  host_project_id                = module.host_project.project_id
  cr_service_owner               = "group:product1@${local.org}"
  log_archive_location           = "US-CENTRAL1"
  log_archive_retention_policy   = 31540000 // 12 months (in seconds)
  serverless_robot_prod_group_id = local.serverless_robot_group_id
  cr_alert_channel_members       = {
    "Laurence Sonnenberg" = "laurence@${local.org}"
  }

  depends_on = [google_folder.env_folder, module.host_project, data.google_billing_account.my_billing_account]
}

module "aux_shared_redis_project" {

  source = "../../modules/projects/template_projects/shared_redis"

  folder_id                    = google_folder.env_folder.folder_id
  billing_account              = local.billing_acc_id
  project_name                 = local.shared_redis_project1_name
  host_project_id              = module.host_project.project_id
  network_id                   = module.host_project.vpc_network_id
  log_archive_location         = "US-CENTRAL1"
  log_archive_retention_policy = 31540000 // 12 months (in seconds)

  redis_config = {
    "instance_name"  = "${local.shared_redis_project1_name}-instance",
    "memory_size_gb" = 2,
    "region"         = "us-central1",
    "version"        = "REDIS_6_X",
    "auth_enabled"   = true
  }

  depends_on = [google_folder.env_folder, module.host_project, data.google_billing_account.my_billing_account]
}
