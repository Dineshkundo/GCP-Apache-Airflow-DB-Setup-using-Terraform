variable "db_instance_name" {
  type = string
}
variable "region" {
  type = string
}
variable "db_tier" {
  type = string
}
variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "airflow_sa_email" {
  description = "Airflow service account email for granting access"
  type        = string
}
variable "db_username_secret_id" {
  description = "Secret ID for the database username"
  type        = string
}

variable "db_password_secret_id" {
  description = "Secret ID for the database password"
  type        = string
}

