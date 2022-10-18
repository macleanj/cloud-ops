#!/usr/bin/env pwsh
# Create Platform Landing zone
# For SP creaton via prompt: https://stackoverflow.com/questions/62111748/create-azure-application-through-az-module-and-assign-api-permissions-using-powe
#
# Resource
# - Resource Group
# - Resource Group Backup (skipped)
# - TF backend Storage Accout and Container
# - Backup Vault (skipped)
# - Service Principal RG (incl RG Owner assignment)
# - Service Principal AKS (skipped, obsolete)
# - Service Principal MONITORING (skipped)
#
# Notes:
# - Bring your own SP secret is no longer supported....

# Input Variables
$tenantId         = '27d2fc0b-1403-47b9-bef5-f339ada03080'
$subscriptionName = 'ADB Safegate - Cortex - Dev'


# Aligned with config
# # enva
# $resourceGroup           = 'plt_ctx_enva'
# $resourceGroupBackup     = 'plt_ctx_enva_bkp'
# $region                  = 'westeurope'
# $regionFailover          = 'northeurope'
# $environment             = 'enva'
# $resourcesName           = 'ctx-enva'
# p-euw1-01
$resourceGroup           = 'plt_ctx_p_euw1_01'
$resourceGroupBackup     = 'plt_ctx_p_euw1_01_bkp'
$region                  = 'westeurope'
$regionFailover          = 'northeurope'
$environment             = 'p-euw1-01'
$resourcesName           = 'ctx-p-euw1-01'

$defaultTags = @{
  AssetID                = '12345'
  AssetLocation          = 'My AssetLocation'
  AssetOperator          = 'My AssetLocation'
  AssetStatus            = 'InOperation'
  AssetUser              = 'Tenants'
  Classification         = 'low'
  ContactInfo            = 'platform_contact@cegeka.com'
  Owner                  = 'CEGEKA'
  PSP                    = 'NA'
  ProtectionResponsible  = 'CEGEKA'
  RiskFactor             = 'low'
}

function Base64EncodeString {
  param ( $String )
  $Bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
  [Convert]::ToBase64String($Bytes)
}

