#!/bin/bash

# Scripts used for the most common GitLab operational tasks

PROGRAM=$(basename "$0")
BASENAME=$(echo $(basename "$0") | sed -e 's/.sh//g')
[ -z $CI_SERVER_URL ] && CI_SERVER_URL="git.eon-cds.de"
[ -z $CI_PROJECT_ID ] && CI_PROJECT_ID="5892"
[ -z $CI_COMMIT_BRANCH ] && CI_COMMIT_BRANCH="develop"

read -r -d '' layers <<- EOM
# 02-vault
# 03-storage
# 09-networking

# 10-k8s-cluster
# 10-k8s-cluster-pod-identity-controller
# 10-k8s-cluster-proportional-autoscaler
# 11-k8s-monitoring

# 12-k8s-logging
# 12-k8s-logging-config

# 14-k8s-kuberhealthy
# 14-k8s-kuberhealthy-checks
# 15-k8s-app-gw-ingress
# 19-k8s-network-policies
# 20-k8s-opa-gatekeeper

# 21-k8s-opa-policy-templates

# 22-k8s-opa-policies
# 50-k8s-storage
# 60-k8s-backup
# 99-k8s-services-ingress

# All (e.g. afterwards)
EOM

Usage()
{
  echo ""
  echo "Usage: $PROGRAM [-trigger <values>]"
  echo ""
  echo "options:"
  echo "-trigger  : Trigger CI pipeline with variables."
  echo "-server   : GitLab Server. Default: $CI_SERVER_URL"
  echo "-project  : GitLab Project. Default: $CI_PROJECT_ID"
  echo "-ref      : GitLab Branch. Default: $CI_COMMIT_BRANCH"
  echo ""
  echo "trigger:"
  echo "values    : variables[<key>]=<value>"
  echo ""
  echo "Examples:"
  echo "$PROGRAM -ref sandbox -trigger"
  echo "$PROGRAM -ref sandbox -project 5892 -server git.eon-cds.de -trigger variables[REPO_DIR]=09-networking"
  exit 5
}


# Read and/or validate command-line parameters
ReadParams()
{
	[ $# -eq 0 ] && Usage

	while [ $# -gt 0 ]
	do
		case ${1}	in
		"-trigger")
      if [[ ${2} =~ "^-" || -z ${2} ]]; then
        triggerValues="all";
        shift 1
      else
        triggerValues="${2}"
        shift 2
      fi
			;;
		"-server")
      [[ ${2} =~ "^-" || -z ${2} ]]  && Usage || CI_SERVER_URL="${2}"
      shift 2
      ;;
		"-project")
      [[ ${2} =~ "^-" || -z ${2} ]] && Usage || CI_PROJECT_ID="${2}"
      shift 2
      ;;
		"-ref")
      [[ ${2} =~ "^-" || -z ${2} ]] && Usage || CI_COMMIT_BRANCH="${2}"
      shift 2
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
  [ -z $triggerValues ] && echo "No option(s) given. Exitting....." && Usage
}

##########################
# Main script
##########################
ReadParams "$@"

if [ ! -z $triggerValues ]; then
  [ -z $GITLAB_CI_TRIGGER_TOKEN ] && echo "Missing \$GITLAB_CI_TRIGGER_TOKEN . Exitting....." && exit 5

  echo "CI_SERVER_URL      : $CI_SERVER_URL"
  echo "CI_PROJECT_ID      : $CI_PROJECT_ID"
  echo "CI_COMMIT_BRANCH   : $CI_COMMIT_BRANCH"

  if [[ "$triggerValues" == "all" ]]; then
    OLDIFS=$IFS
    IFS=$'\n'
    for layer in $layers; do
      [[ $layer =~ ^[[:space:]]*[\#]+ ]] && continue
      layer=$(echo $layer | sed -r 's/[[:space:]]*[\#]+.*$//g'| xargs)
      [ ! -d $layer ] && continue
      echo "Triggering layer $layer"
        # # START Format all layer
        # cd $layer
        # terragrunt fmt
        # cd - > /dev/null 2>&1
        # # END Format all layer

        # # START copy file
        # cd $layer
        # cp /Users/jerome/Services/Workspaces/git/eon/mgt-k8s-cluster/k8stenantonboarding/k8s-namespaces-resources/terraform-config.tf .
        # cd - > /dev/null 2>&1
        # # END copy file

        # # START Init all layer
        # cd $layer
        # terragrunt init -upgrade
        # cd - > /dev/null 2>&1
        # # END Init all layer

        # # START update statefile with new provider
        # cd $layer
        # terragrunt state replace-provider 'registry/terraform-plugins/kubernetes-alpha' 'registry.terraform.io/hashicorp/kubernetes-alpha'
        # terragrunt state replace-provider 'registry/terraform-plugins/kustomization' 'registry.terraform.io/kbst/kustomization'
        # cd - > /dev/null 2>&1
        # # END update statefile with new provider

        # # START apply change
        # cd $layer
        # terragrunt apply
        # cd - > /dev/null 2>&1
        # # END apply change

      curl --request POST \
        --form "token=$GITLAB_CI_TRIGGER_TOKEN" \
        --form "ref=$CI_COMMIT_BRANCH" \
        --form "variables[REPO_DIR]=$layer" \
        "https://$CI_SERVER_URL/api/v4/projects/$CI_PROJECT_ID/trigger/pipeline"
      echo ""
      sleep 5
    done
    IFS=$OLDIFS
  else
    echo "Triggering pipeline "
    curl --request POST \
      --form "token=$GITLAB_CI_TRIGGER_TOKEN" \
      --form "ref=$CI_COMMIT_BRANCH" \
      --form "$triggerValues" \
      "https://$CI_SERVER_URL/api/v4/projects/$CI_PROJECT_ID/trigger/pipeline"
      echo ""
  fi
else
  echo "Unknown options given"
fi
