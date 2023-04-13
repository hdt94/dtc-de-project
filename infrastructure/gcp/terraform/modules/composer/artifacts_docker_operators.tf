resource "google_artifact_registry_repository" "airflow_docker_operators" {
  description   = "Docker repository for Airflow Docker Operator images"
  format        = "DOCKER"
  location      = var.region
  repository_id = "airflow-docker-operators"
}

resource "google_artifact_registry_repository_iam_member" "composer_reader" {
  location   = google_artifact_registry_repository.airflow_docker_operators.location
  member     = "serviceAccount:${var.agent_service_account.email}"
  repository = google_artifact_registry_repository.airflow_docker_operators.name
  role       = "roles/artifactregistry.reader"
}

locals {
  docker_operators_registry_host = "${var.region}-docker.pkg.dev"
  docker_operators_registry_url  = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.airflow_docker_operators.repository_id}"
}
