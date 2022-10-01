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

  env         = "dev"
  org         = "robothouse.io"
  folder_name = "development"

  billing_acc_id = data.google_billing_account.my_billing_account.id

  // teams
  eng_group_key       = "eng@${local.org}"
  eng_group_name      = "Engineering Team"
  eng_el_group_key    = "eng-el@${local.org}"
  eng_el_group_name   = "Engineering Team Elevated"
  cloudops_group_key  = "cloudops@${local.org}"
  cloudops_group_name = "Cloud Operations Team"

  // product teams
  product1_product_group_name = "Product 1 Product Team"
  product1_product_group_key  = "product1@${local.org}"
  product2_product_group_name = "Product 2 Product Team"
  product2_product_group_key  = "product2@${local.org}"
  product3_product_group_name = "Product 3 Product Team"
  product3_product_group_key  = "product3@${local.org}"

  logging_sink_bucket = "aggregated-logging-sink-bucket"

  serverless_robot_group_id  = "<serverless-robot-group-id>"  // dev group ID TODO: Fetch this as data at runtime
  serverless_robot_group_key = "serverless-sa-dev@${local.org}"
  serverless_robot           = [
    {
      serverless_robot_group_key  = local.serverless_robot_group_key,
      serverless_robot_group_name = "Serverless Robot Group Dev"
    },
    {
      serverless_robot_group_key  = "serverless-sa-test@${local.org}"
      serverless_robot_group_name = "Serverless Robot Group Test"
    },
    {
      serverless_robot_group_key  = "serverless-sa-prod@${local.org}"
      serverless_robot_group_name = "Serverless Robot Group Prod"
    }
  ]

  eng_group_folder_permissions = [
    "roles/viewer",
    "roles/logging.viewAccessor",
    "roles/iap.tunnelResourceAccessor",
    "roles/iam.serviceAccountUser",
  ]
  cloudops_folder_permissions  = [
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
  ]

  // project names
  host_project_name          = "vpc-host-${local.env}"
  project1_project_name      = "project1-${local.env}"
  shared_redis_project1_name = "shared-redis-project1-${local.env}"
}

// Get org ID
data "google_organization" "org" {

  domain = local.org
}

//---------------------------------------------------------------------------// global iam groups
// This code block is not duplicated in the prod env as these groups are created globally just once
module "eng_group" {

  source = "../../modules/iam/group"

  customer_id   = data.google_organization.org.directory_customer_id
  display_name  = local.eng_group_name
  group_key_id  = local.eng_group_key
  group_members = var.eng_group_members

  depends_on = [data.google_organization.org]
}

module "eng_el_group" {

  source = "../../modules/iam/group"

  customer_id   = data.google_organization.org.directory_customer_id
  display_name  = local.eng_el_group_name
  group_key_id  = local.eng_el_group_key
  group_members = var.eng_el_group_members

  depends_on = [data.google_organization.org]
}

module "cloud_ops_team_group" {

  source = "../../modules/iam/group"

  customer_id   = data.google_organization.org.directory_customer_id
  display_name  = local.cloudops_group_name
  group_key_id  = local.cloudops_group_key
  group_members = var.cloudops_group_members

  depends_on = [data.google_organization.org]
}

// -- Product Groups -- //
// These groups are per product - they are used to grant service owner permissions in Cloud Run projects
module "product1_product_group" {

  source = "../../modules/iam/group"

  customer_id   = data.google_organization.org.directory_customer_id
  display_name  = local.product1_product_group_name
  group_key_id  = local.product1_product_group_key
  group_members = var.product1_group_members

  depends_on = [data.google_organization.org]
}

module "product2_product_group" {

  source = "../../modules/iam/group"

  customer_id   = data.google_organization.org.directory_customer_id
  display_name  = local.product2_product_group_name
  group_key_id  = local.product2_product_group_key
  group_members = var.product2_group_members

  depends_on = [data.google_organization.org]
}

module "product3_product_group" {

  source = "../../modules/iam/group"

  customer_id   = data.google_organization.org.directory_customer_id
  display_name  = local.product3_product_group_name
  group_key_id  = local.product3_product_group_key
  group_members = var.product3_group_members

  depends_on = [data.google_organization.org]
}
// -------------------- //

// Create groups for serverless-robot-prod service accounts (dev and prod envs)
// These groups will hold serverless-robot service accounts for service projects that need access to the VPC
// Connector in each environment's host project
resource "google_cloud_identity_group" "serverless_robot_group" {

  for_each             = toset(keys({for i, r in local.serverless_robot :  i => r}))
  display_name         = local.serverless_robot[each.value].serverless_robot_group_name
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/${data.google_organization.org.directory_customer_id}"

  group_key {
    id = local.serverless_robot[each.value].serverless_robot_group_key
  }

  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}
//---------------------------------------------------------------------------//

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

  depends_on = [google_folder.env_folder, module.eng_group]
}

resource "google_folder_iam_member" "cloudops_group_folder_permissions" {

  folder   = google_folder.env_folder.folder_id
  for_each = toset(local.cloudops_folder_permissions)
  role     = each.value

  member = "group:${local.cloudops_group_key}"

  depends_on = [google_folder.env_folder, module.cloud_ops_team_group]
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
  vpc_access_conn_max_instances = 4

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

module "shared_redis_project_1" {

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
    "memory_size_gb" = 1,
    "region"         = "us-central1",
    "version"        = "REDIS_6_X",
    "auth_enabled"   = true
  }

  depends_on = [google_folder.env_folder, module.host_project, data.google_billing_account.my_billing_account]
}
