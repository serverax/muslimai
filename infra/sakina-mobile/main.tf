resource "azurerm_resource_group" "sakina_mobile" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    workload = "sakina-mobile"
    env      = "staging"
    managed  = "terraform"
  }
}

resource "azurerm_container_registry" "sakina_mobile" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.sakina_mobile.name
  location            = azurerm_resource_group.sakina_mobile.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_kubernetes_cluster" "sakina_mobile" {
  name                = var.aks_name
  resource_group_name = azurerm_resource_group.sakina_mobile.name
  location            = azurerm_resource_group.sakina_mobile.location
  dns_prefix          = "sakina-mobile-staging"

  default_node_pool {
    name       = "system"
    node_count = 3
    vm_size    = "Standard_D4s_v5"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.aks_api_authorized_ip_ranges
  }

  role_based_access_control_enabled = true

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = {
    workload = "sakina-mobile"
    env      = "staging"
    managed  = "terraform"
  }
}

resource "azurerm_postgresql_flexible_server" "sakina_mobile" {
  name                   = var.postgres_name
  resource_group_name    = azurerm_resource_group.sakina_mobile.name
  location               = azurerm_resource_group.sakina_mobile.location
  version                = "16"
  administrator_login    = "sakinaadmin"
  administrator_password = var.postgres_admin_password
  sku_name               = "B_Standard_B2s"
  storage_mb             = 32768

  lifecycle {
    ignore_changes = [administrator_password]
  }
}

resource "azurerm_redis_cache" "sakina_mobile" {
  name                = var.redis_name
  location            = azurerm_resource_group.sakina_mobile.location
  resource_group_name = azurerm_resource_group.sakina_mobile.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
  minimum_tls_version = "1.2"
}

resource "azurerm_storage_account" "sakina_mobile" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.sakina_mobile.name
  location                 = azurerm_resource_group.sakina_mobile.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = var.allowed_network_ip_rules
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
}

resource "azurerm_key_vault" "sakina_mobile" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.sakina_mobile.location
  resource_group_name = azurerm_resource_group.sakina_mobile.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_network_ip_rules
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
}

data "azurerm_client_config" "current" {}
