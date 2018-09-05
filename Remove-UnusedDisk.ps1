$unUsedDisks = Import-Csv '/Users/jxg2980/Downloads/disks_6-5.csv'   
$interlineSubs = Get-AzureRmSubscription | where-object {$_.Name -like "*interline*"} 

ForEach($interlineSub in $interlineSubs){
    
    foreach($unUsedDisk in $unUsedDisks){
        
        if($unUsedDisk.subscription -eq $interlineSub.name){
           $disk = Get-AzureRmDisk | Where-Object {$_.Name -eq $unUsedDisk.name} 
           $disk | Remove-AzureRmDisk -Confirm:0
           Write-Verbose "Deleting Disk $($unusedDisk.name) on Sub: $($interlineSub.name)" -Verbose
        }
    }
}