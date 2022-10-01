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

  env         = "test"
  org         = "robothouse.io"
  folder_name = "test"

  billing_acc_id = data.google_billing_account.my_billing_account.id

  eng_group_key              = "eng@${local.org}"
  eng_el_group_key           = "eng-el@${local.org}"
  cloudops_group_key         = "cloudops@${local.org}"
  serverless_robot_group_key = "serverless-sa-prod@${local.org}"
  serverless_robot_group_id  = "<serverless-robot-group-id>"  // test group ID TODO: Fetch this as data at runtime

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

resource "google_folder_iam_member" "cloudops_group_folder_permissions" {

  folder   = google_folder.env_folder.folder_id
  for_each = toset(local.cloudops_folder_permissions)
  role     = each.value

  member = "group:${local.cloudops_group_key}"

  depends_on = [google_folder.env_folder]
}
//---------------------------------------------------------------------------//
