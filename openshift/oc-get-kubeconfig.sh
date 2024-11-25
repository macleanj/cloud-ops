#!/bin/bash

now=$(date +%Y-%m-%d\ %H:%M:%S)
programName=$(basename $0)
programDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
baseName=$(echo ${programName} | sed -e 's/\.sh//g')
debug=0

unset KUBECONFIG
clusterName=$(kubectl config current-context | sed -e 's|^[^/]*/||g' | sed -e 's|:.*$||g')
kubectl config view --flatten > "$programDir/kubeconfig/kubeconfig_$clusterName"
