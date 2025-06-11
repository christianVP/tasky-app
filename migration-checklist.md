# 🔁 Azure Tenant Migration Checklist

This checklist guides you through migrating your Terraform-managed infrastructure and GitHub Actions CI/CD pipeline to a **new Azure tenant and subscription**.

---

## 1. 🔐 Create New Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "tasky-sp-new" \
  --role="Contributor" \
  --scopes="/subscriptions/<NEW_SUBSCRIPTION_ID>" \
  --sdk-auth


Copy the output values:

- clientId

- clientSecret

- subscriptionId

 -tenantIdi

Then update secrets in GitHub

Go to GitHub → Repo → Settings → Secrets and Variables → Actions
Replace these with the new values:

Secret Name		Description
ARM_CLIENT_ID		From clientId
ARM_CLIENT_SECRET	From clientSecret
ARM_SUBSCRIPTION_ID	From subscriptionId
ARM_TENANT_ID		From tenantId

Push a change to main.tf or run manually via "Actions > Run workflow"
