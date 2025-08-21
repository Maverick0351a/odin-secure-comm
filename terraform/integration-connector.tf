# Terraform configuration for ODIN Protocol Integration Connector
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "us-central1"
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
  default     = "odin-gateway"
}

variable "connector_name" {
  description = "Name of the Integration Connector"
  type        = string
  default     = "odin-protocol"
}

variable "connection_name" {
  description = "Name of the Integration Connection"
  type        = string
  default     = "odin-ai-communication"
}

# Data sources
data "google_project" "current" {
  project_id = var.project_id
}

data "google_cloud_run_service" "odin_gateway" {
  name     = var.cloud_run_service_name
  location = var.region
  project  = var.project_id
}

# Service account for the connector
resource "google_service_account" "odin_connector_invoker" {
  account_id   = "odin-connector-invoker"
  display_name = "ODIN Connector Invoker Service Account"
  description  = "Service account for ODIN Protocol Integration Connector to invoke Cloud Run"
  project      = var.project_id
}

# Grant Cloud Run invoker permission to service account
resource "google_cloud_run_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  service  = data.google_cloud_run_service.odin_gateway.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.odin_connector_invoker.email}"
}

# Create custom connector (requires google-beta provider)
resource "google_integration_connectors_custom_connector" "odin_connector" {
  provider = google-beta
  
  name        = var.connector_name
  location    = var.region
  project     = var.project_id
  
  display_name = "ODIN Protocol - AI-to-AI Secure Communication"
  description  = "Secure communication protocol for AI agents with Ed25519 signatures and immutable audit trails"
  
  # OpenAPI specification - in production, this would reference your OpenAPI file
  spec {
    spec_type = "OPEN_API"
    spec_path = "openapi/odin-connector.yaml"
  }
  
  labels = {
    environment = "production"
    protocol    = "odin"
    version     = "v1"
  }
}

# Create connection using the custom connector
resource "google_integration_connectors_connection" "odin_connection" {
  provider = google-beta
  
  name        = var.connection_name
  location    = var.region
  project     = var.project_id
  
  description = "ODIN Protocol connection for AI-to-AI secure communication"
  
  connector_version = "${google_integration_connectors_custom_connector.odin_connector.name}/versions/1"
  
  config_variables {
    key {
      key = "ODIN_BASE_URL"
    }
    string_value = data.google_cloud_run_service.odin_gateway.status[0].url
  }
  
  # Authentication configuration
  auth_config {
    auth_type = "OAUTH2_CLIENT_CREDENTIALS"
    
    oauth2_client_credentials {
      client_id = google_service_account.odin_connector_invoker.email
      # Client secret will be the service account key (managed by Google)
    }
    
    # Additional auth parameters for ID token
    additional_variables {
      key {
        key = "audience"
      }
      string_value = data.google_cloud_run_service.odin_gateway.status[0].url
    }
    
    additional_variables {
      key {
        key = "token_endpoint"
      }
      string_value = "https://oauth2.googleapis.com/token"
    }
  }
  
  # Service account for the connection
  service_account = google_service_account.odin_connector_invoker.email
  
  # Logging configuration
  log_config {
    enabled = true
  }
  
  labels = {
    environment = "production"
    protocol    = "odin"
    service     = "ai-communication"
  }
  
  depends_on = [
    google_integration_connectors_custom_connector.odin_connector,
    google_cloud_run_service_iam_member.invoker
  ]
}

# Outputs
output "connector_name" {
  description = "Name of the created custom connector"
  value       = google_integration_connectors_custom_connector.odin_connector.name
}

output "connection_name" {
  description = "Name of the created connection"
  value       = google_integration_connectors_connection.odin_connection.name
}

output "service_account_email" {
  description = "Email of the service account used for the connector"
  value       = google_service_account.odin_connector_invoker.email
}

output "cloud_run_url" {
  description = "URL of the Cloud Run service"
  value       = data.google_cloud_run_service.odin_gateway.status[0].url
}

output "connection_status" {
  description = "Status of the integration connection"
  value       = google_integration_connectors_connection.odin_connection.connection_revision
}
