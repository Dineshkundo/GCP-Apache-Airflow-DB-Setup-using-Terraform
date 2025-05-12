resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.vpc_name}-allow-ssh"
  network = var.vpc_self_link

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_airflow_web" {
  name    = "${var.vpc_name}-allow-airflow-web"
  network = var.vpc_self_link

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  network = var.vpc_self_link

  allow {
    protocol = "all"
  }

  source_ranges = ["10.10.0.0/16"]  # matches your VPC CIDR
  direction     = "INGRESS"
}
