output "env" {
  value = {
    docker_operators_registry_host = local.docker_operators_registry_host
    docker_operators_registry_url  = local.docker_operators_registry_url
    location                       = google_composer_environment.env.region
    name                           = google_composer_environment.env.name
  }
}
