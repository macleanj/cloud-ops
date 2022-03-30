# Create virtual machine in existing network for troubleshooting
# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-powershell
# Debugging (left button with the bug) to run interactively.

$user = "jerome"
$purpose = "network_debugging"
$dateHR = (Get-Date).ToString("yyyyMMdd")
$resourcesName = $user + "_" + $purpose + "_" + $dateHR
$resourcesDNSName = $resourcesName -replace "_", "-"
Write-Host "We take $($resourcesName) as resourcesName for additional resources."

# Input Variables
$tenant = ""
$subscription = ""
$resourceGroup = $resourcesName
$location = "westeurope"
$virtualNetworkName = "$($resourcesName)_vnet"
$virtualNetworkAddressPrefix = "10.101.0.0/16"
$subnetName = "$($purpose)_subnet"
$subnetAddressPrefix = "10.101.0.0/24"
$publicIpAddressName = "$($resourcesName)_pip"
$publicIpAddressNameDnsPrefix = "$($resourcesDNSName)-$(Get-Random)-pip"
$securityGroupName = "$($resourcesName)_nsg"
$nicName = "$($resourcesName)_nic"
$vmName = "$($resourcesDNSName)-vm"
$vmSize = "Standard_D2s_v3"
$vmImage = "18.04-LTS"
$azureuserSshPublicKeyLocation = "/Users/jerome/Services/System/Config/cred/azure-vm-azureuser-custom-rsa.pub"

#####################################################################################
# Connect to subscription. Can be comented after first login.
#####################################################################################
# Connect-AzAccount -Tenant $tenant -SubscriptionId $subscription

#####################################################################################
# Create a new resource group
#####################################################################################
Write-Output -InputObject "Creating resource group $($resourceGroup)"
New-AzResourceGroup -Name $resourceGroup -Location $location

#####################################################################################
# Create virtual network resources
#####################################################################################
Write-Output -InputObject "Create virtual network resources"

# Create a subnet configuration
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
  -Name $subnetName `
  -AddressPrefix $subnetAddressPrefix

# Create a virtual network
$vnet = New-AzVirtualNetwork `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -Name $virtualNetworkName `
  -AddressPrefix $virtualNetworkAddressPrefix `
  -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzPublicIpAddress `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -Sku "Basic" `
  -AllocationMethod Dynamic `
  -Name $publicIpAddressName `
  -DomainNameLabel $publicIpAddressNameDnsPrefix

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
  -Name "SSH_TCP_Inbound"  `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority 1000 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 22 `
  -Access "Allow"

# Create an inbound network security group rule for port 80
$nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
  -Name "HTTP_TCP_Inbound"  `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority 1001 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80 `
  -Access "Allow"

# Create a network security group
$nsg = New-AzNetworkSecurityGroup `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -Name $securityGroupName `
  -SecurityRules $nsgRuleSSH,$nsgRuleWeb

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzNetworkInterface `
  -Name $nicName `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -SubnetId $vnet.Subnets[0].Id `
  -PublicIpAddressId $pip.Id `
  -NetworkSecurityGroupId $nsg.Id

#####################################################################################
# Create a virtual machine
#####################################################################################
Write-Output -InputObject "Create a virtual machine"

# Define a credential object
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

# Create a virtual machine configuration
$vmConfig = New-AzVMConfig `
  -VMName $vmName `
  -VMSize $vmSize | `
Set-AzVMOperatingSystem `
  -Linux `
  -ComputerName $vmName `
  -Credential $cred `
  -DisablePasswordAuthentication | `
Set-AzVMSourceImage `
  -PublisherName "Canonical" `
  -Offer "UbuntuServer" `
  -Skus $vmImage `
  -Version "latest" | `
Add-AzVMNetworkInterface `
  -Id $nic.Id | `
Set-AzVMBootDiagnostic `
  -disable

# Configure the SSH key
$sshPublicKey = cat $azureuserSshPublicKeyLocation
Add-AzVMSshPublicKey `
  -VM $vmconfig `
  -KeyData $sshPublicKey `
  -Path "/home/azureuser/.ssh/authorized_keys"

New-AzVM `
-ResourceGroupName $resourceGroup `
-Location $location `
-VM $vmConfig

$azureuserSshPrivateKeyLocation = $azureuserSshPublicKeyLocation -replace "pub", "pem"
$givenPublicIpAddress= (Get-AzPublicIpAddress -ResourceGroupName $resourceGroup -Name $publicIpAddressName)
Write-Output -InputObject "##### CONNECT: ssh -i $($azureuserSshPrivateKeyLocation) azureuser@$($givenPublicIpAddress.IpAddress)"

#####################################################################################
# Cleanup
#####################################################################################
# Remove-AzResourceGroup -Name $resourceGroup
