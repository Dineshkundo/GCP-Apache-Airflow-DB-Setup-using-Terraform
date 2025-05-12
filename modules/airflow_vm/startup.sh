#!/bin/bash

set -euo pipefail

echo "Starting Airflow startup script..."

# Wait for network connectivity
echo "Waiting for network..."
until ping -c 1 google.com &> /dev/null; do
  sleep 2
done
echo "Network connected."

# Install prerequisites
sudo apt-get clean
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

# Install Docker CE
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Google Cloud SDK
echo "Installing Google Cloud SDK..."
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
sudo apt-get update -y
sudo apt-get install -y google-cloud-sdk

# Fetch metadata attributes
echo "Fetching metadata attributes..."
METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
SA_NAME=$(curl -s -H "Metadata-Flavor: Google" ${METADATA_URL}/sa-name)
CLOUDSQL_CONN_NAME=$(curl -s -H "Metadata-Flavor: Google" ${METADATA_URL}/cloudsql-connection-name)
GCS_BUCKET=$(curl -s -H "Metadata-Flavor: Google" ${METADATA_URL}/gcs-bucket)
DB_USERNAME_SECRET_ID=$(curl -s -H "Metadata-Flavor: Google" ${METADATA_URL}/db_username_secret_id)
DB_PASSWORD_SECRET_ID=$(curl -s -H "Metadata-Flavor: Google" ${METADATA_URL}/db_password_secret_id)

export SA_KEY_SECRET_ID=$(curl -s -H "Metadata-Flavor: Google" ${METADATA_URL}/sa_key_secret_id)
echo "Resolved SA_KEY_SECRET_ID=$SA_KEY_SECRET_ID"

PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)
echo "Project ID: $PROJECT_ID"

# Set gcloud project
gcloud config set project "$PROJECT_ID"

# Obtain DB credentials from Secret Manager
echo "Fetching DB credentials from Secret Manager..."
DB_USERNAME=$(gcloud secrets versions access latest --secret="$DB_USERNAME_SECRET_ID")
DB_PASSWORD=$(gcloud secrets versions access latest --secret="$DB_PASSWORD_SECRET_ID")
DB_NAME="postgres"
# Create necessary directories
echo "Creating Airflow directories..."
mkdir -p /opt/airflow/logs /opt/airflow/dags /opt/airflow/secrets
chown -R 50000:50000 /opt/airflow

# Fetch service account key
echo "Fetching service account key..."
gcloud secrets versions access latest --secret="$SA_KEY_SECRET_ID"  > /opt/airflow/secrets/sa-key.json
chown 50000:50000 /opt/airflow/secrets/sa-key.json

