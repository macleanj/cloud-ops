#!/usr/bin/env bash
# 2020.08.28: Jerome Mac Lean - CrossLogic Consulting
# 
# Script to switch between Terraform workspaces having potentially completely different backends.

# Prepare base variable declaration
now=$(date +%Y-%m-%d\ %H:%M:%S)
programName=$(basename $0)
programDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
baseName=$(echo ${programName} | sed -e 's/.sh//g')
TF_STATEFILE_LOCATION="remote"
debug=0

declare -A clusterSubscriptions
# Currently all the same subscription
clusterSubscriptionsAAD="RUN, EONDATA (61673)"
clusterSubscriptions[dev]="RUN, ESP Kubernetes Cluster (61673)"
clusterSubscriptions[pre]="RUN, ESP Kubernetes Cluster (61673)"
clusterSubscriptions[prod]="RUN, ESP Kubernetes Cluster (61673)"

Usage()
{
	echo "########################################################################################"
	echo "# "
	echo "# Script to switch between Terraform workspaces having potentially completely different remote backends."
	echo "# "
	echo "# Usage: ${programName} [arg] <defined tf workspace in ./environments> -debug"
	echo "# "
	echo "# Arguments:"
	echo "# -local     : Switch local statefile"
	echo "# -cfg       : tf_workspaces.cfg in the environment directory"
  echo "# "
	echo "# Examples:"
	echo "# ${programName} -cfg environments/tf_workspaces.cfg pre"
	echo "# ${programName} -local -cfg environments/tf_workspaces.cfg dev"
	echo "# "
	echo "# Defaults:"
	echo "# Remote backend statefile will be used from ./environments/<tf workspace>"
	echo "# "
	echo "########################################################################################"
	exit 5
}

# Read and/or validate command-line parameters
ReadParams()
{
	[ $# -eq 0 ] && Usage

	while [ $# -gt 0 ]
	do
		case ${1}	in
		"-local")
      TF_STATEFILE_LOCATION=$(echo ${1} | sed -e 's/^-//g')
      shift 1
			;;
		"-cfg")
      TF_WORKSPACE_CFG=${2}
      shift 2
			;;
    "-debug")
      debug=1
      shift 1
      ;;
		*)
			TF_WORKSPACE_ENVIRONMENT=${1}
      shift 1
			;;
		esac
 	done

  # Obligated fields
	[ -z ${TF_WORKSPACE_CFG} ] && echo "No tf_workspaces.cfg given. Exitting....." && Usage
}

##########################
# Main script
##########################
ReadParams "$@"

[[ ! -f ${TF_WORKSPACE_CFG} ]] && echo "ERROR: Environment config file does not exist. Exitting....." && exit 4
TF_WORKSPACE_DIR=$(dirname ${TF_WORKSPACE_CFG})
readarray CFG_TF_WORKSPACE_ENVIRONMENTS < <(printf '%s, ' $(cat ${TF_WORKSPACE_CFG} | grep -v default | sed -e 's/.*__\([^_]*\)$/\1/g'))
readarray CFG_TF_WORKSPACE_NAMES < ${TF_WORKSPACE_CFG}
[[ -f ${TF_WORKSPACE_DIR}/../.terraform/environment ]] && TF_INITIALIZED=1 || TF_INITIALIZED=0
[ $TF_INITIALIZED -eq 1 ] && LIVE_TF_WORKSPACE_NAMES=($(terraform workspace list | egrep -v "^[ ]*$" | sed -e 's/^[* ]*//g')) || LIVE_TF_WORKSPACE_NAMES=()

[ -z ${TF_WORKSPACE_ENVIRONMENT} ] && echo "ERROR: No environment given. Please offer ${CFG_TF_WORKSPACE_ENVIRONMENTS}or dev as argument. Exitting....." && exit 5
[[ ${TF_WORKSPACE_ENVIRONMENT} == "dev" ]] && TF_WORKSPACE_NAME="default" || TF_WORKSPACE_NAME=$(cat ${TF_WORKSPACE_CFG} | egrep "__${TF_WORKSPACE_ENVIRONMENT}$")
[ -z ${TF_WORKSPACE_NAME} ] && echo "ERROR: Environment ${TF_WORKSPACE_ENVIRONMENT} does not exist in ${TF_WORKSPACE_CFG}. Exitting....." && exit 6

