variable "project_id" {
  type = string
}

variable "cr_service_owner" {
  type = string
}

variable "cr_alert_channel_members" {
  type = map(string)
}
