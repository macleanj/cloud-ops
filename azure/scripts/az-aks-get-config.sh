# Scripts to get all USER kubeconfigs (dedicated for jerome)

export user=jerome
export az_user_name=jerome
az login
# export az_user_name=sp
# az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

export exportPath=/Users/$user/Services/Workspaces/git/abn_amro/upf-platform

# Acceptance
# export CLUSTER_RESOURCE_GROUP_NAME=upfaks-a-rg
# export CLUSTER_NAME=upfaks-01-a-aks
# az account set --subscription ${ARM_SUBSCRIPTION_ID}
# KUBECONFIG_FILE="${exportPath}/kubeconfig-${az_user_name}-${CLUSTER_NAME}.yml"
# az aks get-credentials --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -f "${KUBECONFIG_FILE}" --overwrite-existing
# export KUBECONFIG="${KUBECONFIG_FILE}"
# kubelogin convert-kubeconfig

export CLUSTER_RESOURCE_GROUP_NAME=upfaks-a-rg
export CLUSTER_NAME=upfaks-01-a-aks
az account set --subscription ${ARM_SUBSCRIPTION_ID}
KUBECONFIG_FILE="${exportPath}/kubeconfig-${az_user_name}-${CLUSTER_NAME}.yml"
az aks get-credentials --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -f "${KUBECONFIG_FILE}" --overwrite-existing
export KUBECONFIG="${KUBECONFIG_FILE}"
kubelogin convert-kubeconfig
