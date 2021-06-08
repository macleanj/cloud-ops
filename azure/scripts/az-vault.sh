# Scripts used for the most common Azure operational tasks
resourceGroup=K8S_WEU_SBX_3.0_1
resourcesName=aks-mgt-k8s-sbx

# List all vault
az keyvault list --resource-group $resourceGroup | jq -r '.[].name'
az keyvault list | jq -r '.[].name'
az keyvault list-deleted

# Disable purge protection (disabled in latest version of Azure. Not possible)
# az keyvault update --name "$resourcesName" --resource-group $resourceGroup --retention-days 1
# --enable-soft-delete false
# --enable-purge-protection false
