#!/bin/bash

# Scripts used for the most common GitLab operational tasks

PROGRAM=$(basename "$0")
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')

read -r -d '' layers <<- EOM
02-vault
09-networking
10-k8s-cluster
11-k8s-monitoring
13-k8s-kubecost
15-k8s-app-gw-ingress
19-k8s-network-policies
20-k8s-opa-gatekeeper
21-k8s-opa-policy-templates
22-k8s-opa-policies
30-k8s-kured
60-k8s-backup
EOM

Usage()
{
  echo ""
  echo "Usage: $PROGRAM [-fmt]"
  echo ""
  echo "options:"
  echo "-fmt      : Format"
  echo ""
  echo "Examples:"
  echo "$PROGRAM -fmt"
  exit 5
}


# Read and/or validate command-line parameters
ReadParams()
{
	[ $# -eq 0 ] && Usage

	while [ $# -gt 0 ]
	do
		case ${1}	in
    "-fmt")
      fmt=1
      shift 1
      ;;
    "-debug")
      debug=1
      shift 1
      ;;
		*)
			echo ">>>>> Wrong argument given: ${1}"; Usage
			;;
		esac
 	done

  # Obligated fields
}

##########################
# Main script
##########################
ReadParams "$@"

if [ ! -z $fmt ]; then
  OLDIFS=$IFS
  IFS=$'\n'
  for layer in $layers; do
    [ ! -d $layer ] && continue
    [[ $layer =~ ^[[:space:]]*[\#]+ ]] && continue
    echo "Format layer $layer"
    cd $layer
    # terragrunt fmt
    terragrunt apply
    # terragrunt apply --auto-approve
    cd - > /dev/null 2>&1
  done
  IFS=$OLDIFS
else
  echo "Unknown options given"
fi
