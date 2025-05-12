output "connection_name" {
  value = google_sql_database_instance.airflow.connection_name
}
output "db_username_secret_id" {
  value = google_secret_manager_secret.db_user.secret_id
}

output "db_password_secret_id" {
  value = google_secret_manager_secret.db_password.secret_id
}

