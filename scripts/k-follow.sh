#!/bin/bash

# Script to follow logs of pod.

POD_NAME=$(echo ${1} | sed -e 's/.*pod\///g')
kubectl logs --follow $(kubectl get all | grep pod/${POD_NAME} | grep -v Terminating | head -1 | sed -e 's/ .*//g')
