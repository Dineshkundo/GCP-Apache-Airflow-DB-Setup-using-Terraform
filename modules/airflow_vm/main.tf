resource "google_compute_instance" "airflow_vm" {
  name                = var.vm_name
  machine_type        = var.machine_type
  zone                = var.zone
  deletion_protection = false

  boot_disk {
    initialize_params {
      image        = var.vm_image
      size          = var.vm_disk_size_gb   
    }
  }

  network_interface {
    subnetwork    = var.subnet
    access_config {}  // assign an ephemeral external IP
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script            = file("${path.module}/startup.sh")
    cloudsql-connection-name  = var.sql_connection_name
    sa-name                   = var.sa_name
    gcs-bucket                = var.bucket_name
    db_username_secret_id     = var.db_username_secret_id
    db_password_secret_id     = var.db_password_secret_id
    sa_key_secret_id          = var.sa_key_secret_id
  }
}

