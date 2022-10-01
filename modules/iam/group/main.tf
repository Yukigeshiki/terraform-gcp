resource "google_cloud_identity_group" "iam_group" {

  display_name         = var.display_name
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/${var.customer_id}"

  group_key {
    id = var.group_key_id
  }

  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group_membership" "cloud_identity_engineering_group_members" {

  for_each = toset(var.group_members)
  group    = google_cloud_identity_group.iam_group.id

  preferred_member_key {
    id = each.value
  }
  roles {
    name = "MEMBER"
  }

  depends_on = [google_cloud_identity_group.iam_group]
}
