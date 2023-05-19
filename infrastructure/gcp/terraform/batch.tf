locals {
  cloud_batch_parent = "projects/${var.project_id}/locations/${var.region}"
}

output "cloud_batch_parent" {
  value = local.cloud_batch_parent
}
