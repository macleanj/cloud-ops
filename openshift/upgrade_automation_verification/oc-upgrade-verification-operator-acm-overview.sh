#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

name=${1}
managed_cluster_expected=$(echo ${2} | yq -r '.[]')
managed_cluster=$(oc get ManagedClusters -o json | jq -r '.items[].metadata.labels.name')
cluster_status_expected=0 # 0 "exit code"
declare -a cluster_run_status_expected=("True")

echo ">>>>> Manual verification via GUI"
echo "     All Clusters -> Home -> Overview"
echo "     Should be accessible"
