variable "project_id" {
  type = string
}

variable "host_project_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "redis_config" {
  type = object({
    instance_name  = string,
    memory_size_gb = number,
    region         = string,
    version        = string
    auth_enabled   = bool,
  })
}
