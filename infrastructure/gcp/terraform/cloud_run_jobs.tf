locals {
  cloud_run_jobs_parent = "projects/${var.project_id}/locations/${var.region}"
}

output "cloud_run_jobs_parent" {
 value = local.cloud_run_jobs_parent
}
