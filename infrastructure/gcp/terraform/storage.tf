resource "google_storage_bucket" "data_lake_bucket" {
  name     = var.gcs_datalake_bucket_name
  location = var.region

  force_destroy               = true
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

output "datalake_bucket" {
  value = {
    self_link = google_storage_bucket.data_lake_bucket.self_link
    url       = google_storage_bucket.data_lake_bucket.url
  }
}
