#!/usr/bin/env bash
# Script to fetch client information based on given credentials file.

# Prepare base variable declaration
now=$(date +%Y-%m-%d\ %H:%M:%S)
programName=$(basename $0)
programDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
baseName=$(echo ${programName} | sed -e 's/\.sh//g')
azCredentrialsDir="${HOME}/.azure/az-sp"
debug=0

Usage()
{
	echo "########################################################################################"
	echo "# "
	echo "# Script to fetch client information based on given credentials file."
	echo "# It relies on the default that the name of the client starts with the resource group name"
	echo "# "
	echo "# Usage: ${programName} -t <tenant> -r <resource_group> -debug"
	echo "# "
	echo "# Arguments:"
	echo "# -t         : The name of the customer/project where the cluster is deployed."
	echo "# -r         : The name of the resource group the cluster is deployed in."
  echo "# "
	echo "# Examples:"
	echo "# ${programName} -t eon -r esp-dev-jerome"
	echo "# "
	echo "# Defaults:"
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
		"-t"|"-tenant")
      [[ ${2} =~ "^-" || -z ${2} ]] && Usage || tenant="${2}"
      shift 2
			;;
		"-r")
      [[ ${2} =~ "^-" || -z ${2} ]] && Usage || resourceGroup="${2}"
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
  [ -z "${tenant}" ]  && echo "Tenant is to given. Exitting....." && Usage
  [ -z "${resourceGroup}" ]  && echo "Resource Group is to given. Exitting....." && Usage
}

_jq() {
  # $1: Row offered as base64
  # $2: Value to be selected
  echo ${1} | base64 --decode | jq -r ${2}
}

##########################
# Main script
##########################
ReadParams "$@"

[ ! -d ${azCredentrialsDir} ] && mkdir -p ${azCredentrialsDir}
[ ! -f ${azCredentrialsDir}/$tenant.sp.secret.json ] && echo "File ${azCredentrialsDir}/$tenant.sp.secret.json not present. Exitting....." && exit 5

currentAccount=$(az account show)
servicePinciple="${resourceGroup}-devops"
servicePincipleInstance="${resourceGroup}-aks"
spCredentials=$(cat ${azCredentrialsDir}/$tenant.sp.secret.json)

echo "# >>> Export service principal for execution of Terraform plans"
# Provisioning
# echo "export ARM_ENDPOINT=\"$(echo $spCredentials | jq -r --arg servicePinciple "$servicePinciple" '.[] | select(.displayName==$servicePinciple) | .name')\""
echo "export ARM_CLIENT_ID=\"$(echo $spCredentials | jq -r --arg servicePinciple "$servicePinciple" '.[] | select(.displayName==$servicePinciple) | .appId')\""
echo "export ARM_CLIENT_SECRET=\"$(echo $spCredentials | jq -r --arg servicePinciple "$servicePinciple" '.[] | select(.displayName==$servicePinciple) | .password')\""
echo "export ARM_SUBSCRIPTION_ID=\"$(echo $currentAccount | jq -r '.id')\""
echo "export ARM_TENANT_ID=\"$(echo $currentAccount | jq -r '.tenantId')\""
# Terraform
echo "# >>> Export service principal used by Terraform for provisioning of AKS"
echo "export TF_VAR_aks_service_principal_app_id=\"$(echo $spCredentials | jq -r --arg servicePincipleInstance "$servicePincipleInstance" '.[] | select(.displayName==$servicePincipleInstance) | .appId')\""
echo "export TF_VAR_aks_service_principal_client_secret=\"$(echo $spCredentials | jq -r --arg servicePincipleInstance "$servicePincipleInstance" '.[] | select(.displayName==$servicePincipleInstance) | .password')\""
echo "export TF_VAR_aks_service_principal_object_id=\"$(az ad sp list --filter "displayName eq '$servicePincipleInstance'" | jq -r '.[].objectId')\""
echo "# >>> Login with"
echo "az login --service-principal -u \$ARM_CLIENT_ID -p \$ARM_CLIENT_SECRET --tenant \$ARM_TENANT_ID"
