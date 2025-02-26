# providers.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.20.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  subscription_id                 = var.sub
  resource_provider_registrations = "none"
  features {}
}
