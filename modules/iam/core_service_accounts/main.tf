// This module uses custom roles that have been created outside of Terraform. This was done so that the permissions
// found in these roles could remain flexible and be changed quickly with little friction.

locals {

  // TODO: keep an eye on GCP excess permission suggestions
  // roles for GitHub Actions SA
  ga_sa_roles  = [
    "roles/cloudbuild.serviceAgent",
  ]
  // roles for Cloud Run SA
  cr_sa_roles  = [
    "roles/run.invoker",
    "organizations/1071464837087/roles/cloudrun.corePermissions",
  ]
  // roles for Cloud Build SA
  cb_sa_roles  = [
    "organizations/1071464837087/roles/cloudbuild.corePermissions",
  ]
  // roles for serverless-robot-prod SA
  srp_sa_roles = [
    "roles/run.serviceAgent",
  ]

  github_actions_sa_account_id   = "github-actions-sa"
  github_actions_sa_display_name = "GitHub Actions Service Account"
  cloud_run_sa_account_id        = "cloud-run-sa"
  cloud_run_sa_display_name      = "Cloud Run Service Account"
}

module "ga_service_account" {

  source = "../service_account"

  project_id   = var.project_id
  roles        = toset(local.ga_sa_roles)
  account_id   = local.github_actions_sa_account_id
  display_name = local.github_actions_sa_display_name
}

module "cr_service_account" {

  source = "../service_account"

  project_id   = var.project_id
  roles        = toset(local.cr_sa_roles)
  account_id   = local.cloud_run_sa_account_id
  display_name = local.cloud_run_sa_display_name
}

//---------------------------------------------------------------------------// iam roles for gcp default SAs
resource "google_project_iam_binding" "cb_sa_iam_roles" {

  for_each = toset(local.cb_sa_roles)
  project  = var.project_id
  role     = each.value

  members = [
    "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com",
  ]
}

resource "google_project_iam_binding" "srp_sa_iam_roles" {

  for_each = toset(local.srp_sa_roles)
  project  = var.project_id
  role     = each.value

  members = [
    "serviceAccount:service-${var.project_number}@serverless-robot-prod.iam.gserviceaccount.com",
  ]
}
//---------------------------------------------------------------------------//
