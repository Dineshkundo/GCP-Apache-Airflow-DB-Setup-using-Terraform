variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "sa_name" {
  description = "Service Account Name"
  type        = string
}

variable "roles" {
  description = "List of IAM roles for the service account"
  type        = list(string)
}
