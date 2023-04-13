module "composer" {
  source = "./modules/composer"
  count  = var.composer ? 1 : 0
  depends_on = [
    google_project_service.artifacts,
    google_project_service.composer,
  ]

  agent_service_account = data.google_compute_default_service_account.default
  name                  = "dev-env"
  project_id            = var.project_id
  project_number        = data.google_project.project.number
  region                = var.region

  env_variables = {
    data_bucket_name = google_storage_bucket.data_lake_bucket.name
  }
}

output "composer" {
  value = module.composer[0].env
}