Connect-AzAccount -TenantId $tenantId
Import-Module Az.Resources
Import-Module Az.DataProtection # Install-Module Az.DataProtection
if($subscriptionId = Get-AzSubscription | Where-Object {$_.Name -eq $subscriptionName}) {
  Set-AzContext -TenantId $tenantId -SubscriptionId $subscriptionId
  Write-Host @"
#################################################################
Connected to:
  tenant        : $($tenantId)
  subscription  : $($subscriptionId)
#################################################################
"@
} else {
  Write-Host "Subscription `"$($subscriptionName)`" not found. Check and try again. Exitting....."
  exit 1
}

# Script variables
$ErrorActionPreference = "Stop"
$resourcesDNSName = $resourcesName -creplace "_", "-"

# Generate randomString used for unique resources names. Similar to the encoding used in Terraform (echo "$subscriptionId" | openssl base64)
# Note: output to Write-Host might be truncated!!
$randomString = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($subscriptionId))

#####################################################################################
# Create a new resource group
#####################################################################################
# Main Resource Group
if(!($azResourceGroup = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -eq $resourceGroup})) {
  Write-Host "Creating resource groups `"$($resourceGroup)`""
  $azResourceGroup = New-AzResourceGroup -Name $resourceGroup -Location $region -Tag $defaultTags
} else {
  Write-Host "NOTICE: Resource Group `"$($resourceGroup)`" exists. Continuing....."
}
# Backup 
# if(!($azResourceGroupBackup = Get-AzResourceGroup | Where-Object {$_.ResourceGroupName -eq $resourceGroupBackup})) {
#   $azResourceGroupBackup = New-AzResourceGroup -Name $resourceGroupBackup -Location $region -Tag $defaultTags
#   Write-Host "Creating resource groups `"$($resourceGroupBackup)`""
# } else {
#   Write-Host "NOTICE: Resource Group `"$($resourceGroupBackup)`" exists. Continuing....."
# }

#####################################################################################
# Create Terraform backend storage account
#####################################################################################
$resourceNameUnique = ("tf" + $resourceGroup.ToLower() + $randomString -creplace "[^a-z0-9]", "").SubString(0,24)
if(!($azStorageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup | Where-Object {$_.StorageAccountName -eq $resourceNameUnique})) {
  Write-Host "Creating Terraform backend Storage Account `"$($resourceNameUnique)`""
  $azStorageAccount = New-AzStorageAccount `
  -ResourceGroupName $resourceGroup `
  -Name $resourceNameUnique `
  -Location $region `
  -SkuName Standard_LRS `
  -Kind StorageV2 `
  -Tag $defaultTags
} else {
  Write-Host "NOTICE: Terraform backend Storage Account `"$($resourceNameUnique)`" exists. Continuing....."
}
if(!($azStorageContainer = Get-AzStorageContainer -Context $azStorageAccount.Context| Where-Object {$_.Name -eq $resourcesDNSName})) {
  Write-Host "Creating Terraform backend Storage Container `"$($resourcesDNSName)`""
  New-AzStorageContainer `
  -Name $resourcesDNSName `
  -Context $azStorageAccount.Context
} else {
  Write-Host "NOTICE: Terraform backend Storage Container `"$($resourcesDNSName)`" exists. Continuing....."
}

# #####################################################################################
# # Create Backup Vault
# #####################################################################################
# $resourceNameUnique = $resourcesDNSName + "-backup-vault"
# if(!($azBkpVault = Get-AzDataProtectionBackupVault -ResourceGroupName $resourceGroupBackup | Where-Object {$_.Name -eq $resourceNameUnique})) {
#   Write-Host "Creating Backup Vault `"$($resourceNameUnique)`""
#   $storageSetting = New-AzDataProtectionBackupVaultStorageSettingObject -Type GeoRedundant -DataStoreType VaultStore
#   $azBkpVault = New-AzDataProtectionBackupVault `
#   -ResourceGroupName $resourceGroupBackup `
#   -VaultName $resourceNameUnique `
#   -Location $region `
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
$spName = 'SP_' + $resourceGroup.ToUpper() + '_RG' -creplace '-', '_'
Write-Host "Setting up RG Service Principal $($spName)"
$spDNSName = $spName.ToLower() -creplace "[^A-Za-z0-9]", "-"
$appHomePageUrl = "api://" + $spDNSName
$appURI = $appHomePageUrl
if(!($azApp = Get-AzADApplication | Where-Object {$_.DisplayName -eq $spName})) {
  Write-Host "Registering Application `"$($spName)`""
  $azApp = New-AzADApplication -DisplayName $spName -IdentifierUris $appURI -Homepage $appHomePageUrl
  # Generate first password
  Write-Host "Generating secret for `"$($spName)`""
  $startDate = Get-Date
  $endDate = $startDate.AddYears(2)
  New-AzADAppCredential -ObjectId $azApp.Id -StartDate $startDate -EndDate $endDate -CustomKeyIdentifier (Base64EncodeString -String 'landing zone')
} else {
  Write-Host "NOTICE: Registration for Application `"$($spName)`" exists. Continuing....."
}

if(!($azSp = Get-AzADServicePrincipal -ApplicationId $azApp.AppId)) {
  Write-Host "Assigning Service Principal to application`"$($spName)`""
  $azSp = New-AzADServicePrincipal -ApplicationId $azApp.AppId

  # Work-around: Remove any role assignments that are being created by the New-AzADServicePrincipal (which is be default Contributor on subscription level!!)
  # https://github.com/Azure/azure-powershell/issues/10963
  Write-Host "NOTICE: Role Assigning 'Contributor' removed again (work-around)"
  Get-AzRoleAssignment -ObjectId $azSp.Id | ForEach-Object { $_ | Remove-AzRoleAssignment }

  Write-Host "NOTICE: Give time for the Service Principal to be published....."
  Start-Sleep -Seconds 60
  Write-Host "Assigning 'Owner' to Resource Group `"$($resourceGroup)`""
  New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner -Scope ('/subscriptions/' + $subscriptionId + '/resourceGroups/' + $resourceGroup)
  Write-Host @"
#################################################################
Service Principal information for $($azSp.DisplayName):
  object_id     : $($azSp.Id)
  client_id     : $($azSp.AppId)
  client_secret : See above
#################################################################
"@  
} else {
  Write-Host "NOTICE: Service Principal is already assigned to application `"$($spName)`". Continuing....."
}

# ##### Manual regenerate password and/or re-assign role for existing Service Principal (comment in commands)
# Write-Host "Re-generating secret for `"$($spName)`""
# $startDate = Get-Date
# $endDate = $startDate.AddYears(2)
# New-AzADAppCredential -ObjectId $azApp.Id -StartDate $startDate -EndDate $endDate -CustomKeyIdentifier (Base64EncodeString -String 'landing zone')
# Write-Host "Re-assigning 'Owner' to Resource Group `"$($resourceGroup)`""
# New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner -Scope ('/subscriptions/' + $subscriptionId + '/resourceGroups/' + $resourceGroup)

# #####################################################################################
# # Create AKS Service Principal. Comment when no longer needed
# #####################################################################################
# $spName = 'SP_' + $resourceGroup.ToUpper() + '_AKS' -creplace '-', '_'
# Write-Host "Setting up AKS Service Principal $($spName)"
# $spDNSName = $spName.ToLower() -creplace "[^A-Za-z0-9]", "-"
# $appHomePageUrl = "api://" + $spDNSName
# $appURI = $appHomePageUrl
# if(!($azApp = Get-AzADApplication | Where-Object {$_.DisplayName -eq $spName})) {
#   Write-Host "Registering Application `"$($spName)`""
#   $azApp = New-AzADApplication -DisplayName $spName -IdentifierUris $appURI -Homepage $appHomePageUrl
#   # Generate first password
#   Write-Host "Generating secret for `"$($spName)`""
#   $startDate = Get-Date
#   $endDate = $startDate.AddYears(2)
#   New-AzADAppCredential -ObjectId $azApp.Id -StartDate $startDate -EndDate $endDate -CustomKeyIdentifier (Base64EncodeString -String 'landing zone')
# } else {
#   Write-Host "NOTICE: Registration for Application `"$($spName)`" exists. Continuing....."
# }

# if(!($azSp = Get-AzADServicePrincipal -ApplicationId $azApp.AppId)) {
#   Write-Host "Assigning Service Principal to application`"$($spName)`""
#   $azSp = New-AzADServicePrincipal -ApplicationId $azApp.AppId

#   # Work-around: Remove any role assignments that are being created by the New-AzADServicePrincipal (which is be default Contributor on subscription level!!)
#   # https://github.com/Azure/azure-powershell/issues/10963
#   Write-Host "NOTICE: Role Assigning 'Contributor' removed again (work-around)"
#   Get-AzRoleAssignment -ObjectId $azSp.Id | ForEach-Object { $_ | Remove-AzRoleAssignment }

#   # Role Assignments
#   # Write-Host "NOTICE: Give time for the Service Principal to be published....."
#   # Start-Sleep -Seconds 60
#   # Write-Host "Assigning 'Owner' to Resource Group `"$($resourceGroup)`""
#   # New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner -Scope ('/subscriptions/' + $subscriptionId + '/resourceGroups/' + $resourceGroup)
#   Write-Host @"
# #################################################################
# Service Principal information for $($azSp.DisplayName):
#   object_id     : $($azSp.Id)
#   client_id     : $($azSp.AppId)
#   client_secret : See above
# #################################################################
# "@  
# } else {
#   Write-Host "NOTICE: Service Principal is already assigned to application `"$($spName)`". Continuing....."
# }

# # ##### Manual regenerate password and/or re-assign role for existing Service Principal (comment in commands)
# # Write-Host "Re-generating secret for `"$($spName)`""
# # $startDate = Get-Date
# # $endDate = $startDate.AddYears(2)
# # New-AzADAppCredential -ObjectId $azApp.Id -StartDate $startDate -EndDate $endDate -CustomKeyIdentifier (Base64EncodeString -String 'landing zone')
# # Write-Host "Re-assigning 'Owner' to Resource Group `"$($resourceGroup)`""
# # New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner -Scope ('/subscriptions/' + $subscriptionId + '/resourceGroups/' + $resourceGroup)

# #####################################################################################
# # Create MONITORING Service Principal
# #####################################################################################
# $spName = 'SP_' + $resourceGroup.ToUpper() + '_MONITORING' -creplace '-', '_'
# Write-Host "Setting up MONITORING Service Principal $($spName)"
# $spDNSName = $spName.ToLower() -creplace "[^A-Za-z0-9]", "-"
# $appHomePageUrl = "api://" + $spDNSName
# $appURI = $appHomePageUrl
# if(!($azApp = Get-AzADApplication | Where-Object {$_.DisplayName -eq $spName})) {
#   Write-Host "Registering Application `"$($spName)`""
#   $azApp = New-AzADApplication -DisplayName $spName -IdentifierUris $appURI -Homepage $appHomePageUrl
#   # Generate first password
#   Write-Host "Generating secret for `"$($spName)`""
#   $startDate = Get-Date
#   $endDate = $startDate.AddYears(2)
#   New-AzADAppCredential -ObjectId $azApp.Id -StartDate $startDate -EndDate $endDate -CustomKeyIdentifier (Base64EncodeString -String 'landing zone')
# } else {
#   Write-Host "NOTICE: Registration for Application `"$($spName)`" exists. Continuing....."
# }

# if(!($azSp = Get-AzADServicePrincipal -ApplicationId $azApp.AppId)) {
#   Write-Host "Assigning Service Principal to application`"$($spName)`""
#   $azSp = New-AzADServicePrincipal -ApplicationId $azApp.AppId

#   # Work-around: Remove any role assignments that are being created by the New-AzADServicePrincipal (which is be default Contributor on subscription level!!)
#   # https://github.com/Azure/azure-powershell/issues/10963
#   Write-Host "NOTICE: Role Assigning 'Contributor' removed again (work-around)"
#   Get-AzRoleAssignment -ObjectId $azSp.Id | ForEach-Object { $_ | Remove-AzRoleAssignment }

#   # Role Assignments
#   # Write-Host "NOTICE: Give time for the Service Principal to be published....."
#   # Start-Sleep -Seconds 60
#   # Write-Host "Assigning 'Owner' to Resource Group `"$($resourceGroup)`""
#   # New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner -Scope ('/subscriptions/' + $subscriptionId + '/resourceGroups/' + $resourceGroup)
#   Write-Host @"
# #################################################################
# Service Principal information for $($azSp.DisplayName):
#   object_id     : $($azSp.Id)
#   client_id     : $($azSp.AppId)
#   client_secret : See above
# #################################################################
# "@  
# } else {
#   Write-Host "NOTICE: Service Principal is already assigned to application `"$($spName)`". Continuing....."
# }

# # ##### Manual regenerate password and/or re-assign role for existing Service Principal (comment in commands)
# # Write-Host "Re-generating secret for `"$($spName)`""
# # $startDate = Get-Date
# # $endDate = $startDate.AddYears(2)
# # New-AzADAppCredential -ObjectId $azApp.Id -StartDate $startDate -EndDate $endDate -CustomKeyIdentifier (Base64EncodeString -String 'landing zone')
# # Write-Host "Re-assigning 'Owner' to Resource Group `"$($resourceGroup)`""
# # New-AzRoleAssignment -ObjectId $azSp.Id -RoleDefinitionName Owner -Scope ('/subscriptions/' + $subscriptionId + '/resourceGroups/' + $resourceGroup)