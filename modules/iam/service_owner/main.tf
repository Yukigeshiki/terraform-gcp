locals {

  service_owner_role_title       = "Cloud Run Service Owner"
  service_owner_role_id          = "run.serviceOwner"
  service_owner_role_permissions = [
    // Cloud Run
    "iam.serviceAccounts.actAs",
    "run.revisions.delete",
    "run.services.create",
    "run.services.delete",
    "run.services.update",
  ]

  service_owner_default_roles = [
    "roles/run.developer",
    "roles/secretmanager.admin",
    "roles/cloudscheduler.admin",
  ]
}

// this role can evolve over time as the individual permissions needed become more clear to an org
resource "google_project_iam_custom_role" "service_owner_role" {

  title   = local.service_owner_role_title
  role_id = local.service_owner_role_id
  project = var.project_id

  permissions = local.service_owner_role_permissions
}

// the service owner custom role can be re-added and the default roles removed once the permissions
// needed are more clear
#resource "google_project_iam_binding" "cr_service_owner" {
#
#  project = var.project_id
#  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.service_owner.role_id}"
#
#  members = [
#    var.cr_service_owner,
#  ]
#
#  depends_on = [google_project_iam_custom_role.service_owner]
#}

resource "google_project_iam_member" "cr_service_owner_iam_member" {

  for_each = toset(local.service_owner_default_roles)
  project  = var.project_id
  role     = each.value

  member = var.cr_service_owner

  depends_on = [google_project_iam_custom_role.service_owner_role]
}

resource "google_monitoring_notification_channel" "notification_channels" {

  for_each     = var.cr_alert_channel_members
  project      = var.project_id
  display_name = each.key

  type = "email"

  labels = {
    email_address = each.value
  }
}
