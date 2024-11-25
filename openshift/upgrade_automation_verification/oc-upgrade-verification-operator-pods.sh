#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

name=${1}
pod_namespaces=${3}
pods_status_expected=0 # 0 "exit code"
declare -a pod_phase_expected=("Running" "Completed")

pods_status=0
for pod_namespace in $(echo "$pod_namespaces" | yq -r '.[]')
do
    pods_phase=$(oc get pods -n "${pod_namespace}" -o json | jq -r '.items[].status.phase')
    for pod_phase in $pods_phase
    do
        [[ " ${pod_phase_expected[@]} " =~ " ${pod_phase} " ]] || let "pods_status++";
    done

    if [ $pods_status == $pods_status_expected ]; then
        status_message="${GREEN}OK${NC}"
    else
        status_message="${RED}Not OK${NC}"
        oc get pods -n "${namespace}"
    fi

    printf "Operator pods status in namespace $pod_namespace: $status_message\n"
    if [ "$status_message" != "${GREEN}OK${NC}" ]; then exit 1; fi
done
