# Create Managed Kubernetes Landing zone
# For SP creaton via prompt: https://stackoverflow.com/questions/62111748/create-azure-application-through-az-module-and-assign-api-permissions-using-powe
# Notes:
# - Bring your own SP secret: https://www.avast.com/random-password-generat31pw3uTwHkiNh9FbftyXNAYvzqTQbBNed9sDor#mac (36 characters, all allowed)
# - The main RG Service Principal will have automated roles assignment
# - Other SP roles need to be assigned manually (SPs will be obsoleted in the future -> Managed Identities)

# Input Variables
$subscriptionName = "RUN, ESP Kubernetes Cluster (61673), PSP 9914.P01716.002.80"
# $subscriptionName = "CCF - CPS (APL207789) PSP 9914.P01715.002.80"
$kubernetes_domain = "aks-mgt-k8s"
$env="trn1"
$location = "westeurope"
# $failoverLocation = "northeurope"
$defaultTags = @{
  AssetID                = '10003'
  AssetLocation          = 'ESP Kubernetes Cluster 61673'
  AssetOperator          = 'CD DEN Team'
  AssetStatus            = 'InOperation'
  AssetUser              = 'Tenants'
  Classification         = 'very_high'
  ContactInfo            = 'foundationteam@eon.com'
  Owner                  = 'CD DEN Team'
  PSP                    = '9914.P00811.002.80'
  ProtectionResponsible  = 'CD DEN Team'
  RiskFactor             = 'high'
}

