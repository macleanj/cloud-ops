#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

name=${1}
managed_cluster_expected=$(echo ${2} | yq -r '.[]')
managed_cluster=$(oc get ManagedClusters -o json | jq -r '.items[].metadata.labels.name')
cluster_status_expected=0 # 0 "exit code"
declare -a cluster_run_status_expected=("True")

# Compare found vs expected managed clusters
diff_managed_clusters=$(echo ${managed_cluster_expected[@]} ${managed_cluster[@]} | tr ' ' '\n' | sort | uniq -u)
if [[ "$diff_managed_clusters" == "" ]]; then
    status_message="${GREEN}OK${NC}"
else
    status_message="${RED}Not OK${NC}"
    echo "Cluster(s) not expected: $diff_managed_clusters"
    printf "Found managed clusters are not corresponding with the expected managed clusters.\n"
fi
printf "Cluster found matching clusters expected: $status_message\n"

if [ "$status_message" != "${GREEN}OK${NC}" ]; then exit 1; fi

clusters_status=0
for managed_cluster in $managed_cluster_expected
do
    cluster_run_statusses=$(oc get ManagedClusters -o json | jq -r '.items[].status.conditions[].status')
    for cluster_run_status in $cluster_run_statusses
    do
        [[ " ${cluster_run_status_expected[@]} " =~ " ${cluster_run_status} " ]] || let "clusters_status++";
    done

    if [ $clusters_status == $cluster_status_expected ]; then
      status_message="${GREEN}OK${NC}"
    else
        status_message="${RED}Not OK${NC}"
        oc get ManagedClusters $managed_cluster -o json | jq -r '.items[].status.conditions.status'
    fi

    printf "Cluster status $managed_cluster: $status_message\n"
    if [ "$status_message" != "${GREEN}OK${NC}" ]; then exit 1; fi
done
