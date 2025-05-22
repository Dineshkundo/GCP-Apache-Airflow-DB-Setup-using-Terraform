#!/bin/bash
set -e

echo "🌀 Starting Apache Airflow GCP Terraform Setup..."

# Prompt user for input
read -p "Enter your GCP Project ID: " PROJECT_ID
read -p "Enter your GCP Region (e.g., us-central1): " REGION
read -p "Enter your GCP Zone (e.g., us-central1-a): " ZONE
read -p "Enter a name for the Terraform GCS backend bucket (e.g., airflow-tf-state-123): " BACKEND_BUCKET
read -p "Enter a name for the DAGs/logs bucket (e.g., airflow-dags-logs-123): " DAG_BUCKET

REPO_NAME="GCP-Apache-Airflow-DB-Setup-using-Terraform"

# Clone the repo
echo "📥 Cloning repository..."
git clone https://github.com/Dineshkundo/$REPO_NAME.git
cd $REPO_NAME

# Generate backend.tf from template inside repo
echo "🛠 Generating backend.tf from template..."
sed "s/__BACKEND_BUCKET__/$BACKEND_BUCKET/" backend.tf.tpl > backend.tf

# Temporarily move backend.tf to allow local init
mv backend.tf backend.tf.bak

# Initialize Terraform locally
echo "🚧 Running terraform init with local backend..."
terraform init

# Create GCS backend bucket if needed
if ! gsutil ls -b gs://$BACKEND_BUCKET &> /dev/null; then
  echo "📦 Creating GCS backend bucket: $BACKEND_BUCKET"
  gsutil mb -p "$PROJECT_ID" -l "$REGION" gs://$BACKEND_BUCKET
else
  echo "✅ Backend bucket $BACKEND_BUCKET already exists"
fi

# Restore backend.tf
mv backend.tf.bak backend.tf

# Reconfigure backend with GCS
echo "🔁 Reconfiguring Terraform backend..."
terraform init -reconfigure

# Generate terraform.tfvars dynamically
echo "📝 Creating terraform.tfvars..."
cat > terraform.tfvars <<EOF
project_id  = "$PROJECT_ID"
region      = "$REGION"
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

bucket_name = "$DAG_BUCKET"
location    = "US"

vm_name      = "airflow-prod-vm"
machine_type = "e2-medium"
zone         = "$ZONE"
vm_image     = "ubuntu-os-cloud/ubuntu-2204-lts"
EOF

# Apply Terraform
echo "🚀 Applying Terraform configuration..."
terraform apply -auto-approve
