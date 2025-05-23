#!/bin/bash
set -euo pipefail

echo "🌀 Starting Apache Airflow GCP Terraform Setup..."

# Get inputs interactively
read -p "Enter your GCP Project ID: " PROJECT_ID < /dev/tty
read -p "Enter your GCP Region (e.g., us-central1): " REGION < /dev/tty
read -p "Enter your GCP Zone (e.g., us-central1-a): " ZONE < /dev/tty
read -p "Enter a name for the Terraform GCS backend bucket (e.g., airflow-tf-state-123): " BACKEND_BUCKET < /dev/tty
read -p "Enter a name for the DAGs/logs bucket (e.g., airflow-dags-logs-123): " DAG_BUCKET < /dev/tty
read -p "Enter the DB username: " DB_USER < /dev/tty
read -s -p "Enter the DB password: " DB_PASS < /dev/tty
echo
read -p "Enter the disk size for the Airflow VM (e.g., 30): " VM_DISK_SIZE_GB < /dev/tty

# Secret IDs
DB_USERNAME_SECRET_ID="airflow-db-username-secret"
DB_PASSWORD_SECRET_ID="airflow-db-password-secret"

REPO_NAME="GCP-Apache-Airflow-DB-Setup-using-Terraform"

# Clone repo if not present
if [ ! -d "$REPO_NAME" ]; then
  echo "📥 Cloning repository..."
  git clone https://github.com/Dineshkundo/$REPO_NAME.git
  chmod +x $REPO_NAME/bootstrap.sh
fi
cd $REPO_NAME

# Validate bucket name
if [[ -z "$BACKEND_BUCKET" ]]; then
  echo "❌ Error: BACKEND_BUCKET is empty. Exiting..."
  exit 1
fi

# Create backend bucket
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

# Generate backend.tf
echo "🛠 Generating backend.tf from template..."
sed "s/__BACKEND_BUCKET__/$BACKEND_BUCKET/" backend.tf.tpl > backend.tf
echo "📄 backend.tf content:"
cat backend.tf

# Initialize Terraform
echo "🚧 Initializing Terraform with backend..."
terraform init -reconfigure

# Create secrets
echo "🔐 Creating secrets..."
gcloud secrets create "$DB_USERNAME_SECRET_ID" \
  --data-file=<(echo -n "$DB_USER") \
  --replication-policy="automatic" || echo "ℹ️ Secret $DB_USERNAME_SECRET_ID may already exist."

gcloud secrets create "$DB_PASSWORD_SECRET_ID" \
  --data-file=<(echo -n "$DB_PASS") \
  --replication-policy="automatic" || echo "ℹ️ Secret $DB_PASSWORD_SECRET_ID may already exist."

# Grant access to service account
echo "🔐 Granting secret access to airflow-saa@$PROJECT_ID..."
gcloud secrets add-iam-policy-binding "$DB_USERNAME_SECRET_ID" \
  --member="serviceAccount:airflow-saa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" || true

gcloud secrets add-iam-policy-binding "$DB_PASSWORD_SECRET_ID" \
  --member="serviceAccount:airflow-saa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" || true

# Create terraform.tfvars
echo "📝 Writing terraform.tfvars..."
cat > terraform.tfvars <<EOF
project_id  = "$PROJECT_ID"
region      = "$REGION"
zone        = "$ZONE"

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

db_instance_name        = "airflow"
db_tier                 = "db-f1-micro"
bucket_name             = "$DAG_BUCKET"
location                = "US"

vm_name                 = "airflow-prod-vm"
machine_type            = "e2-medium"
vm_image                = "ubuntu-os-cloud/ubuntu-2204-lts"
vm_disk_size_gb         = "$VM_DISK_SIZE_GB"

# 👇 Actual DB creds are fetched from these secrets at runtime by the VM
db_user                 = ""
db_password             = ""
db_username_secret_id   = "$DB_USERNAME_SECRET_ID"
db_password_secret_id   = "$DB_PASSWORD_SECRET_ID"
EOF

# .gitignore
echo -e ".terraform/\nterraform.tfvars" > .gitignore

# Apply Terraform
echo "🚀 Applying Terraform configuration..."
terraform apply -auto-approve
