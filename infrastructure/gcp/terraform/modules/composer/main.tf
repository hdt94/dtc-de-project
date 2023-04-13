resource "google_service_account_iam_member" "custom_service_account" {
  service_account_id = var.agent_service_account.id
  role               = "roles/composer.ServiceAgentV2Ext"
  member             = "serviceAccount:service-${var.project_number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

resource "google_composer_environment" "env" {
  depends_on = [google_service_account_iam_member.custom_service_account]

  name   = var.name
  region = var.region

  config {
    software_config {
      image_version = "composer-1.20.11-airflow-2.4.3"
      env_variables = var.env_variables
    }
  }
}
