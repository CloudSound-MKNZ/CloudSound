# Outputs for CloudSound Azure Infrastructure

# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# AKS
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_node_resource_group" {
  description = "Resource group containing AKS nodes"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

# Azure Container Registry
output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Login server URL for ACR"
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "Admin username for ACR"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for ACR"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

# PostgreSQL
output "postgres_server_name" {
  description = "Name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgres_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgres_admin_user" {
  description = "Administrator username for PostgreSQL"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "postgres_password" {
  description = "Administrator password for PostgreSQL"
  value       = var.postgres_admin_password != null ? var.postgres_admin_password : random_password.postgres_password[0].result
  sensitive   = true
}

output "postgres_database_name" {
  description = "Name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}:${var.postgres_admin_password != null ? var.postgres_admin_password : random_password.postgres_password[0].result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.main.name}"
  sensitive   = true
}

# Storage Account
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_key" {
  description = "Primary access key for storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "storage_connection_string" {
  description = "Connection string for storage account"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "storage_blob_endpoint" {
  description = "Blob endpoint for storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

# Event Hubs (Kafka-compatible)
output "eventhubs_namespace_name" {
  description = "Name of the Event Hubs namespace"
  value       = azurerm_eventhub_namespace.main.name
}

output "eventhubs_namespace_fqdn" {
  description = "FQDN of the Event Hubs namespace"
  value       = "${azurerm_eventhub_namespace.main.name}.servicebus.windows.net"
}

output "eventhubs_kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers for Event Hubs"
  value       = "${azurerm_eventhub_namespace.main.name}.servicebus.windows.net:9093"
}

output "eventhubs_connection_string" {
  description = "Event Hubs connection string for Kafka access"
  value       = azurerm_eventhub_namespace_authorization_rule.kafka_access.primary_connection_string
  sensitive   = true
}

output "eventhubs_connection_string_alias" {
  description = "Event Hubs connection string alias"
  value       = azurerm_eventhub_namespace_authorization_rule.kafka_access.primary_connection_string_alias
  sensitive   = true
}

# Application Insights
output "app_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# Log Analytics
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

# Networking
output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

# Quick Setup Commands
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-all"
}

output "acr_login_command" {
  description = "Command to login to ACR"
  value       = "az acr login --name ${azurerm_container_registry.main.name}"
}

output "deployment_info" {
  description = "Important deployment information"
  value = <<-EOT
    
    ===================================================================
    CloudSound Azure Deployment - Important Information
    ===================================================================
    
    Resource Group: ${azurerm_resource_group.main.name}
    Location: ${azurerm_resource_group.main.location}
    
    --- AKS Cluster ---
    Cluster Name: ${azurerm_kubernetes_cluster.main.name}
    Configure kubectl:
      az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}
    
    --- Container Registry ---
    ACR Name: ${azurerm_container_registry.main.name}
    Login Server: ${azurerm_container_registry.main.login_server}
    Login Command:
      az acr login --name ${azurerm_container_registry.main.name}
    
    --- PostgreSQL Database ---
    Server: ${azurerm_postgresql_flexible_server.main.fqdn}
    Database: ${azurerm_postgresql_flexible_server_database.main.name}
    Username: ${azurerm_postgresql_flexible_server.main.administrator_login}
    (Password stored in Terraform state - retrieve with: terraform output postgres_password)
    
    --- Storage Account ---
    Account Name: ${azurerm_storage_account.main.name}
    Blob Endpoint: ${azurerm_storage_account.main.primary_blob_endpoint}
    
    --- Monitoring ---
    Log Analytics: ${azurerm_log_analytics_workspace.main.name}
    App Insights: ${azurerm_application_insights.main.name}
    
    ===================================================================
    Next Steps:
    1. Configure kubectl: ${format("az aks get-credentials --resource-group %s --name %s", azurerm_resource_group.main.name, azurerm_kubernetes_cluster.main.name)}
    2. Login to ACR: az acr login --name ${azurerm_container_registry.main.name}
    3. Build and push Docker images
    4. Deploy using Helm
    ===================================================================
  EOT
}

# Generate random password if not provided
resource "random_password" "postgres_password" {
  count   = var.postgres_admin_password == null ? 1 : 0
  length  = 32
  special = true
}

