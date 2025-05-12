variable "vm_name" {}
variable "machine_type" {}
variable "zone" {}
variable "vm_image" {}
variable "subnet" {}
variable "service_account_email" {}
variable "sql_connection_name"  { type = string }
variable "sa_name" {
  description = "The Service Account name used for fetching secrets"
  type        = string
}
variable "bucket_name"{}
variable "db_username_secret_id" {
  description = "Secret Manager secret ID for the database username"
  type        = string
}

variable "db_password_secret_id" {
  description = "Secret Manager secret ID for the database password"
  type        = string
}
variable "sa_key_secret_id" {
  description = "Secret Manager secret ID for the service account key"
  type        = string
}
variable "vm_disk_size_gb" {
  description = "Boot disk size for the Airflow VM, in GB"
  type        = number
}

