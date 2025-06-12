variable "vm_admin_username" {
  description = "TODO: Add description for vm_admin_username"
  type        = string
  default     = "azureuser"
}

variable "vm_public_key_path" {
  description = "TODO: Add description for vm_public_key_path"
  type        = string
  default     = "keys/id_rsa.pub"
}

variable "vm_private_key_path" {
  description = "TODO: Add description for vm_private_key_path"
  type        = string
  default     = "keys/id_rsa"
}

variable "azure_resource_group" {
  description = "TODO: Add description for azure_resource_group"
  type        = string
  default     = "tasky-rg"
}

variable "azure_storage_account_name" {
  description = "TODO: Add description for azure_storage_account_name"
  type        = string
  default     = "taskytfstate1234"
}

variable "tenant_id" {
  description = "The Tenant ID of the Azure Active Directory"
  type        = string
}

variable "client_id" {
  description = "The Client ID of the Service Principal"
  type        = string
}

variable "client_secret" {
  description = "The Client Secret of the Service Principal"
  type        = string
  sensitive   = true  # Mask the secret
}

variable "subscription_id" {
  description = "The Subscription ID in Azure"
  type        = string
}

variable "blob_conn_string" {
  description = "The connection string for the blob storage"
  type        = string
}

variable "ssh_private_key" {
  description = "The private SSH key for MongoDB backup"
  type        = string
  sensitive   = true
}

