#!/bin/bash

# Scripts used for the most common K8S operational tasks
# Todo
# - Trigger redeploy: kubectl patch deployment <your_deployment> -p "{\"spec\": {\"template\": {\"metadata\": { \"labels\": {  \"redeploy\": \"$(date +%s)\"}}}}}"

PROGRAM=$(basename "$0")
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')
execCmd="kubectl" # Use oc or kubectl 

Usage()
{
  echo ""
  echo "Usage: $PROGRAM [resourceType] -label"
  echo ""
  echo "resourceType  : kubernetes resourceType like node, pod, etc"
  echo ""
  echo "options:"
  echo "-label    : When no argument is given : show all resources' labels"
  echo "            When argument is given    : show only resources matching that label"
  exit 5
}


# Read and/or validate command-line parameters
ReadParams()
{
	[ $# -eq 0 ] && Usage
  resourceType="${1}"; resourceTypeSet=0
  [[ "ns namespace namespaces" =~ (^|[[:space:]])"${resourceType}"($|[[:space:]]) ]] &&  resourceTypeSet=1 && resourceType="namespace"
  [[ "n node nodes" =~ (^|[[:space:]])"${resourceType}"($|[[:space:]]) ]] &&  resourceTypeSet=1 && resourceType="node"
  [[ "p pod pods" =~ (^|[[:space:]])"${resourceType}"($|[[:space:]]) ]] && resourceTypeSet=1 && resourceType="pod"
  [[ "s svc service services" =~ (^|[[:space:]])"${resourceType}"($|[[:space:]]) ]] && resourceTypeSet=1 && resourceType="service"
  [[ "pv persistentvolume" =~ (^|[[:space:]])"${resourceType}"($|[[:space:]]) ]] && resourceTypeSet=1 && resourceType="persistentvolume"
  [[ "pvc persistentvolumeclaim" =~ (^|[[:space:]])"${resourceType}"($|[[:space:]]) ]] && resourceTypeSet=1 && resourceType="persistentvolumeclaim"
  [ $resourceTypeSet -eq 0 ] && echo "Unsupported resourceType given." && Usage
  shift 1

	while [ $# -gt 0 ]
	do
		case ${1}	in
		"-l"|"-label")
      if [[ ${2} =~ "^-" || -z ${2} ]]; then
        label="all";
        shift 1
      else
        label="${2}"
        shift 2
      fi
			;;
		"-z"|"-zone")
      if [[ ${2} =~ "^-" || -z ${2} ]]; then
        zone="all";
        shift 1
      else
        zone="${2}"
        shift 2
      fi
			;;
		"-ppn")
        option="ppn"; shift 1
			;;
		"-i"|"-image")
      if [[ ${2} =~ "^-" || -z ${2} ]]; then
        image="all";
        shift 1
      else
        image="${2}"
        shift 2
      fi
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

_jq() {
  # $1: Row offered as base64
  # $2: Value to be selected
  echo ${1} | base64 --decode | jq -r ${2}
}

# Function getting labels
getLabels()
{
  resourceType="${1}"
  label="${2}"
  if [[ "$label" == "all" ]]; then
    getResourcesCmd="kubectl get ${resourceType} --output=name"
    for resource in $( $getResourcesCmd ); do printf "Labels for %s\n" "$resource" | grep --color -E '[^/]+$' && kubectl get "$resource" --output=json | jq -r -S '.metadata.labels | to_entries | .[] | " \(.key)=\(.value)"' 2>/dev/null; printf "\n"; done
  else
    $execCmd get ${resourceType} --selector="${label}" --output=name
  fi
}

# Function getting labels
getZones()
{
  resourceType="${1}"
  zone="${2}"
  if [[ "$zone" == "all" ]]; then
    [[ "${resourceType}" == "node" ]] && $execCmd get ${resourceType} -o=custom-columns=NAME:.metadata.name,"ZONE":".metadata.labels.failure-domain\.beta\.kubernetes\.io/zone" --sort-by=.metadata.name
    [[ "${resourceType}" == "persistentvolume" ]] && $execCmd get ${resourceType} -o=custom-columns=CLAIM:.spec.claimRef.name,"ZONE":".metadata.labels.failure-domain\.beta\.kubernetes\.io/zone",NAME:.metadata.name --sort-by=.spec.claimRef.name
  else
    $execCmd get ${resourceType} --selector="failure-domain.beta.kubernetes.io/zone=${zone}" --output=name
  fi
}


##########################
# Main script
##########################
ReadParams "$@"

case "${resourceType}" in
  "namespace")
    if [ ! -z $image ]; then
      echo ">>> All container images"
      kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort | uniq -c
    fi
  ;;
  "node")
    if [ ! -z $label ]; then
      getLabels "${resourceType}" "${label}"
    elif [ ! -z $zone ]; then
      getZones "${resourceType}" "${zone}"
    else
      echo ">>>>> No proper ${resourceType} option given...."; Usage
    fi
  ;;
  "pod")
    if [ ! -z $label ]; then
      getLabels "${resourceType}" "${label}"
    elif [[ "$option" == "ppn" ]]; then
      echo ">>> Pods per node"
      kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name,STATUS:.status.phase --sort-by=.spec.nodeName --all-namespaces
    else
      echo ">>>>> No proper ${resourceType} option given...."; Usage
    fi
  ;;
  "persistentvolume")
    if [ ! -z $label ]; then
      getLabels "${resourceType}" "${label}"
    elif [ ! -z $zone ]; then
      getZones "${resourceType}" "${zone}"
    else
      echo ">>>>> No proper ${resourceType} option given...."; Usage
    fi
  ;;
  "persistentvolumeclaim")
    if [ ! -z $label ]; then
      getLabels "${resourceType}" "${label}"
    else
      echo ">>>>> No proper ${resourceType} option given...."; Usage
    fi
  ;;
  *)
    Usage
  ;;
esac
