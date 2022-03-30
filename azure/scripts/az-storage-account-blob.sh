exit 11

resourceGroup=K8S_WEU_SBX_3.0_1
# resourceGroup=K8S_WEU_DEV_3.0_1
# resourceGroup=K8S_WEU_PREPROD_3.0_1
# resourceGroup=K8S_WEU_PROD_3.0_1

# Copy blob: https://thecodeblogger.com/2019/12/05/copying-azure-blobs-from-one-storage-account-to-another/
# Main vault
########################################################################
# SBX
########################################################################
# Vault(s)
SOURCE_STORAGE_NAME=3j58berrm2
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-auditevent
DESTINATION_STORAGE_NAME=aksmgtk8ssbx0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

# Public IP -> Not logging at the moment.

# App GW
SOURCE_STORAGE_NAME=47injs0tk4
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-applicationgatewayaccesslog
DESTINATION_STORAGE_NAME=aksmgtk8ssbx0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# App GW-WAF
SOURCE_STORAGE_NAME=47injs0tk4
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-applicationgatewayfirewalllog
DESTINATION_STORAGE_NAME=aksmgtk8ssbx0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

# AKS Cluster - API server
SOURCE_STORAGE_NAME=2pnw26661y
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-apiserver
DESTINATION_STORAGE_NAME=aksmgtk8ssbx0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# AKS Cluster - Audit
SOURCE_STORAGE_NAME=2pnw26661y
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-audit
DESTINATION_STORAGE_NAME=aksmgtk8ssbx0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# AKS Cluster - AuditAdmin
SOURCE_STORAGE_NAME=2pnw26661y
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-audit-admin
DESTINATION_STORAGE_NAME=aksmgtk8ssbx0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

########################################################################
# DEV
########################################################################
# Vault(s)
SOURCE_STORAGE_NAME=7bj7uv1mp9
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-auditevent
DESTINATION_STORAGE_NAME=aksmgtk8sdev0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

# Public IP -> Not logging at the moment.

# App GW
SOURCE_STORAGE_NAME=62a22gylgt
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-applicationgatewayaccesslog
DESTINATION_STORAGE_NAME=aksmgtk8sdev0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# App GW-WAF
SOURCE_STORAGE_NAME=62a22gylgt
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-applicationgatewayfirewalllog
DESTINATION_STORAGE_NAME=aksmgtk8sdev0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

# AKS Cluster - API server
SOURCE_STORAGE_NAME=jnfeevzlua
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-apiserver
DESTINATION_STORAGE_NAME=aksmgtk8sdev0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# AKS Cluster - Audit
SOURCE_STORAGE_NAME=jnfeevzlua
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-audit
DESTINATION_STORAGE_NAME=aksmgtk8sdev0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# AKS Cluster - AuditAdmin
SOURCE_STORAGE_NAME=jnfeevzlua
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-audit-admin
DESTINATION_STORAGE_NAME=aksmgtk8sdev0logging0nji
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

########################################################################
# PROD
########################################################################
# Vault(s)
SOURCE_STORAGE_NAME=xxxxxxxxxxx
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-auditevent
DESTINATION_STORAGE_NAME=aksmgtk8sprod0logging0nj
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

# Public IP -> Not logging at the moment.

# App GW
SOURCE_STORAGE_NAME=3lo8vf4e2z
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-applicationgatewayaccesslog
DESTINATION_STORAGE_NAME=aksmgtk8sprod0logging0nj
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# App GW-WAF
SOURCE_STORAGE_NAME=3lo8vf4e2z
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-applicationgatewayfirewalllog
DESTINATION_STORAGE_NAME=aksmgtk8sprod0logging0nj
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

# AKS Cluster - API server
SOURCE_STORAGE_NAME=fzs0mzyyzo
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-apiserver
DESTINATION_STORAGE_NAME=aksmgtk8sprod0logging0nj
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# AKS Cluster - Audit
SOURCE_STORAGE_NAME=fzs0mzyyzo
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-audit
DESTINATION_STORAGE_NAME=aksmgtk8sprod0logging0nj
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER
# AKS Cluster - AuditAdmin
SOURCE_STORAGE_NAME=fzs0mzyyzo
SOURCE_KEY=
SOURCE_CONTAINER=insights-logs-kube-audit-admin
DESTINATION_STORAGE_NAME=aksmgtk8sprod0logging0nj
DESTINATION_KEY=
DESTINATION_CONTAINER=$SOURCE_CONTAINER

# Copy command
az storage blob copy start-batch \
  --source-account-name "$SOURCE_STORAGE_NAME" \
  --source-account-key "$SOURCE_KEY" \
  --source-container "$SOURCE_CONTAINER" \
  --account-name  "$DESTINATION_STORAGE_NAME" \
  --account-key "$DESTINATION_KEY" \
  --destination-container "$DESTINATION_CONTAINER"
az storage blob list --account-name "$DESTINATION_STORAGE_NAME" --account-key "$DESTINATION_KEY" --container-name "$DESTINATION_CONTAINER" | jq -r '.[].name'
