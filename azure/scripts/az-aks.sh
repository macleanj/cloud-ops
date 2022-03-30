exit 11

# AKS: https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest
resourceGroup=K8S_WEU_SBX_3.0_1
clusterName=aks-mgt-k8s-sbx
# resourceGroup=K8S_WEU_DEV_3.0_1
# clusterName=aks-mgt-k8s-dev
# resourceGroup=K8S_WEU_PROD_3.0_1
# clusterName=aks-mgt-k8s-prod

# Base commands
az aks show --name $clusterName --resource-group $resourceGroup
az aks nodepool list --cluster-name $clusterName --resource-group $resourceGroup
az monitor autoscale list --resource-group $resourceGroup

# Versions and upgrade preperation
export clusterVersion=$(
  az aks show --name $clusterName --resource-group $resourceGroup |
    jq -r '.kubernetesVersion'
)
echo -e "AKS current cluster version:\n$clusterVersion"
echo -e "AKS current nodepool version(s):"
az aks show --name $clusterName --resource-group $resourceGroup |
  jq -r '
  .agentPoolProfiles[] | 
  .name + ": " + .orchestratorVersion
  '

location="westeurope"
echo "All AKS version in location $location:"
az aks get-versions --location $location | jq '.orchestrators[].orchestratorVersion'
echo "AKS version available in location $location eligible for upgrade (ALL):"
az aks get-upgrades --resource-group $resourceGroup --name $clusterName --output table
# location="northeurope"
# echo "All AKS version in location $location:"
# az aks get-versions --location $location | jq '.orchestrators[].orchestratorVersion'

# Nodes per nodepools
echo "Nodes per nodepools"
az aks nodepool list --cluster-name $clusterName --resource-group $resourceGroup |
  jq -r '
  .[] |
  "---",
  .name,
  .count,
  .max-surge
  # .vmSize,
  # .nodeLabels,
  # .nodeTaints
  '

# Upgrade Cluster
newK8SVerion="1.21.2"
az aks upgrade --resource-group $resourceGroup --name $clusterName --control-plane-only --kubernetes-version $newK8SVerion
az aks show --resource-group $resourceGroup --name $clusterName --output table


# Upgrade Node Pools
az aks nodepool upgrade -n system -g $resourceGroup --cluster-name $clusterName  --kubernetes-version $newK8SVerion --max-surge 33%
az aks nodepool show -n system --resource-group $resourceGroup --cluster-name $clusterName --output table

az aks nodepool upgrade -n infra -g $resourceGroup --cluster-name $clusterName  --kubernetes-version $newK8SVerion --max-surge 33%
az aks nodepool show -n infra --resource-group $resourceGroup --cluster-name $clusterName --output table

az aks nodepool upgrade -n generic -g $resourceGroup --cluster-name $clusterName  --kubernetes-version $newK8SVerion --max-surge 33%
az aks nodepool show -n generic --resource-group $resourceGroup --cluster-name $clusterName --output table

az aks nodepool upgrade -n memory -g $resourceGroup --cluster-name $clusterName  --kubernetes-version $newK8SVerion --max-surge 33%
az aks nodepool show -n memory --resource-group $resourceGroup --cluster-name $clusterName --output table

az aks nodepool upgrade -n cpu -g $resourceGroup --cluster-name $clusterName  --kubernetes-version $newK8SVerion --max-surge 33%
az aks nodepool show -n cpu --resource-group $resourceGroup --cluster-name $clusterName --output table

az aks nodepool upgrade -n gpu -g $resourceGroup --cluster-name $clusterName  --kubernetes-version $newK8SVerion --max-surge 33%
az aks nodepool show -n gpu --resource-group $resourceGroup --cluster-name $clusterName --output table


# Prep
az aks nodepool update -n system -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n infra -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n generic -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n memory -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n cpu -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n gpu -g $resourceGroup --cluster-name $clusterName --max-surge 33%


