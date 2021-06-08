# Scripts used for the most common Azure operational tasks
resourceGroup=K8S_WEU_DEV_3.0_1
clusterName=aks-mgt-k8s-dev
object_reference=esp-owl

# Adding certificate
az network application-gateway ssl-cert create --resource-group $resourceGroup --gateway-name "$clusterName-app-gw" --cert-file $certpfxFile --cert-password $certpasswd \
  -n $certName

# Listing all certificate
az network application-gateway ssl-cert list --resource-group $resourceGroup --gateway-name "$clusterName-app-gw" | jq -r '.[].name'
az network application-gateway address-pool list --resource-group $resourceGroup --gateway-name "$clusterName-app-gw" | jq -r --arg object_reference "$object_reference" '.[] | select(.name | test(".*'${object_reference}'.*")) | .name,.backendAddresses'


# Investigate logs
# 403 Forbidden / Microsoft-Azure-Application-Gateway/v2
https://docs.microsoft.com/en-us/azure/application-gateway/log-analytics

# 502 Bad Gateweay
https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-troubleshooting-502


# Get all pubic IPs
for env in sbx dev pre prod; do
  [[ "$env" == "pre" ]] && resourceGroup="K8S_WEU_PREPROD_3.0_1" || resourceGroup="K8S_WEU_$(echo $env | tr '[:lower:]' '[:upper:]')_3.0_1"
  clusterName=aks-mgt-k8s-$env
  echo "$clusterName"
  az network public-ip show -g $resourceGroup -n "$clusterName-app-gw-pip" | jq -r '.ipAddress'
done
