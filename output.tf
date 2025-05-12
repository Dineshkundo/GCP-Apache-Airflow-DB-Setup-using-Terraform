output "airflow_vm_ip" {
  description = "Public IP of the Airflow VM"
  value       = module.airflow_vm.vm_ip
}

output "cloudsql_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = module.sql_instance.connection_name
}

output "bucket_name" {
  description = "GCS bucket name"
  value       = module.gcs_bucket.bucket_name
}

output "sa_email" {
  description = "Service Account email"
  value       = module.service_account.email
}

output "sa_key_secret_id" {
  description = "Secret Manager secret holding SA key"
  value       = module.service_account.sa_key_secret_id
}

output "db_password_secret_id" {
  description = "Secret Manager secret holding DB password"
  value       = module.sql_instance.db_password_secret_id
}

