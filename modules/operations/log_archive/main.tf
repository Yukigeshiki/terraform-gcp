locals {

  services = [
    "cloudresourcemanager.googleapis.com",
  ]

  log_archive_storage_name = "${var.project_name}-log-archive-storage" // the bucket name must be universally unique

  log_archive_sink_name        = "log-archive-sink"
  log_archive_sink_description = "Route logs to archive storage"
  log_archive_sink_destination = "storage.googleapis.com/${google_storage_bucket.log_archive_storage.name}"

}

resource "google_project_service" "services" {

  for_each = toset(local.services)
  project  = var.project_id
  service  = each.value
}

resource "google_storage_bucket" "log_archive_storage" {

  name     = local.log_archive_storage_name
  location = var.log_archive_location

  project       = var.project_id
  storage_class = "ARCHIVE"

  // If the archive bucket needs to be deleted, `log_archive_storage_force_destroy` will need to be set to true and
  // `log_archive_retention_policy` set to its minimum (1) before deletion is attempted.
  // These changes must be made so that if the data is deleted before the retention period is up, it is done
  // deliberately and not by accident.
  force_destroy = var.log_archive_storage_force_destroy
  retention_policy { retention_period = var.log_archive_retention_policy }
}

resource "google_logging_project_sink" "log_archive_sink" {

  name        = local.log_archive_storage_name
  description = local.log_archive_sink_description
  destination = local.log_archive_sink_destination
  filter      = var.log_filter // which resource's logs must be archived

  project                = var.project_id
  unique_writer_identity = true

  depends_on = [google_project_service.services, google_storage_bucket.log_archive_storage]
}

resource "google_project_iam_binding" "log_writer_iam" {

  project = var.project_id
  role    = "roles/storage.objectCreator"

  members = [
    google_logging_project_sink.log_archive_sink.writer_identity,
  ]

  depends_on = [google_logging_project_sink.log_archive_sink]
}
