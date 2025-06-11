# tasky-app
Terraform to deploy tasky-app to Azure 


# Tasky App Infrastructure on Azure with Terraform

This project provisions an Azure environment to run the **Tasky app** in a Kubernetes cluster, using a VM running MongoDB 4.4.

## 📦 What It Deploys

- Azure Resource Group
- Azure Virtual Network + Subnet
- Ubuntu 18.04 VM with MongoDB 4.4 installed
- Azure Kubernetes Service (AKS) Cluster
- Sample Kubernetes deployment for Tasky (`cvp01/tasky:3`)

---

## ⚙️ Requirements

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- SSH key pair (e.g., `~/.ssh/id_rsa` and `id_rsa.pub`)

---

## 🚀 How to Use

### 1. Login to Azure

Run this once from your terminal:

```bash
az login
az account set --subscription "<your-subscription-id>"


## CI-GitHub Actions:

GitHub Actions needs secrets for AZR storage to get Terraform state
Likewise a Service Principal must exist in Azure
