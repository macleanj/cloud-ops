#!/bin/bash

# Script to prepare KUBECONFIG with service accounts

PROGRAM=$(basename "$0")
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')
TEMP_DIR=$HOME/.kube/temp
defaultKubeConfig="/.kube/vagrant-lab-admin.conf"
defaultNamespace="jenkins"

# Create temp directory
mkdir -p $TEMP_DIR

Usage()
{
  echo ""
  echo "Usage:"
  echo "Script to add ServiceAccount to KUBECONFIG."
  echo "You need to make sure you have sufficient priveledges."
  echo ""
  echo "Usage: $PROGRAM -sa <service account> [-ns <namespace>] [-c <clustername>]"
  echo ""
  echo "options:"
  echo "- sa      : Name of service account"
  echo "- ns      : Kubernetes namespace (Optional)"
  echo "- out     : Output file (Optional)"
  echo "- c       : Cluster name in KUBECONFIG (not implemented yet)"
  echo ""
  echo "default:"
  echo "KUBECONFIG: \$HOME/.kube/vagrant-lab-admin.conf"
  echo "output    : The currently used KUBECONFIG (merged)"
  echo "namespace : jenkins"
  echo "cluster   : Cluster used when running this script"
  echo ""
  exit 5
}

addSaToKubeConfig() {
  serviceAccount="${1}"
  namespace="${2}"
  outputFile="${3}"
  
  echo "Adding ServiceAccount: $serviceAccount from namespace $namespace to $outputFile"
  secret=$(kubectl get sa $serviceAccount -n $namespace -o json | jq -r .secrets[].name)
  kubectl get secret $secret -n $namespace  -o json | jq -r '.data["ca.crt"]' | base64 -D > $TEMP_DIR/$serviceAccount-ca.crt
  userToken=$(kubectl get secret $secret  -n $namespace -o json | jq -r '.data["token"]' | base64 -D)

  # get current context
  currentContext=$(kubectl config current-context)
  # get cluster name of context
  currentCluster=$(kubectl config get-contexts $currentContext | awk '{print $3}' | tail -n 1)
  # get endpoint of current context 
  currentEndpoint=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"$currentCluster\")].cluster.server}")

  # TODO: Some defaults. Will be updated later when options are added.
  clusterName=$currentCluster

  # Set cluster (only when different cluster needs to be set)
  # kubectl config set-cluster $clusterName \
  #   --embed-certs=true \
  #   --server=$endpoint \
  #   --certificate-authority=./$serviceAccount-ca.crt

  # Should we write out the current cluster config?
  if [ "$outputFile" != "$KUBECONFIG" ]; then
    kubectl config view --flatten --minify | yq d - contexts | yq d - users > $outputFile
  fi

  # Set user credentials
  kubectl --kubeconfig $outputFile config set-credentials $serviceAccount --token=$userToken

  # Set context. Define the combination of user with the cluster
  contextName="${serviceAccount}@${clusterName}"
  kubectl --kubeconfig $outputFile config set-context ${contextName} \
    --cluster=${clusterName} \
    --user=${serviceAccount} \
    --namespace=${namespace}

  if [ "$outputFile" != "$KUBECONFIG" ]; then
    # Switch current-context to alice-staging for the user
    kubectl --kubeconfig $outputFile config use-context $contextName
  fi
  
  # kubectl config unset users.cicd
  # kubectl config unset contexts.cicd@kubernetes
  # kubectl config unset clusters.foobar-baz
}

# Read and/or validate command-line parameters
ReadParams()
{
	[ $# -eq 0 ] && Usage

	while [ $# -gt 0 ]
	do
    case "${1}" in
      -sa)
        [[ ${2} =~ "^-" || -z ${2} ]] && echo ">>>>> No value given for ${1}" && Usage || serviceAccount="${2}"
        shift 2
      ;;
      -ns)
        [[ ${2} =~ "^-" || -z ${2} ]] && echo ">>>>> No value given for ${1}" && Usage || namespace="${2}"
        shift 2
      ;;
      -out)
        [[ ${2} =~ "^-" || -z ${2} ]] && echo ">>>>> No value given for ${1}" && Usage || outputFile="${2}"
        shift 2
      ;;
      *)
        Usage
      ;;
    esac
 	done

# Obligated fields
[ -z "$serviceAccount" ]  && echo "-sa missing. Exitting....." && Usage

# Defaults
[ -z $KUBECONFIG ] && KUBECONFIG="$defaultKubeConfig" && export $KUBECONFIG
[ -z $namespace ] && namespace="$defaultNamespace"
[ -z $outputFile ] && outputFile="$KUBECONFIG"
}

##########################
# Main script
##########################
ReadParams "$@"

addSaToKubeConfig "$serviceAccount" "$namespace" "$outputFile"


# Cleanup temp directory
rm -rf $TEMP_DIR
