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

# Clone repo if missing
if [ ! -d "$REPO_NAME" ]; then
  echo "📥 Cloning repository..."
  git clone https://github.com/Dineshkundo/$REPO_NAME.git
fi
cd $REPO_NAME

# Validate bucket name
if [[ -z "$BACKEND_BUCKET" ]]; then
  echo "❌ Error: BACKEND_BUCKET is empty. Exiting..."
  exit 1
fi

# Check & create backend bucket BEFORE terraform init
if ! gsutil ls -b "gs://$BACKEND_BUCKET" &> /dev/null; then
  echo "📦 Creating backend GCS bucket: $BACKEND_BUCKET"
  gcloud storage buckets create "gs://$BACKEND_BUCKET" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --uniform-bucket-level-access
  echo "⏳ Waiting for bucket to become ready..."
  while ! gsutil ls -b "gs://$BACKEND_BUCKET" &> /dev/null; do
    sleep 2
  done
  echo "✅ Backend bucket is now ready."
else
  echo "✅ Backend bucket $BACKEND_BUCKET already exists"
fi

# Generate backend.tf for Terraform backend config
echo "🛠 Generating backend.tf from template..."
sed "s/__BACKEND_BUCKET__/$BACKEND_BUCKET/" backend.tf.tpl > backend.tf

echo "📄 backend.tf content:"
cat backend.tf

# Initialize Terraform with backend (now safe because bucket exists)
echo "🚧 Initializing Terraform with backend..."
terraform init -reconfigure

# Create terraform.tfvars
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

# Add ignore files
echo -e ".terraform/\nterraform.tfvars" > .gitignore

# Apply Terraform config
echo "🚀 Applying Terraform configuration..."
terraform apply -auto-approve
