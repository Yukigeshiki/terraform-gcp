variable "project_name" {
  type = string
}

variable "project_id" {
  type    = string
  default = "project_id"
}

variable "host_project_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "billing_account" {
  type = string
}

variable "serverless_robot_prod_group_id" {
  type = string
}

variable "cr_service_owner" {
  type = string
}

variable "log_archive_retention_policy" {
  type = number
}

variable "log_archive_location" {
  type = string
}

variable "cr_alert_channel_members" {
  type = map(string)
}
