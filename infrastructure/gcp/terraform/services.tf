resource "google_project_service" "composer" {
  disable_on_destroy = false
  project            = var.project
  service            = "composer.googleapis.com"
}

resource "google_project_service" "compute" {
  disable_on_destroy = false
  project            = var.project
  service            = "compute.googleapis.com"
}