if [[ ! -d "${TF_WORKSPACE_DIR}/${TF_WORKSPACE_ENVIRONMENT}" ]]; then
  echo "ERROR: The environment '${TF_WORKSPACE_ENVIRONMENT}' doesn't exist under ${TF_WORKSPACE_DIR}"
  echo "ERROR: The following environments are available:"
  ls -1 ${TF_WORKSPACE_DIR} | grep -v cfg
  exit 1
fi

if [[ "${TF_STATEFILE_LOCATION}" == "local" ]]; then
  # Local statefile
  TF_WORKSPACE_ARG=""
elif [[ -f ${TF_WORKSPACE_DIR}/${TF_WORKSPACE_ENVIRONMENT}/backend.config ]]; then
  # Remote statefile: configure the backend
  TF_WORKSPACE_ARG="-reconfigure -backend-config=${TF_WORKSPACE_DIR}/${TF_WORKSPACE_ENVIRONMENT}/backend.config"
else
  echo "ERROR: The backend configuration is missing at ${TF_WORKSPACE_DIR}/${TF_WORKSPACE_ENVIRONMENT}/backend.config! Did you missed the -local option?"
  exit 2
fi

# Switching workspace
[ $TF_INITIALIZED -eq 1 ] && echo "Switching Terraform ${TF_STATEFILE_LOCATION} workspace from $(cat ${TF_WORKSPACE_DIR}/../.terraform/environment) to ${TF_WORKSPACE_NAME}" || echo "Initializing Terraform ${TF_STATEFILE_LOCATION} workspace ${TF_WORKSPACE_NAME}"

# Make Terraform think it has already switched to the new Terraform workspace.
# In that case the statefile is not created in the previous backend but created/found in the new/desired backend.
mkdir -p .terraform && echo "${TF_WORKSPACE_NAME}" > ${TF_WORKSPACE_DIR}/../.terraform/environment

# The -reconfigure option essentially means “ignore any previously-initialized backend”. 
terraform init ${TF_WORKSPACE_ARG} . > /dev/null 2>&1
terraform get -update

# Because of the "-reconfigure" option Terraform will "forget" about the workspaces and a new one needs to be created every time. Which is OK.
if [[ ! " ${LIVE_TF_WORKSPACE_NAMES[@]} " =~ .*" ${TF_WORKSPACE_NAME} ".* ]]; then
  [ $debug == 1 ] && echo "Terraform workspace ${TF_WORKSPACE_NAME} not found. Creating..... "
  terraform workspace new ${TF_WORKSPACE_NAME} > /dev/null 2>&1
fi

# #########################################
# # Work-around for kubernetes-alpha not being able to process variables.
# #########################################
# if ls ${TF_WORKSPACE_DIR}/../provider-kubernetes-kubeconfig.* 1> /dev/null 2>&1; then
#   # Update pointer to the correct kubeconfig file for that environment
#   cp ${TF_WORKSPACE_DIR}/../provider-kubernetes-kubeconfig.${TF_WORKSPACE_ENVIRONMENT} ${TF_WORKSPACE_DIR}/../provider-kubernetes-kubeconfig.name
# fi

az account clear
az login

# Active Directory Subscription
if [[ ! "$PWD" =~ _prerequisites ]]; then
	subscriptionIdAAD=$(az account list | jq -r --arg input "${clusterSubscriptionsAAD}" '.[] | select(.name | startswith($input)) | .id')
	if [ "$subscriptionIdAAD" == "" ] || [ "$subscriptionIdAAD" == "null" ]; then
		echo "ERROR: Subscription ${clusterSubscriptionsAAD} not found. No rights?"
		exit 2
	fi
	tenantIdAAD=$(az account list | jq -r --arg input "${clusterSubscriptionsAAD}" '.[] | select(.name | startswith($input)) | .tenantId')
	az account set --subscription $subscriptionIdAAD
	clusterAdminsGroupId=$(az ad group show -g "aks-mgt-k8s-${TF_WORKSPACE_ENVIRONMENT}-cluster-admins" | jq -r '.objectId')
	tenantAdminsSubscriptionGroupId=$(az ad group show -g "aks-mgt-k8s-${TF_WORKSPACE_ENVIRONMENT}-tenant-admins-subscription-group" | jq -r '.objectId')
	tenantUsersSubscriptionGroupId=$(az ad group show -g "aks-mgt-k8s-${TF_WORKSPACE_ENVIRONMENT}-tenant-users-subscription-group" | jq -r '.objectId')
fi

