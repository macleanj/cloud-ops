#!/bin/bash

# Script to follow logs of pod.

POD_NAME=$(echo ${1} | sed -e 's/.*pod\///g')
POD_NAME_SELECTED=$(kubectl get pods | grep ${POD_NAME} | grep -v Terminating | head -1 | sed -e 's/ .*//g')
# echo $POD_NAME_SELECTED
CONTAINER_NAME=$2
kubectl logs --follow $POD_NAME_SELECTED $CONTAINER_NAME
