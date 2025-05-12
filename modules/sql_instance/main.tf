resource "google_secret_manager_secret" "db_user" {
  secret_id = var.db_username_secret_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_user_version" {
  secret      = google_secret_manager_secret.db_user.id
  secret_data = var.db_user
}

resource "google_secret_manager_secret_iam_member" "db_user_access" {
  secret_id = google_secret_manager_secret.db_user.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.airflow_sa_email}"
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = var.db_password_secret_id
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

resource "google_secret_manager_secret_iam_member" "db_password_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.airflow_sa_email}"
}

resource "google_sql_database_instance" "airflow" {
  name             = var.db_instance_name
  database_version = "POSTGRES_14"
  region           = var.region
  deletion_protection = false

  settings {
    tier = var.db_tier
    ip_configuration {
      authorized_networks {
        value = "0.0.0.0/0"
      }
    }
  }
}
resource "google_sql_user" "airflow" {
  name     = var.db_user
  password = var.db_password
  instance = google_sql_database_instance.airflow.name

  lifecycle {
    prevent_destroy = true
  }
}
