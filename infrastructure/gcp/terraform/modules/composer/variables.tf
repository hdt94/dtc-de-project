variable "agent_service_account" {
  type = map(string)
}

variable "data_bucket_name" {
  default = {}
  type    = map(string)
}

variable "env_variables" {
  default = {}
  type    = map(string)
}

variable "name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "project_number" {
  type = string
}

variable "region" {
  type = string
}
