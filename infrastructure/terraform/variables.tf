# Variables for CloudSound Azure Infrastructure

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "cloudsound-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "cloudsound"
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "production"
}

# AKS Variables
variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28.3"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS cluster"
  type        = number
  default     = 2
}

variable "aks_node_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s"  # Cost-effective for student credits
}

variable "aks_enable_autoscaling" {
  description = "Enable autoscaling for AKS node pool"
  type        = bool
  default     = false
}

variable "aks_min_count" {
  description = "Minimum node count for autoscaling"
  type        = number
  default     = 2
}

variable "aks_max_count" {
  description = "Maximum node count for autoscaling"
  type        = number
  default     = 5
}

# PostgreSQL Variables
variable "postgres_admin_user" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "cloudsoundadmin"
}

variable "postgres_admin_password" {
  description = "Administrator password for PostgreSQL"
  type        = string
  sensitive   = true
  default     = null  # Will be generated if not provided
}

variable "postgres_sku_name" {
  description = "SKU name for PostgreSQL (B_Standard_B1ms for cost-effective)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Storage capacity in MB for PostgreSQL"
  type        = number
  default     = 32768  # 32GB
}

variable "postgres_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "cloudsound"
}

# Storage Variables
variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

# Monitoring Variables
variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

# Optional Features
variable "enable_app_gateway" {
  description = "Enable Application Gateway for advanced routing"
  type        = bool
  default     = false
}

variable "admin_email" {
  description = "Admin email for SSL certificates and notifications"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

