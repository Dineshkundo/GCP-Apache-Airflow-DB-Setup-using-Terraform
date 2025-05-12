resource "google_storage_bucket" "airflow" {
  name          = var.bucket_name
  location      = var.location
  force_destroy = true
}
