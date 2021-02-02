#!/bin/bash

# Script to exec into pod.
POD_NAME=$(echo ${1} | sed -e 's/.*pod\///g')
[ -z "${2}" ] && CMD="bash" || CMD="${2}"
[ -z "${3}" ] && CONTAINER="" || CONTAINER="${3}"

kubectl exec -it $(kubectl get all | grep pod/${POD_NAME} | grep -v Terminating | head -1 | sed -e 's/ .*//g') -- ${CMD}