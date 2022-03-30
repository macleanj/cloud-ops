#please run the module install commandlets with admin previleges 
# Please run the install commands only when you do not have these modules installed
install Az.Resources module  
Install-Module -Name Az.Resources -RequiredVersion 4.4.1 -AllowClobber 
#If Module is not imported please import if after installation
Import-Module Az.Storage
 
 
# Set these variables according to your convenience.
$resourceGroup="RG0111"
$tenantID
$location="eastus"
$storageAccountName="autoloaderdemo777"
$appName="autoloader777"
$uri="api://"+$appName
$homePageURL="http://www.microsoft.com"
$filesystemName = "incoming"
$incomingDirName = "file/"
$checkpointDirName = "StreamCheckpoint/"
$deltaDirName = "delta/"
$schemaDirName = "schema/"
$mntPoint="mnt/rajaniesh"
 
#First create a resource group
Connect-AzAccount
New-AzResourceGroup -Name $resourceGroup -Location $location
$tenantID=(Get-AzTenant).TenantId[0].ToString()
 
# Create Datalake Gen2 
$storageAccount =New-AzStorageAccount -ResourceGroupName $resourceGroup `
  -Name $storageAccountName `
  -Location $location `
  -SkuName Standard_LRS `
  -Kind StorageV2 `
  -EnableHierarchicalNamespace $True
 
$accessKey=(Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -AccountName $storageAccountName).GetValue(0)  
$Context = $storageAccount.Context
 
# Create Container in Datalake Gen2 
New-AzStorageContainer -Context $Context -Name $filesystemName -Permission Off
 
#Create a directory named file in Datalake Gen2
New-AzDataLakeGen2Item -Context $Context -FileSystem $filesystemName -Path $incomingDirName -Directory
 
 
#Create a directory named StreamCheckpoint in Datalake Gen2
New-AzDataLakeGen2Item -Context $Context -FileSystem $filesystemName -Path $checkpointDirName -Directory
 
#Create a directory named delta in Datalake Gen2
New-AzDataLakeGen2Item -Context $Context -FileSystem $filesystemName -Path $deltaDirName -Directory
 
#Create a directory named schema in Datalake Gen2
New-AzDataLakeGen2Item -Context $Context -FileSystem $filesystemName -Path $schemaDirName -Directory
  
#Create a Service principle 
Connect-AzureAD -TenantId $tenantID
$azureADAppReg=New-AzADApplication  -DisplayName $appName -HomePage $homePageURL -IdentifierUris $uri
$secret = (New-AzureADApplicationPasswordCredential  -ObjectId $azureADAppReg.ObjectId  -CustomKeyIdentifier mysecret -StartDate (Get-Date) -EndDate ((Get-Date).AddYears(6))).value 
 
 
$clientID=$azureADAppReg.ApplicationId
$servicePrincipal=New-AzureADServicePrincipal -AppId $clientID
$subscriptionID=(Get-AzSubscription -TenantId $tenantID).id
$storageAccountResourceType=(Get-AzResource -Name $storageAccountName).ResourceId
 
 
#Add Role assignment for resource Group
New-AzRoleAssignment  `
-ApplicationId $servicePrincipal.AppId  `
-RoleDefinitionName "EventGrid EventSubscription Contributor" `
-ResourceGroupName $resourceGroup
  
  
  
#Add Role assignment for Storage account
New-AzRoleAssignment  `
-ApplicationId $servicePrincipal.AppId  `
-RoleDefinitionName "Storage Blob Data Contributor" `
-Scope $storageAccountResourceType
 
#Add Role assignment for Storage account
New-AzRoleAssignment  `
-ApplicationId $servicePrincipal.AppId  `
-RoleDefinitionName "Contributor" `
-Scope $storageAccountResourceType
 
#Add Role assignment for Storage account
New-AzRoleAssignment  `
-ApplicationId $servicePrincipal.AppId  `
-RoleDefinitionName "Storage Queue Data Contributor" `
-Scope $storageAccountResourceType
 
#Python code generation starts from here
$PythonCodeBlock = @'
 
configs = {"fs.azure.account.auth.type": "OAuth",
          "fs.azure.account.oauth.provider.type": "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider",
          "fs.azure.account.oauth2.client.id": "clientID",
          "fs.azure.account.oauth2.client.secret":"clsecret",
          "fs.azure.account.oauth2.client.endpoint": "https://login.microsoftonline.com/tenantID/oauth2/token"}
 
# Please run the mount command only once after that you do not have to run it otherwise it willl throw error
dbutils.fs.mount(
  source = "abfss://filesystemName@storageAccountName.dfs.core.windows.net/",
  mount_point = "/mnt/",
  extra_configs = configs)
 
 
 
from pyspark.sql.functions import *
from pyspark.sql import *
from pyspark.sql.types import StringType, IntegerType, StructType, StructField, TimestampType, DoubleType, DateType;
from pyspark.sql.types import *
 
  
#InputDirectory and Checkpoint Location
SourceFilePath = "/mnt/file/" 
CheckpointPath = "/mnt/StreamCheckpoint/" 
WritePath = "/mnt/delta/" 
schemaLocation= "/mnt/schema/"
 
#Define Schema for the Incoming files
schema = StructType([StructField('Employee_First_Name', StringType(), True),
                     StructField('Employee_Last_Name', StringType(), True),
                     StructField('Date_Of_Joining', DateType(), True)]
                       )
dbutils.fs.unmount("/mnt/rajaniesh/")
readquery = (spark.readStream.format("cloudFiles")
  .option("cloudFiles.format", "csv")
  .option("header", "true")
  .option("cloudFiles.useNotifications" , "true")
  .option("cloudFiles.includeExistingFiles", "true")
  .option("cloudFiles.resourceGroup", "ResourceGroup")
  .option("cloudFiles.subscriptionId", "subscriptionID")
  .option("cloudFiles.tenantId", "tenantID")
  .option("cloudFiles.clientId","clientID")
  .option("cloudFiles.clientSecret","clsecret") 
  .schema(schema)
  .option("mergeSchema", "true")
  .option("cloudFiles.schemaLocation",schemaLocation)
  .load(SourceFilePath)
            )
 
readquery.writeStream.trigger(once=True).format('delta').option('checkpointLocation', CheckpointPath).start(WritePath)
 
#You can write the below line of code into another cell of databricks
import time
time.sleep(15)
df = spark.read.format('delta').load(WritePath)
df.count()
'@
$FinalCodeBlock=$PythonCodeBlock.`
Replace("clientID",$clientID).
Replace("ResourceGroup",$resourceGroup).`
Replace("clsecret",$secret).`
Replace("tenantID",$tenantID).` 
Replace("subscriptionID",$subscriptionID).`
Replace("filesystemName",$filesystemName).`
Replace("incomingDirName",$incomingDirName).`
Replace("checkpointDirName",$checkpointDirName).`
Replace("deltaDirName",$deltaDirName).`
Replace("schemaDirName",$schemaDirName).`
Replace("accessKey",$accessKey.value).`
Replace("storageAccountName",$storageAccountName).`
Replace("mnt",$mntPoint)
 
$FinalCodeBlock | out-file code.txt