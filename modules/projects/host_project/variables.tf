variable "project_name" {
  type = string
}

variable "project_id" {
  type    = string
  default = "project_id"
}

variable "folder_id" {
  type = string
}

variable "billing_account" {
  type = string
}

variable "vpc_access_conn_machine_type" {
  type = string
}

variable "vpc_access_conn_min_instances" {
  type = number
}

variable "vpc_access_conn_max_instances" {
  type = number
}
