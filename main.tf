## providers w settings for AZR and K8S APIs, to auth and connect, what to connect to

provider "azurerm" {
  features {}
  
  tenant_id       = var.tenant_id      # Use the tenant_id variable
  client_id       = var.client_id      # Service Principal client ID
  client_secret   = var.client_secret  # Service Principal client secret
  subscription_id = var.subscription_id # Subscription ID
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

## This block declares version of prov but also where tfstate is stored
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
  
  ### AZR storage where terraform.tfstate is saved
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

# public IP for MongoDB VM
resource "azurerm_public_ip" "vm_pip" {
  name                = "tasky-vm-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

# NSG to control access to MongoDB-VM
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
# bind NSG and interface
resource "azurerm_network_interface_security_group_association" "vm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Ubuntu 18.04 VM for MongoDB 
# install script used to install and start MongoDB
# ssh-key used to access VM, also used in Git-secrets by GitHub-actions

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

# Overly permissive CSP RBAC for MongoDB 
# AZR RBAC 

data "azurerm_subscription" "primary" {}

resource "azurerm_role_assignment" "mongo_vm_contributor" {
  principal_id   	= azurerm_linux_virtual_machine.mongo_vm.identity[0].principal_id
  role_definition_name 	= "Contributor"
  scope           	= data.azurerm_subscription.primary.id
}


# AKS K8S Cluster to run tasky-app
# netw is for subnet inside k8s cluster 
# node pool defines what machines are used to actually run the cluster
# DNS prefix is used for the K8S API endpoints 
# used internally for the control plane 
# Autoscaling enabled for VMs 
# - no pod scaling in this version (HPA), could be rel if many simul users
# this may not trigger VM scaling 

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
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 3
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

# Define ServiceAccount to then set Cluster Admin priv for tasky container
# ServiceAccount is the id, the role is the permissions and the binding assigns role to id
# the ServiceAccount is ref in the deployment

# Define the ServiceAccount
resource "kubernetes_service_account" "tasky_service_account" {
  metadata {
    name      = "tasky-service-account"
    namespace = "default"
  }
}

# Define the ClusterRoleBinding to grant ClusterAdmin privileges
resource "kubernetes_cluster_role_binding" "tasky_cluster_admin" {
  metadata {
    name = "tasky-cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.tasky_service_account.metadata[0].name
    namespace = kubernetes_service_account.tasky_service_account.metadata[0].namespace
  }

  role_ref {
    kind     = "ClusterRole"
    name     = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}

# how we deploy the tasky-app; 
# how many replicas are needed, what container version 
# Env vars are used to parse important variables to the taksy contianer 
# these env var define how to connect to the MongoDB VM
# ref the interface IP of the VM
# the secret is for sessions 
# Service Account is for Cluster Admin priv

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
        service_account_name = kubernetes_service_account.tasky_service_account.metadata[0].name
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
          
          # what port to connect to
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

# Setup a AZR native LB service to expose the tasky-app outside the cluster
# this automatically provides a AZT Loadbalancer and a public IP
# the LB gets traffic on port 8080 and fwd this to the pod, listening on port 8080
# the selector looks a the label to ensure only pods w app=tasky gets the traffic
# DNS name for taksy-app is set manually in One.com 

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

# Outputs kubeconfig - this is needed for kubectl and other tools
# like "az aks get-credentials"
output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

# Storage Account for backups
# Assign the connection string from Git-secret and store in local var, this comes from the -var option in Actions
# A K8S cron-job is used to schedule and run the actual backup. A container cvp01/mongo-backup is used in the cron-job.
# This container contains a script that ssh to the MongoDB VM and runs mongodump then connects to AZR storage using the connection string
# A separate K8S namespace is used for the backup "-n backup"
# In here we define the Secret and it contains the ssh key and connection string 
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

# Use the connection string passed through the GitHub secret (via environment variable -var)
locals {
  blob_connection_string = var.blob_conn_string  # Reference the variable here
}

## old
#locals {
#  blob_connection_string = "DefaultEndpointsProtocol=https;AccountName=${azurerm_storage_account.backup.name};AccountKey=${azurerm_storage_account.backup.primary_access_key};EndpointSuffix=core.windows.net"
#}

## we need the connection string so we can upload the actual backup from mongo

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
# we need to store the connection-string and the ssh-key as secrets inside K8S 
# we use a k8s-cronjob to schedule the backups 
# in order to backup mongo we ssh into the VM -> need sshkey
# we need to conn-string to connect to AZR-storage and upload the backup

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
    #blob-conn = local.blob_connection_string
    blob-conn = azurerm_storage_account.backup.primary_connection_string
    #id_rsa    = file(var.vm_private_key_path)
    #id_rsa = base64encode(var.ssh_private_key)
    id_rsa = var.ssh_private_key
  }

  type = "Opaque"
}

# setup the cronjob for backups
# done manually - via kubectl apply

#Re-run trigger dummy 28