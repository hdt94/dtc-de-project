variable "bq_dataset" {
  type = string
}

variable "composer" {
  default = true
  type    = bool
}

variable "gcs_datalake_bucket_name" {
  default = "datalake"
  type    = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  default = "us-central1"
  type    = string
}
