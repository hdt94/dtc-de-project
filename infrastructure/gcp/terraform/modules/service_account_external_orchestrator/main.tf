resource "google_service_account" "external_orchestrator" {
  account_id   = "external-orchestrator"
  display_name = "External Orchestrator Service Account"
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = var.data_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.external_orchestrator.email}"
}
