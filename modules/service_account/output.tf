output "email" {
  value = google_service_account.sa.email
}

output "sa_key_secret_id" {
  value = google_secret_manager_secret.sa_key_secret.secret_id
}

