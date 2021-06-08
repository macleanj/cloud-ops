# Scripts to get all USER kubeconfigs (dedicated for jerome)
export user=jerome
export exportPath=/Users/$user/Services/Workspaces/git/eon/mgt-k8s-cluster/azure-mgt-k8s-cluster

az login
export ARM_SUBSCRIPTION_ID="$(az account list | jq -r '.[] | select(.name|test("Kubernetes")) | .id')"
az account set --subscription $ARM_SUBSCRIPTION_ID

export CLUSTER_RESOURCE_GROUP_NAME=K8S_WEU_SBX_3.0_1
export CLUSTER_NAME=aks-mgt-k8s-sbx
KUBECONFIG_FILE="${exportPath}/kubeconfig-${user}-${CLUSTER_NAME}.yaml"
az aks get-credentials --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -f "${KUBECONFIG_FILE}" --overwrite-existing
export KUBECONFIG="${KUBECONFIG_FILE}"
kubelogin convert-kubeconfig

export CLUSTER_RESOURCE_GROUP_NAME=K8S_WEU_DEV_3.0_1
export CLUSTER_NAME=aks-mgt-k8s-dev
KUBECONFIG_FILE="${exportPath}/kubeconfig-${user}-${CLUSTER_NAME}.yaml"
az aks get-credentials --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -f "${KUBECONFIG_FILE}" --overwrite-existing
export KUBECONFIG="${KUBECONFIG_FILE}"
kubelogin convert-kubeconfig

export CLUSTER_RESOURCE_GROUP_NAME=K8S_WEU_PREPROD_3.0_1
export CLUSTER_NAME=aks-mgt-k8s-pre
KUBECONFIG_FILE="${exportPath}/kubeconfig-${user}-${CLUSTER_NAME}.yaml"
az aks get-credentials --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -f "${KUBECONFIG_FILE}" --overwrite-existing
export KUBECONFIG="${KUBECONFIG_FILE}"
kubelogin convert-kubeconfig

export CLUSTER_RESOURCE_GROUP_NAME=K8S_WEU_PROD_3.0_1
export CLUSTER_NAME=aks-mgt-k8s-prod
KUBECONFIG_FILE="${exportPath}/kubeconfig-${user}-${CLUSTER_NAME}.yaml"
az aks get-credentials --resource-group "$CLUSTER_RESOURCE_GROUP_NAME" --name "$CLUSTER_NAME" -f "${KUBECONFIG_FILE}" --overwrite-existing
export KUBECONFIG="${KUBECONFIG_FILE}"
kubelogin convert-kubeconfig
