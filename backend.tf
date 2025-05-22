terraform {
  backend "gcs" {
    bucket = "airflow-terraform-bkt"
    prefix = "airflow-gcp/state"
  }
}
