data "google_compute_default_service_account" "default" {
  depends_on = [google_project_service.compute]
}

resource "google_service_account" "dbt_sa" {
  account_id   = "dbt-sa"
  display_name = "dbt Service Account"
}

module "service_account_external_orchestrator" {
  source = "./modules/service_account_external_orchestrator"
  count  = var.external_orchestrator ? 1 : 0

  data_bucket_name = google_storage_bucket.data_lake_bucket.name
}

output "dbt_sa" {
  value = google_service_account.dbt_sa.email
}

output "external_orchestrator_sa" {
  value = var.external_orchestrator ? module.service_account_external_orchestrator[0].email : null
}
