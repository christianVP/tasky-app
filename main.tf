provider "azurerm" {
  features {}

  subscription_id = "12c9cd90-3a91-45d3-bf62-95ad0d62f438"
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

# Ubuntu 18.04 VM
resource "azurerm_network_interface" "vm_nic" {
  name                = "tasky-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
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

  custom_data = filebase64("install-mongodb.sh")
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "tasky-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "taskyaks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
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

# Outputs kubeconfig
output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

