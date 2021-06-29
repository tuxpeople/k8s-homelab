terraform {
  backend "azurerm" {
    resource_group_name  = "tstate-rg"
    storage_account_name = "tfstate11747"
    container_name       = "tfstate"
    key                  = "aks-test.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "azurerm"
      version = "~>2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x.
  # If you're using version 1.x, the "features" block is not allowed.
  features {}
}