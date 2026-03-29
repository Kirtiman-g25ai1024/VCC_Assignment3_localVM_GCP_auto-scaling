terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "autoscale_vm" {
  name         = "autoscale-cloud-vm"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {} # Assigns external IP
  }

  metadata_startup_script = file("startup.sh")

  tags = ["http-server", "https-server", "autoscaled"]

  labels = {
    environment = "autoscale"
    managed_by  = "terraform"
  }
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-autoscale"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "5000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}
