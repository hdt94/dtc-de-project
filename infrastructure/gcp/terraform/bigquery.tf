resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.bq_dataset
}
