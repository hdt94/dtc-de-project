terraform {
  backend "local" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.50.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

data "google_project" "project" {
  project_id = var.project
}
