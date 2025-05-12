resource "google_service_account" "sa" {
  account_id   = var.sa_name
  display_name = "Service Account for Airflow"
}

resource "google_project_iam_member" "sa_roles" {
  for_each = toset(var.roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_service_account_key" "sa_key" {
  service_account_id = google_service_account.sa.name
}

resource "google_secret_manager_secret" "sa_key_secret" {
  secret_id = "${var.sa_name}-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "sa_key_secret_version" {
  secret      = google_secret_manager_secret.sa_key_secret.id
  secret_data = base64decode(google_service_account_key.sa_key.private_key)
}
resource "google_secret_manager_secret_iam_member" "sa_key_access" {
  secret_id = google_secret_manager_secret.sa_key_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.sa.email}"
}
