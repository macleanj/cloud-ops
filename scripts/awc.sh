#!/bin/bash

# Scripts used for the most common AWS operational tasks
# Use K8S as template!!
PROGRAM=$(basename "$0")
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')

Usage()
{
  echo ""
  echo "Usage: $PROGRAM [option]"
  echo ""
  echo "options:"
  echo "- instance-names       : List instance names"
  exit 5
}

case "$1" in
  instance-names|in)
    echo ">>> All instances"
    aws ec2 describe-instances | jq  '.Reservations[].Instances[].Tags[] | select(.Key == "Name").Value' |\
    sort |\
    uniq -c
  ;;
  vpcs)
    echo ">>> All VPCs"
    aws ec2 describe-vpcs | jq  '.Vpcs[].Tags[] | select(.Key == "Name").Value' |\
    sort |\
    uniq -c
  ;;
  *)
    Usage
    exit 1
  ;;
esac