Connect-AzAccount
Import-Module Az.Resources
Import-Module Az.DataProtection # Install-Module Az.DataProtection
$tenant = Get-AzTenant
if($subscription = Get-AzSubscription | Where-Object {$_.Name -eq $subscriptionName}) {
  Set-AzContext -TenantId $tenant -SubscriptionId $subscription
  Write-Host @"
#################################################################
Connected to:
  tenant        : $($tenant)
  subscription  : $($subscription)
#################################################################
"@
} else {
  Write-Host "Subscription `"$($subscriptionName)`" not found. Check and try again. Exitting....."
  exit 1
}

# Script variables
$ErrorActionPreference = "Stop"
# $resourcesName = ($env -eq "prod") ? $kubernetes_domain : $kubernetes_domain + "_" + $env
$resourcesName = $kubernetes_domain + "_" + $env
$resourcesDNSName = $resourcesName -creplace "_", "-"
Write-Host "Environment is $($env). We take $($resourcesDNSName) as resourcesName for additional resources."

# Generate randomString used for unique resources names. Similar to the encoding used in Terraform (echo "$subscription" | openssl base64)
# Note: output to Write-Host might be truncated!!
$randomString = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($subscription))

$resourceGroup = "K8S_WEU_" + $env.ToUpper() + "_3.0_1"
$resourceGroupBkp = "K8S_WEU_" + $env.ToUpper() + "_BKP_3.0_1"

# #####################################################################################
# # Create a new resource group
# #####################################################################################
# if(!($azResourceGroup = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -eq $resourceGroup})) {
#   Write-Host "Creating resource groups `"$($resourceGroup)`""
#   $azResourceGroup = New-AzResourceGroup -Name $resourceGroup -Location $location -Tag $defaultTags
# } else {
#   Write-Host "NOTICE: Resource Group `"$($resourceGroup)`" exists. Continuing....."
# }
# if(!($azResourceGroupBkp = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -eq $resourceGroupBkp})) {
#   $azResourceGroupBkp = New-AzResourceGroup -Name $resourceGroupBkp -Location $location -Tag $defaultTags
#   Write-Host "Creating resource groups `"$($resourceGroupBkp)`""
# } else {
#   Write-Host "NOTICE: Resource Group `"$($resourceGroupBkp)`" exists. Continuing....."
# }

# #####################################################################################
# # Create Terraform backend storage account
# #####################################################################################
# $resourceNameUnique = ("tfbackend" + $env.ToLower() + $randomString -creplace "[^a-z0-9]", "").SubString(0,19)
# if(!($azStorageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup | Where-Object {$_.StorageAccountName -eq $resourceNameUnique})) {
#   Write-Host "Creating Terraform backend Storage Account `"$($resourceNameUnique)`""
#   $azStorageAccount = New-AzStorageAccount `
#   -ResourceGroupName $resourceGroup `
#   -Name $resourceNameUnique `
#   -Location $location `
#   -SkuName Standard_LRS `
#   -Kind StorageV2 `
#   -Tag $defaultTags
# } else {
#   Write-Host "NOTICE: Terraform backend Storage Account `"$($resourceNameUnique)`" exists. Continuing....."
# }
# if(!($azStorageContainer = Get-AzStorageContainer -Context $azStorageAccount.Context| Where-Object {$_.Name -eq $resourcesDNSName})) {
#   Write-Host "Creating Terraform backend Storage Container `"$($resourcesDNSName)`""
#   New-AzStorageContainer `
#   -Name $resourcesDNSName `
#   -Context $azStorageAccount.Context
# } else {
#   Write-Host "NOTICE: Terraform backend Storage Container `"$($resourcesDNSName)`" exists. Continuing....."
# }

# #####################################################################################
# # Create Backup Vault
# #####################################################################################
# $resourceNameUnique = $resourcesDNSName + "-backup-vault"
# if(!($azBkpVault = Get-AzDataProtectionBackupVault -ResourceGroupName $resourceGroupBkp | Where-Object {$_.Name -eq $resourceNameUnique})) {
#   Write-Host "Creating Backup Vault `"$($resourceNameUnique)`""
#   $storageSetting = New-AzDataProtectionBackupVaultStorageSettingObject -Type GeoRedundant -DataStoreType VaultStore
#   $azBkpVault = New-AzDataProtectionBackupVault `
#   -ResourceGroupName $resourceGroupBkp `
#   -VaultName $resourceNameUnique `
#   -Location $location `
#   -IdentityType SystemAssigned `
#   -StorageSetting $storageSetting `
#   -Tag $defaultTags
# } else {
#   Write-Host "NOTICE: Backup Vault `"$($resourceNameUnique)`" exists. Continuing....."
# }

#####################################################################################
# Create RG Service Principal
# Note: https://www.c-sharpcorner.com/blogs/azure-new-restrictions-to-azurewebsitesnet-domain
#####################################################################################
$spName = "SP_K8S_RG_WEU_" + $env.ToUpper() + "_3.0_1"
Write-Host "Setting up RG Service Principal $($spName)"
$spDNSName = $spName -creplace "[^A-Za-z0-9]", "-"
$appHomePageUrl = "api://" + $spDNSName
$appURI = $appHomePageUrl
if(!($azApp = Get-AzADApplication | Where-Object {$_.DisplayName -eq $spName})) {
  Write-Host "Registering Application `"$($spName)`""
  $azApp = New-AzADApplication -DisplayName $spName -IdentifierUris $appURI -Homepage $appHomePageUrl
  # Generate first password
  Write-Host "Generating secret for `"$($spName)`""
  $startDate = Get-Date
  $endDate = $startDate.AddYears(2)
  $scureString = Read-Host -Prompt 'Enter App Secret Key ' -AsSecureString
  New-AzADAppCredential -ObjectId $azApp.ObjectId  -StartDate $startDate -EndDate $endDate -Password $scureString
} else {
  Write-Host "NOTICE: Registration for Application `"$($spName)`" exists. Continuing....."
}

# if(!($azSp = Get-AzADServicePrincipal -ApplicationId $azApp.ApplicationId)) {
#   Write-Host "Assigning Service Principal to application`"$($spName)`""
#   $azSp = New-AzADServicePrincipal -ApplicationId $azApp.ApplicationId
#   # Work-around: Remove any role assignments that are being created by the New-AzADServicePrincipal (which is be default Contributor on subscription level!!)
#   # https://github.com/Azure/azure-powershell/issues/10963
#   Get-AzRoleAssignment -ObjectId $azSp.Id | ForEach-Object { $_ | Remove-AzRoleAssignment }
#   Write-Host "NOTICE: Role Assigning 'Contributor' removed again (work-around)"
#   Write-Host "NOTICE: Waiting for RG to be created....."
#   Start-Sleep -Seconds 60
#   Write-Host "Assigning 'Owner' to Resource Group `"$($resourceGroup)`""
#   New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroup
#   Write-Host @"
# #################################################################
# Service Principal information for $($azSp.DisplayName):
#   object_id     : $($azSp.Id)
#   client_id     : $($azSp.ApplicationId)
#   client_secret : ************************************
# #################################################################
# "@  
# } else {
#   Write-Host "NOTICE: Service Principal is already assigned to application `"$($spName)`". Continuing....."
# }

# # Manual regenerate password and/or re-assign role for existing Service Principal (comment in commands)
# Write-Host "Re-generating secret for `"$($spName)`""
# $startDate = Get-Date
# $endDate = $startDate.AddYears(2)
# $scureString = Read-Host -Prompt 'Enter App Secret Key ' -AsSecureString
# New-AzADAppCredential -ObjectId $azApp.ObjectId  -StartDate $startDate -EndDate $endDate -Password $scureString
# # Write-Host "Re-assigning 'Owner' to Resource Group `"$($resourceGroup)`""
# # New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroup

#####################################################################################
# Create AKS Service Principal. Comment when no longer needed
#####################################################################################
$spName = "SP_K8S_AKS_WEU_" + $env.ToUpper() + "_3.0_1"
Write-Host "Setting up AKS Service Principal $($spName)"
$spDNSName = $spName -creplace "[^A-Za-z0-9]", "-"
$appHomePageUrl = "api://" + $spDNSName
$appURI = $appHomePageUrl
if(!($azApp = Get-AzADApplication | Where-Object {$_.DisplayName -eq $spName})) {
  Write-Host "Registering Application `"$($spName)`""
  $azApp = New-AzADApplication -DisplayName $spName -IdentifierUris $appURI -Homepage $appHomePageUrl
  # Generate first password
  Write-Host "Generating secret for `"$($spName)`""
  $startDate = Get-Date
  $endDate = $startDate.AddYears(2)
  $scureString = Read-Host -Prompt 'Enter App Secret Key ' -AsSecureString
  New-AzADAppCredential -ObjectId $azApp.ObjectId  -StartDate $startDate -EndDate $endDate -Password $scureString
} else {
  Write-Host "NOTICE: Registration for Application `"$($spName)`" exists. Continuing....."
}

# if(!($azSp = Get-AzADServicePrincipal -ApplicationId $azApp.ApplicationId)) {
#   Write-Host "Assigning Service Principal to application`"$($spName)`""
#   $azSp = New-AzADServicePrincipal -ApplicationId $azApp.ApplicationId
#   # Work-around: Remove any role assignments that are being created by the New-AzADServicePrincipal (which is be default Contributor on subscription level!!)
#   # https://github.com/Azure/azure-powershell/issues/10963
#   Get-AzRoleAssignment -ObjectId $azSp.Id | ForEach-Object { $_ | Remove-AzRoleAssignment }
#   Write-Host "NOTICE: Role Assigning 'Contributor' removed again (work-around)"
#   # New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroup
#   Write-Host @"
# #################################################################
# Service Principal information for $($azSp.DisplayName):
#   object_id     : $($azSp.Id)
#   client_id     : $($azSp.ApplicationId)
#   client_secret : ************************************
# #################################################################
# "@  
# } else {
#   Write-Host "NOTICE: Service Principal is already assigned to application `"$($spName)`". Continuing....."
# }

# # Manual regenerate password for existing Service Principal (comment in commands)
# Write-Host "Re-generating secret for `"$($spName)`""
# $startDate = Get-Date
# $endDate = $startDate.AddYears(2)
# $scureString = Read-Host -Prompt 'Enter App Secret Key ' -AsSecureString
# New-AzADAppCredential -ObjectId $azApp.ObjectId  -StartDate $startDate -EndDate $endDate -Password $scureString

#####################################################################################
# Create MONITORING Service Principal
#####################################################################################
$spName = "SP_K8S_MONITORING_WEU_" + $env.ToUpper() + "_3.0_1" # Comment when no longer needed
Write-Host "Setting up MONITORING Service Principal $($spName)"
$spDNSName = $spName -creplace "[^A-Za-z0-9]", "-"
$appHomePageUrl = "api://" + $spDNSName
$appURI = $appHomePageUrl
if(!($azApp = Get-AzADApplication | Where-Object {$_.DisplayName -eq $spName})) {
  Write-Host "Registering Application `"$($spName)`""
  $azApp = New-AzADApplication -DisplayName $spName -IdentifierUris $appURI -Homepage $appHomePageUrl
  # Generate first password
  Write-Host "Generating secret for `"$($spName)`""
  $startDate = Get-Date
  $endDate = $startDate.AddYears(2)
  $scureString = Read-Host -Prompt 'Enter App Secret Key ' -AsSecureString
  New-AzADAppCredential -ObjectId $azApp.ObjectId  -StartDate $startDate -EndDate $endDate -Password $scureString
} else {
  Write-Host "NOTICE: Registration for Application `"$($spName)`" exists. Continuing....."
}
if(!($azSp = Get-AzADServicePrincipal -ApplicationId $azApp.ApplicationId)) {
  Write-Host "Assigning Service Principal to application`"$($spName)`""
  $azSp = New-AzADServicePrincipal -ApplicationId $azApp.ApplicationId
  # Work-around: Remove any role assignments that are being created by the New-AzADServicePrincipal (which is be default Contributor on subscription level!!)
  # https://github.com/Azure/azure-powershell/issues/10963
  Get-AzRoleAssignment -ObjectId $azSp.Id | ForEach-Object { $_ | Remove-AzRoleAssignment }
  Write-Host "NOTICE: Role Assigning 'Contributor' removed again (work-around)"
  # New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner  -ResourceGroupName $resourceGroup
  Write-Host @"
#################################################################
Service Principal information for $($azSp.DisplayName):
  object_id     : $($azSp.Id)
  client_id     : $($azSp.ApplicationId)
  client_secret : ************************************
#################################################################
"@  
} else {
  Write-Host "NOTICE: Service Principal is already assigned to application `"$($spName)`". Continuing....."
}
# # Manual regenerate password for existing Service Principal (comment in commands)
# Write-Host "Re-generating secret for `"$($spName)`""
# $startDate = Get-Date
# $endDate = $startDate.AddYears(2)
# $scureString = Read-Host -Prompt 'Enter App Secret Key ' -AsSecureString
# New-AzADAppCredential -ObjectId $azApp.ObjectId  -StartDate $startDate -EndDate $endDate -Password $scureString
