# Scripts used for the most common Azure operational tasks
resourceGroup=K8S_WEU_DEV_3.0_1
clusterName=aks-mgt-k8s-dev
scaleDynamics=6 # 2 times the amount of zones to be sure the hostname with the availability zone is available for the nodeSelectorTerms
nodePoolName=infra

# Set nodepool min-count to current count +5 to enable multi-zone setup"
nodepoolShow=$(az aks nodepool show --cluster-name "$clusterName" --name $nodePoolName --resource-group "$resourceGroup")
export currentCount=$(echo $nodepoolShow | jq -r '.count')
export currentMaxCount=$(echo $nodepoolShow | jq -r '.maxCount')
echo "Current nodeCount=$currentCount"
export newMinCount=$(($currentCount+$scaleDynamics))
echo "New minCount=$newMinCount / maxCount=$currentMaxCount"
# az aks nodepool update --update-cluster-autoscaler --min-count $newMinCount --max-count $currentMaxCount --cluster-name "$clusterName" --name $nodePoolName --resource-group "$resourceGroup"
az aks nodepool update --disable-cluster-autoscaler --cluster-name "$clusterName" --name $nodePoolName --resource-group "$resourceGroup"
az aks nodepool scale --node-count $newMinCount --no-wait --cluster-name "$clusterName" --name $nodePoolName --resource-group "$resourceGroup"

# Set nodepool min-count to current -5 nodes to nodepool to enable multi-zone setup"
export currentMaxCount=30
export newMinCount=1
echo "New minCount=$newMinCount / maxCount=$currentMaxCount"
az aks nodepool update --enable-cluster-autoscaler --min-count $newMinCount --max-count $currentMaxCount --cluster-name "$clusterName" --name $nodePoolName --resource-group "$resourceGroup"
