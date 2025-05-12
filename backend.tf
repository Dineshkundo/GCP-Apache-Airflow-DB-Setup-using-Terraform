terraform {
  backend "gcs" {
    bucket = "airflow-terraform"
    prefix = "airflow-gcp/state"
  }
}
