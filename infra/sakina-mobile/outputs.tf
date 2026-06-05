output "resource_group_name" {
  value = azurerm_resource_group.sakina_mobile.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.sakina_mobile.name
}

output "acr_login_server" {
  value = azurerm_container_registry.sakina_mobile.login_server
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.sakina_mobile.fqdn
}

output "redis_hostname" {
  value = azurerm_redis_cache.sakina_mobile.hostname
}

output "storage_account_name" {
  value = azurerm_storage_account.sakina_mobile.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.sakina_mobile.vault_uri
}
