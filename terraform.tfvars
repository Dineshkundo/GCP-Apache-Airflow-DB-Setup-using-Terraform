project_id  = "total-apparatus-460306-v7"  #Modify your project name please
region      = "us-central1"
vpc_name    = "airflow-vpct"
subnet_name = "airflow-subnett"
cidr_block  = "10.10.0.0/16"

sa_name = "airflow-saa"
roles = [
  "roles/compute.instanceAdmin.v1",
  "roles/iam.serviceAccountUser",
  "roles/storage.objectAdmin",
  "roles/storage.admin",
  "roles/cloudsql.client",
  "roles/logging.logWriter",
  "roles/monitoring.metricWriter",
  "roles/secretmanager.secretAccessor",
]

db_instance_name = "airflow"
db_tier          = "db-f1-micro"

bucket_name = "airflow-dags-logs-bucket79"
location    = "US"

vm_name      = "airflow-prod-vm"
machine_type = "e2-medium"
zone         = "us-central1-a"
vm_image     = "ubuntu-os-cloud/ubuntu-2204-lts"
