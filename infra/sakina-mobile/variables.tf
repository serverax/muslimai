variable "location" {
  description = "Azure region for Sakina Mobile staging"
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-sakina-mobile-staging-uksouth"
}

variable "aks_name" {
  description = "AKS cluster name"
  type        = string
  default     = "aks-sakina-mobile-staging"
}

variable "acr_name" {
  description = "ACR name"
  type        = string
  default     = "acrsakinamobilestg"
}

variable "postgres_name" {
  description = "Postgres flexible server name"
  type        = string
  default     = "pg-sakina-mobile-staging"
}

variable "redis_name" {
  description = "Redis cache name"
  type        = string
  default     = "redis-sakina-mobile-staging"
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
  default     = "stsakinamobilestg"
}

variable "key_vault_name" {
  description = "Key vault name"
  type        = string
  default     = "kv-sakina-mobile-stg"
}

variable "k8s_namespaces" {
  description = "Namespaces for Sakina Mobile staging"
  type        = list(string)
  default = [
    "sakina-mobile-staging",
    "sakina-rag-staging",
    "sakina-monitoring-staging",
    "sakina-security-staging"
  ]
}


variable "postgres_admin_password" {
  description = "PostgreSQL admin password supplied via tfvars or env"
  type        = string
  sensitive   = true
}

variable "aks_api_authorized_ip_ranges" {
  description = "CIDR ranges allowed to access the Sakina AKS API server."
  type        = list(string)
}

variable "allowed_network_ip_rules" {
  description = "CIDR ranges allowed to access private Sakina Azure data-plane resources."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Subnet IDs allowed to access private Sakina Azure data-plane resources."
  type        = list(string)
  default     = []
}
