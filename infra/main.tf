terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "5683435d-2428-439a-b725-47a58f20022f"
}

# Use the existing resource group
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Use the existing container registry
data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
}

# Log Analytics workspace (required by Container App Environment for logs)
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.app_name}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Container App Environment (the hosting platform)
resource "azurerm_container_app_environment" "env" {
  name                       = "${var.app_name}-env"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

# Container App (your running application)
resource "azurerm_container_app" "app" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  registry {
    server               = data.azurerm_container_registry.acr.login_server
    username             = data.azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = data.azurerm_container_registry.acr.admin_password
  }

  template {
    container {
      name   = var.app_name
      image  = "${data.azurerm_container_registry.acr.login_server}/${var.image_name}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env { name = "APP_NAME" value = var.app_display_name }
      env { name = "INTERN_NAME" value = var.intern_name }
      env { name = "CLOUD_PLATFORM" value = var.cloud_platform }
      env { name = "ENVIRONMENT" value = var.environment }
      env { name = "APP_VERSION" value = var.image_tag }
      env { name = "APP_STATUS" value = var.app_status }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
