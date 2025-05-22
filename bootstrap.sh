#!/bin/bash
set -e

# Clone the repo
git clone https://github.com/Dineshkundo/GCP-Apache-Airflow-DB-Setup-using-Terraform.git
cd GCP-Apache-Airflow-DB-Setup-using-Terraform

# Run Terraform
terraform init
terraform apply -auto-approve
