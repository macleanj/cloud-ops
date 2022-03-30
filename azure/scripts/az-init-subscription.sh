#!/usr/bin/env bash
# 2020.08.05: Jerome Mac Lean - CrossLogic Consulting
# 
# Script to initialize all resources in a subscription. Hereafter Terraform can provision them without any registration restrictions.

[ -z $1 ] && echo "Please provide the subscriptionId" && exit 5

SUBSCRIPTIONNAMEORID=$1
az account set --subscription $SUBSCRIPTIONNAMEORID
status=$?

if [ $status -eq 0 ]; then
  NOTREGISTEREDNAMESPACES=$(az provider list --query "[?registrationState=='NotRegistered'].namespace" -o tsv)

  for NAMESPACE in $NOTREGISTEREDNAMESPACES
  do
    echo "Register: $NAMESPACE"
    az provider register --namespace $NAMESPACE
  done

  echo 'Finished!'
# else
# 	echo "Something went wrong"
fi

# Enables features
# NOTREGISTEREDFEATURES=$(az feature list --query "[?registrationState=='NotRegistered'].name" -o tsv)
# az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableUltraSSD')].{Name:name,State:properties.state}"
az feature register --namespace "Microsoft.ContainerService" --name "EnableUltraSSD"