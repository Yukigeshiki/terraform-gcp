resource "google_service_account" "service_account" {

  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
}

// custom service accounts should be assigned individual custom roles
resource "google_project_iam_binding" "iam_roles" {

  for_each = var.roles
  project  = var.project_id
  role     = each.value

  members = [
    "serviceAccount:${google_service_account.service_account.email}",
  ]

  depends_on = [google_service_account.service_account]
}