####################################################################
# >>> Delete and recreate node manually
# 1. Set node pool on manual scale + 2 nodes
# 2. Drain node
# 3. Check: watch "kubectl get pods -A | egrep -v 'Completed|Running'"
# 4. Put node pool back to auto scaling
# In autoscal mode: By draining the node will be deleted automatically. A new one will 
# be added as part of the auto-scaling. Node might end up in OOM.
####################################################################
nodeName=aks-infra-22373201-vmss000000
nodeName=aks-infra-22373201-vmss000001
nodeName=aks-infra-22373201-vmss000007
kubectl drain $nodeName --ignore-daemonsets --delete-emptydir-data
kubectl delete node $nodeName # Also delete from vss
# # Delete all daemonSet pods
# kubectl get pod -o wide -A | grep $nodeName
# OLDIFS=$IFS
# IFS=$'\n'
# nodeName=aks-infra-22373201-vmss000001
# for daemonSet in $(kubectl get pod -o wide -A | grep $nodeName); do
#   # echo $daemonSet
#   namespace=$(echo $daemonSet | awk '{print $1}')
#   pod=$(echo $daemonSet | awk '{print $2}')
#   echo "Namespace: $namespace, Pod: $pod"
#   kubectl delete -n $namespace pod $pod
# done
# IFS=$OLDIFS

# Remove cluster
# az aks delete --name $clusterName --resource-group $resourceGroup


## Change SKU of cluster between Free and UptimeSLA
# https://docs.microsoft.com/en-us/azure/aks/uptime-sla#modify-an-existing-cluster-to-use-uptime-sla
# https://docs.microsoft.com/en-us/azure/aks/uptime-sla#opt-out-of-uptime-sla
az aks update --resource-group $resourceGroup --name $clusterName --uptime-sla
az aks update --resource-group $resourceGroup --name $clusterName --no-uptime-sla
az aks show --name $clusterName --resource-group $resourceGroup |  jq -r '.sku'

# Load balancer configuration
# With regard to the SNAT exhaustion issue: "Load balancer profile allocated ports is not in an allowable range given the number of nodes and IPs provisioned. Refer to https://aka.ms/aks/slb-ports for more details."
# Calculation:
# Total nodes: 5 x nodepool of 30 + 3 x system = 153 nodes (when auto-scaling this is the max value)
# 4000 ports per node: 612000 slb ports
# IP addressed needed: 612000 / 64000 = 10
# Same adding maxSurge
# Total nodes: 153 * 33% = 204 nodes
# 4000 ports per node: 813960 slb ports
# IP addressed needed: 813960 / 64000 = 13
aksResourceGroup=$(az aks show --resource-group $resourceGroup --name $clusterName --query nodeResourceGroup -o tsv)
az network lb outbound-rule list --resource-group $aksResourceGroup --lb-name kubernetes -o table


# Update identity
az aks update --resource-group $resourceGroup --name $clusterName --enable-managed-identity --assign-identity /subscriptions/622b4053-790d-4938-9c89-35a1f3ab0137/resourceGroups/K8S_WEU_SBX_3.0_1/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aks-mgt-k8s-sbx-aks-identity
az resource update --ids /subscriptions/622b4053-790d-4938-9c89-35a1f3ab0137/resourcegroups/K8S_WEU_SBX_3.0_1/providers/Microsoft.ContainerService/managedClusters/aks-mgt-k8s-sbx
# Update node image only (no upgrade)
az aks nodepool update -n system -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n infra -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n generic -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n memory -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n cpu -g $resourceGroup --cluster-name $clusterName --max-surge 33%
az aks nodepool update -n gpu -g $resourceGroup --cluster-name $clusterName --max-surge 33%

# Refetch MI on nodes (e.g. when changing from SP to MI)
for nodepool in system infra generic memory cpu gpu; do
  az aks nodepool upgrade -n $nodepool -g $resourceGroup --cluster-name $clusterName --node-image-only --no-wait
done

# Update node labels
for nodepool in system infra; do
  az aks nodepool update --resource-group $resourceGroup --cluster-name $clusterName --name $nodepool \
  --labels kubernetes-role=$nodepool node-type=provider
done
