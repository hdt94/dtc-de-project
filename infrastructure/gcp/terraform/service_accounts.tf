resource "google_service_account" "dbt_sa" {
  account_id   = "dbt-sa"
  display_name = "dbt Service Account"
}

output "dbt_sa" {
  value = google_service_account.dbt_sa.email
}