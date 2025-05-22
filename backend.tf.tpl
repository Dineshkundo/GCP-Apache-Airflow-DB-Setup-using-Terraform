terraform {
  backend "gcs" {
    bucket = "__BACKEND_BUCKET__"
    prefix = "airflow-gcp/state"
  }
}
