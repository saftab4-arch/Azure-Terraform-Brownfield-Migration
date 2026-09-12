terraform {
  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "1-ab3ea420-playground-sandbox"
    storage_account_name = "tfstatebrownfield2026"
    container_name       = "tfstate"
    key                  = "brownfield-migration/terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.80.0"
    }
  }
}
