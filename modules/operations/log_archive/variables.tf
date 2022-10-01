variable "project_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "log_filter" {
  type = string
}

variable "log_archive_location" {
  type = string
}

variable "log_archive_storage_force_destroy" {
  type    = bool
  default = false
}

variable "log_archive_retention_policy" {
  type = number
}
