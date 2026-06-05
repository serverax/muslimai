terraform {
  backend "azurerm" {
    resource_group_name  = "rg-sakina-mobile-staging-uksouth"
    storage_account_name = "stsakinamobilestg"
    container_name       = "tfstate"
    key                  = "sakina-mobile-staging.terraform.tfstate"
  }
}
