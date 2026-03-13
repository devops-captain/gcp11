terraform {
  required_version = ">= 1.0"
  
  backend "gcs" {
    # Bucket and prefix configured via init
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project Name"
  type        = string
}

variable "project_alias" {
  description = "Project Alias"
  type        = string
}

variable "billing_account" {
  description = "Billing Account ID"
  type        = string
}

variable "services" {
  description = "List of APIs to enable"
  type        = list(string)
  default     = ["compute.googleapis.com"]
}

variable "environment" {
  description = "Environment (lab/dev/prod)"
  type        = string
  default     = "lab"
}

variable "budget" {
  description = "Monthly budget in USD"
  type        = number
  default     = 1000
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# Enable APIs
resource "google_project_service" "apis" {
  for_each = toset(var.services)
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

# Create default VPC if compute API is enabled
resource "google_compute_network" "default" {
  count = contains(var.services, "compute.googleapis.com") ? 1 : 0
  
  name                    = "${var.project_alias}-vpc"
  auto_create_subnetworks = true
  
  depends_on = [google_project_service.apis]
}

# Create firewall rules for default VPC
resource "google_compute_firewall" "allow_ssh" {
  count = contains(var.services, "compute.googleapis.com") ? 1 : 0
  
  name    = "${var.project_alias}-allow-ssh"
  network = google_compute_network.default[0].name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

# Create storage bucket if storage API is enabled
resource "google_storage_bucket" "project_bucket" {
  count = contains(var.services, "storage.googleapis.com") ? 1 : 0
  
  name     = "${var.project_id}-${var.project_alias}-storage"
  location = "US"
  
  depends_on = [google_project_service.apis]
}

# Output important information
output "project_id" {
  value = var.project_id
}

output "project_name" {
  value = var.project_name
}

output "vpc_name" {
  value = contains(var.services, "compute.googleapis.com") ? google_compute_network.default[0].name : null
}

output "bucket_name" {
  value = contains(var.services, "storage.googleapis.com") ? google_storage_bucket.project_bucket[0].name : null
}
