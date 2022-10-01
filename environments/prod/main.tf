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
  folder_name = "development"

  billing_acc_id = data.google_billing_account.my_billing_account.id
}

// Get org ID
data "google_organization" "org" {

  domain = local.org
}
