provider "azurerm" {
  features {}

  subscription_id = "12c9cd90-3a91-45d3-bf62-95ad0d62f438"
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tasky-tfstate-rg"
    storage_account_name = "taskytfstate1234"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    lock_timeout	 = "5m"
  }
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = "tasky-rg"
  location = "West Europe"
}

# Create Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "tasky-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Subnet for VM and AKS
resource "azurerm_subnet" "main" {
  name                 = "tasky-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "tasky-aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_public_ip" "vm_pip" {
  name                = "tasky-vm-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

resource "azurerm_network_security_group" "vm_nsg" {
  name                = "tasky-vm-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "vm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Ubuntu 18.04 VM
resource "azurerm_network_interface" "vm_nic" {
  name                = "tasky-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.vm_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "mongo_vm" {
  name                  = "tasky-mongo-vm"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = "Standard_B1s"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.vm_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/keys/id_rsa.pub")

  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  
  identity {
    type = "SystemAssigned"
  }

  custom_data = filebase64("install-mongodb.sh")
}

# Permissive CSP RBAC

data "azurerm_subscription" "primary" {}

resource "azurerm_role_assignment" "mongo_vm_contributor" {
  principal_id   	= azurerm_linux_virtual_machine.mongo_vm.identity[0].principal_id
  role_definition_name 	= "Contributor"
  scope           	= data.azurerm_subscription.primary.id
}


# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "tasky-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "taskyaks"

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.2.0.10"
    service_cidr   = "10.2.0.0/16"
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = "azureuser"

    ssh_key {
      key_data = file("${path.module}/keys/id_rsa.pub")
    }
  }
}

resource "kubernetes_deployment" "tasky" {
  metadata {
    name = "tasky"
    labels = {
      app = "tasky"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "tasky"
      }
    }

    template {
      metadata {
        labels = {
          app = "tasky"
        }
      }

      spec {
        container {
          image = "cvp01/tasky:4"
          name  = "tasky"

          env {
            name  = "MONGODB_URI"
            value = "mongodb://admin:mongo@${azurerm_network_interface.vm_nic.private_ip_address}:27017/tasky?authSource=admin"
            #value = "mongodb://admin:mongo@${azurerm_public_ip.vm_pip.ip_address}:27017/tasky?authSource=admin"
          }

          env {
            name  = "SECRET"
            value = "secret123"
          }

          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "tasky" {
  metadata {
    name = "tasky-service"
  }

  spec {
    selector = {
      app = kubernetes_deployment.tasky.metadata[0].labels.app
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

# Outputs kubeconfig
output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

# Storage Account for backups

#

resource "azurerm_storage_account" "backup" {
  name                     = "taskybackupstore"  # must be globally unique
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "backup_container" {
  name                  = "tasky-backups"
  storage_account_name  = azurerm_storage_account.backup.name
  container_access_type = "blob"
}

# Use the connection string passed through the GitHub secret (via environment variable)
locals {
  blob_connection_string = var.blob_conn_string  # Reference the variable here
}

## old
#locals {
#  blob_connection_string = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.backup.name};AccountKey=${azurerm_storage_account.backup.primary_access_key};EndpointSuffix=core.windows.net"
#}

## old

output "blob_conn_string" {
  value     = azurerm_storage_account.backup.primary_connection_string # Output the connection string from the variable
  sensitive = true      
}

#old
#output "blob_conn_string" {
#  value = azurerm_storage_account.backup.primary_connection_string
#  sensitive = true
#}
# old


# K8S secrets
resource "kubernetes_namespace" "backup" {
  metadata {
    name = "backup"
  }
}

resource "kubernetes_secret" "backup_secrets" {
  metadata {
    name      = "backup-secrets"
    namespace = kubernetes_namespace.backup.metadata[0].name
  }

  data = {
    blob-conn = local.blob_connection_string
    id_rsa    = file(var.vm_private_key_path)
  }

  type = "Opaque"
}

# setup the cronjob for backups
# done manually - via kubectl apply

#Re-run trigger dummy 4 
