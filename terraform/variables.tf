variable "project_id" {
  description = "GCP project ID"
  default     = "vm-autoscale-project"
}

variable "region" {
  description = "GCP region"
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "GCE machine type"
  default     = "e2-medium"
}
