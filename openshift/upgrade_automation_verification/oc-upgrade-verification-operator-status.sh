#!/usr/bin/env bash
# https://docs.openshift.com/container-platform/4.17/operators/admin/olm-status.html

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

name=${1}
namespace=${2}
CatalogSourcesUnhealthyExpected='False' # Mind: this is reversed logic!!!

CatalogSourcesUnhealthy=$(oc get sub -n "${namespace}" "${name}" -o json | jq -r '.status.conditions[0].status')
if [ $CatalogSourcesUnhealthy == $CatalogSourcesUnhealthyExpected ]; then
    status_message="${GREEN}OK${NC}"
else
    status_message="${RED}Not OK${NC}"
    oc get sub -n "${namespace}" "${name}" -o json | jq -r '.status.conditions[0]'
fi

printf "Operator status: $status_message"
if [ "$status_message" != "${GREEN}OK${NC}" ]; then exit 1; fi
