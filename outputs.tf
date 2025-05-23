output "vm_ip" {
  description = "Private IP of the MongoDB VM"
  value       = azurerm_network_interface.vm_nic.private_ip_address
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

