variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "cidr_block" {
  description = "CIDR for subnet"
  type        = string
}

variable "sa_name" {
  description = "Service account ID (used as sa_name in module)"
  type        = string
}

variable "roles" {
  description = "IAM roles to bind to the SA"
  type        = list(string)
}

variable "db_instance_name" {
  description = "Cloud SQL instance name"
  type        = string
}

variable "db_tier" {
  description = "Cloud SQL tier"
  type        = string
}


variable "bucket_name" {
  description = "GCS bucket name for DAGs & logs"
  type        = string
}

variable "location" {
  description = "GCS bucket location"
  type        = string
}

variable "vm_name" {
  description = "Compute instance name"
  type        = string
}

variable "machine_type" {
  description = "Compute instance machine type"
  type        = string
}

variable "zone" {
  description = "Compute instance zone"
  type        = string
}

variable "vm_image" {
  description = "Compute instance boot image"
  type        = string
}

variable "db_password_secret_id" {
  description = "Secret Manager Secret ID for Database Password"
  type        = string
}

variable "db_username_secret_id" {
  description = "Secret Manager Secret ID for Database Username"
  type        = string
}
variable "db_password" {
  description = "Cloud SQL password"
  type        = string
  sensitive   = true
}
variable "db_user" {
  description = "Database username"
  type        = string
}
variable "vm_disk_size_gb" {
  description = "Boot disk size for the Airflow VM, in GB"
  type        = number
}

