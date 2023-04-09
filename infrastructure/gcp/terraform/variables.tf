variable "bq_dataset" {
  type = string
}

variable "gcs_datalake_bucket_name" {
  default = "datalake"
  type    = string
}

variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  default = "us-central1"
  type    = string
}
