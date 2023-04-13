resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.bq_dataset
}

resource "google_project_iam_member" "bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.dbt_sa.member
}

resource "google_bigquery_dataset_iam_member" "bigquery_data_editor" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_service_account.dbt_sa.member
}

resource "google_bigquery_dataset_iam_member" "bigquery_user" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  role       = "roles/bigquery.user"
  member     = google_service_account.dbt_sa.member
}