# Resource Provisioning Subscription
mgtK8sServicePrincipals=$(az ad sp list --filter "startswith(displayName,'aks-mgt-k8s')")
subscriptionId=$(az account list | jq -r --arg input "${clusterSubscriptions[$TF_WORKSPACE_ENVIRONMENT]}" '.[] | select(.name | startswith($input)) | .id')
if [ "$subscriptionId" == "" ]; then
	echo "ERROR: Subscription ${clusterSubscriptions[$TF_WORKSPACE_ENVIRONMENT]} not found. No rights?"
	exit 2
fi
tenantId=$(az account list | jq -r --arg input "${clusterSubscriptions[$TF_WORKSPACE_ENVIRONMENT]}" '.[] | select(.name | startswith($input)) | .tenantId')
clientId=$(echo $mgtK8sServicePrincipals | jq -r --arg env "$TF_WORKSPACE_ENVIRONMENT" '.[] | select(.displayName | endswith("\($env)-devops")) | .appId')
clientKey=$(az keyvault secret show --vault-name aks-mgt-k8s-dev -n aks-mgt-k8s-${TF_WORKSPACE_ENVIRONMENT}-devops | jq -r '.value')

clientIdAks=$(echo $mgtK8sServicePrincipals | jq -r --arg env "$TF_WORKSPACE_ENVIRONMENT" '.[] | select(.displayName | endswith("\($env)-aks")) | .appId')
clientKeyAks=$(az keyvault secret show --vault-name aks-mgt-k8s-dev -n aks-mgt-k8s-${TF_WORKSPACE_ENVIRONMENT}-aks | jq -r '.value')
objectIdAks=$(echo $mgtK8sServicePrincipals | jq -r --arg env "$TF_WORKSPACE_ENVIRONMENT" '.[] | select(.displayName | endswith("\($env)-aks")) | .objectId')

# Data mapping for export
echo
az account set --subscription $subscriptionId

if [[ ! "$PWD" =~ _prerequisites ]]; then
	# _prerequisites need to be executed as owner, not as service principal user.

	az login --service-principal -u $ARM_CLIENT_ID -p $clientKey --tenant $tenantId
	echo ">>>>> Run (copy/paste) the following exports to select the correct subscription and tenant (do not forget to fill in the password):"
	echo "export ARM_SUBSCRIPTION_ID=\"$subscriptionId\""
	echo "export ARM_TENANT_ID=\"$tenantId\"" # breaks the az client in _prerequisites somehow!!

	if [ ! "$clientId" == "" ]; then
		# For Azure resource access as service principle
		echo "export ARM_CLIENT_ID=\"$clientId\""
		echo "export ARM_CLIENT_SECRET=\"$clientKey\""
		# For AKS with AAD integration (non-interactive)
		echo "export AAD_SERVICE_PRINCIPAL_CLIENT_ID=\"$clientId\""
		echo "export AAD_SERVICE_PRINCIPAL_CLIENT_SECRET=\"$clientKey\""
	fi

	echo "export TF_VAR_aad_cluster_admins_group_id=\"$clusterAdminsGroupId\""
	echo "export TF_VAR_aad_tenant_admins_subscription_group_id=\"$tenantAdminsSubscriptionGroupId\""
	echo "export TF_VAR_aad_tenant_users_subscription_group_id=\"$tenantUsersSubscriptionGroupId\""

	if [[ "$PWD" =~ cluster.*cluster$ ]]; then
		if [ ! "$clientIdAks" == "" ] && [ ! "$objectIdAks" == "" ]; then
			echo "export TF_VAR_aks_service_principal_app_id=\"$clientIdAks\""
			echo "export TF_VAR_aks_service_principal_client_secret=\"$clientKeyAks\""
			echo "export TF_VAR_aks_service_principal_object_id=\"$objectIdAks\""
		fi
	else
		export KUBECONFIG_BASE="kubeconfig_cluster-admin"
		export KUBECONFIG="${KUBECONFIG_BASE}-aad.yml"
		az aks get-credentials -g "aks-mgt-k8s-$TF_WORKSPACE_ENVIRONMENT" -n "aks-mgt-k8s-$TF_WORKSPACE_ENVIRONMENT" -f "${KUBECONFIG_BASE}.yml" --overwrite-existing > /dev/null 2>&1
		cp "${KUBECONFIG_BASE}.yml" "${KUBECONFIG}"
		kubelogin convert-kubeconfig -l spn
		echo "export KUBECONFIG=\"${KUBECONFIG}\""
	fi
	# echo "az login --service-principal -u \$ARM_CLIENT_ID -p \$ARM_CLIENT_SECRET --tenant \$ARM_TENANT_ID"
	echo
fi
