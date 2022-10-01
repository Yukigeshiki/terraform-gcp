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

variable "network_id" {
  type = string
}

variable "log_archive_retention_policy" {
  type = number
}

variable "log_archive_location" {
  type = string
}

variable "redis_config" {
  type = object({
    instance_name  = string,
    memory_size_gb = number,
    region         = string,
    version        = string,
    auth_enabled   = bool,
  })
}
