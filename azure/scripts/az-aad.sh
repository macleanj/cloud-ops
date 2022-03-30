exit 11
resourceGroup=K8S_WEU_SBX_3.0_1
aksResourceGroup=MC_K8S_WEU_SBX_3.0_1_aks-mgt-k8s-sbx_westeurope
clusterName=aks-mgt-k8s-sbx

az ad group member list --group K8S_MGT_ALL_USERS | jq -r '.[].displayName'

# Search Apps, Users, etc
# Get ObjectId (SP or MI)
az ad sp list --display-name "SP_K8S_AKS_WEU_SBX_3.0_1" --query [].objectId --output tsv
az ad sp list --display-name "aks-mgt-k8s-sbx-aks-control-plane-identity" --query [].objectId --output tsv
# Get info
az ad sp show --id bb395c90-cdad-4789-9e93-d0af821f16de
# Get roles
az role assignment list --all --assignee bb395c90-cdad-4789-9e93-d0af821f16de --query '[].{resourceGroup:resourceGroup, roleDefinitionName:roleDefinitionName, scope:scope}' --output tsv
# Show AKS connected identity
az aks show --name $clusterName --resource-group $resourceGroup --query '{identity:identity}' --output json
# Show VMSS connected identities
az vmss list -g $aksResourceGroup --query [].name
az vmss show -n aks-infra-24130635-vmss -g $aksResourceGroup --query 'identity.userAssignedIdentities'