# Logrotate config for all Airflow logs
cat <<EOF | sudo tee /etc/logrotate.d/airflow-logs
/opt/airflow/logs/*.log
/opt/airflow/logs/**/*.log {
    daily
    rotate 7
    size 20M
    missingok
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

# Ensure GCS prefixes exist (so gsutil rsync has something to sync)
echo "Bootstrapping GCS bucket prefixes..."

# Create an empty placeholder in dags/ and logs/
cat <<EOF > /tmp/placeholder.txt
# placeholder
EOF

gsutil -q cp /tmp/placeholder.txt gs://${GCS_BUCKET}/dags/placeholder.txt \
  || echo "Failed to create dags/ prefix (bucket may not exist yet)"
gsutil -q cp /tmp/placeholder.txt gs://${GCS_BUCKET}/logs/placeholder.txt \
  || echo "Failed to create logs/ prefix"

rm /tmp/placeholder.txt


# Sync DAGs from GCS bucket to local directory
echo "Syncing DAGs from GCS bucket..."
gsutil -m rsync -r gs://${GCS_BUCKET}/dags/ /opt/airflow/dags

# Write docker-compose.yaml
echo "Creating docker-compose.yaml..."
cat > /opt/airflow/docker-compose.yaml <<EOF
version: '3.8'
services:
  cloud-sql-proxy:
    image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.15.2
    command:
      - "${CLOUDSQL_CONN_NAME}"
      - --credentials-file=/opt/airflow/secrets/sa-key.json
      - --address=0.0.0.0
      - --port=5432
    volumes:
      - /opt/airflow/secrets/sa-key.json:/opt/airflow/secrets/sa-key.json:ro
    expose:
      - 5432

  airflow-init:
    image: apache/airflow:2.6.3
    depends_on:
      - cloud-sql-proxy
    entrypoint: >
      bash -c "
        airflow db init &&
        airflow users create --username admin --password admin --firstname Airflow --lastname Admin --role Admin --email admin@example.com
      "
    environment:
      - AIRFLOW__CORE__EXECUTOR=LocalExecutor
      - AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${DB_USERNAME}:${DB_PASSWORD}@cloud-sql-proxy:5432/${DB_NAME}
    volumes:
      - /opt/airflow/dags:/opt/airflow/dags
      - /opt/airflow/logs:/opt/airflow/logs
      - /opt/airflow/secrets/sa-key.json:/opt/airflow/secrets/sa-key.json:ro

  dag-sync:
    image: google/cloud-sdk:latest
    volumes:
      - /opt/airflow/dags:/opt/airflow/dags
      - /opt/airflow/secrets/sa-key.json:/sa-key.json:ro
      - /opt/airflow/logs:/opt/airflow/logs
    entrypoint: >
      bash -c "
        gcloud auth activate-service-account --key-file=/sa-key.json &&
        while true; do
          echo '--- [$(date)] Starting DAG sync ---' >> /opt/airflow/logs/dag-sync.log;
          gsutil -m rsync -r gs://${GCS_BUCKET}/dags/ /opt/airflow/dags >> /opt/airflow/logs/dag-sync.log 2>&1;
          echo '--- [$(date)] DAG sync completed ---' >> /opt/airflow/logs/dag-sync.log;


          echo '--- [$(date)] Starting LOG sync ---' >> /opt/airflow/logs/dag-sync.log;
          gsutil -m rsync -r /opt/airflow/logs gs://${GCS_BUCKET}/logs >> /opt/airflow/logs/dag-sync.log 2>&1;
          echo '--- [$(date)] LOG sync completed ---' >> /opt/airflow/logs/dag-sync.log;

          sleep 60;
        done
      "

  webserver:
    image: apache/airflow:2.6.3
    command: webserver
    depends_on:
      - cloud-sql-proxy
      - airflow-init
    environment:
      - AIRFLOW__CORE__EXECUTOR=LocalExecutor
      - AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${DB_USERNAME}:${DB_PASSWORD}@cloud-sql-proxy:5432/${DB_NAME}
    ports:
      - 8080:8080
    volumes:
      - /opt/airflow/dags:/opt/airflow/dags
      - /opt/airflow/logs:/opt/airflow/logs
      - /opt/airflow/secrets/sa-key.json:/opt/airflow/secrets/sa-key.json:ro

  scheduler:
    image: apache/airflow:2.6.3
    command: scheduler
    depends_on:
      - cloud-sql-proxy
      - airflow-init
    environment:
      - AIRFLOW__CORE__EXECUTOR=LocalExecutor
      - AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${DB_USERNAME}:${DB_PASSWORD}@cloud-sql-proxy:5432/${DB_NAME}
    volumes:
      - /opt/airflow/dags:/opt/airflow/dags
      - /opt/airflow/logs:/opt/airflow/logs
      - /opt/airflow/secrets/sa-key.json:/opt/airflow/secrets/sa-key.json:ro

EOF


# Start Airflow services

cd /opt/airflow
echo "Starting Airflow services (first attempt)..."
docker compose up -d

# Wait 60 seconds
echo "Sleeping for 60 seconds before retrying docker compose up..."
sleep 60

# Second attempt to ensure everything is up
echo "Retrying docker compose up..."
docker compose up -d

# Wait for webserver
echo "Waiting for Airflow Webserver to be ready..."
until curl --silent --output /dev/null --head --fail http://localhost:8080/health; do
  sleep 5
done

echo "Airflow is up and running."
echo "Airflow setup completed."

# --- Create systemd service for Airflow ---

echo "[INFO] Creating systemd service for Airflow..."

cat <<EOF > /etc/systemd/system/airflow.service
[Unit]
Description=Airflow Docker Compose Service
Requires=docker.service
After=docker.service network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/airflow
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable airflow.service
systemctl start airflow.service

echo "[INFO] systemd airflow.service enabled and started."
