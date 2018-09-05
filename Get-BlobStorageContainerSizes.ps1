<#
.Synopsis

Gathers container and blob info from Azure storage account and dumps it into Excel Spreadsheet. 

.EXAMPLE
Install-Module ImportExcel
Import-Module ImportEcel
Get-ContainersAndBlobs -Subscription 'SUBSCRIPTION' -StorageRG 'RESOURCE_GROUP' -StorageName 'STORAGE_ACCOUNT' -verbose
#>
function Get-ContainersAndBlobs {
    [CmdletBinding()]

    param(
        $Subscription,
        $StorageRG,
        $StorageName,
        $path = "$pwd/$StorageName-info.xlsx"
        )

    #Get blob and list conainters
    Select-AzureRmSubscription $Subscription
    $stor=Get-AzureRmStorageAccount -ResourceGroupName $StorageRG -Name $StorageName
    $ctx=$stor.Context
    Set-AzureRmCurrentStorageAccount -Context $ctx
    $containers=Get-AzureStorageContainer
    Write-Verbose "Gathering CONTAINER info"
    $c=foreach($container in $containers){
        $length=(Get-AzureStorageBlob -Container $($container.name)| %{ $_.Length } | measure -Sum).sum/1024/1024
        New-Object -TypeName psobject -Property $([ordered]@{
            Container = $container.Name
            Size_MB = $(($length).ToString("N0"))
            Last_Modified = $container.LastModified.DateTime
        })
    }

    #List container blobs
    Write-Verbose "Gathering BLOB info this might take some time"
    $b=foreach($container in $containers){
            $blobs=Get-AzureStorageBlob -Container $container.name 
            foreach($blob in $blobs){
                $length=$blob.Length/1024/1024
                New-Object -TypeName psobject -Property $([ordered]@{
                    Blob = $blob.Name
                    Type = $blob.blobtype
                    Size_MB = $(($length).ToString("N0"))
                    Last_Modified = $blob.LastModified.DateTime
                    Container = $container.Name
           })
        }   
    }
    #Create Excel Spreadsheet
    Write-Verbose "Adding CONTAINER info to spreadsheet $($path)"
    $c | Export-Excel -Path $path -WorksheetName Containers
    Write-Verbose "Adding BLOB info to spreadsheet $($path) might take some time"
    $b | Export-Excel -Path $path -WorksheetName Blobs #took 6 minutes on 128TB storage account
}

