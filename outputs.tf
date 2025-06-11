output "vm_ip" {
  description = "Private IP of the MongoDB VM"
  value       = azurerm_network_interface.vm_nic.private_ip_address
}

output "vm_public_ip" {
  description = "Public IP of the MongoDB VM"
  value       = azurerm_public_ip.vm_pip.ip_address
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_kube_config" {
  description = "Kubeconfig raw content (for debugging only)"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "tasky_service_lb_ip" {
  value = kubernetes_service.tasky.status[0].load_balancer[0].ingress[0].ip
}

output "backup_blob_conn_string" {
  value = azurerm_storage_account.backup.primary_connection_string
  sensitive = true
}

