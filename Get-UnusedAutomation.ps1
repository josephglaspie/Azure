#Start Time
$start=get-date

#Connect to azure
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in txo Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Create CSV with data
$filedate =  (($($start).ToString("s").Replace(":","-") -split "T")[0]) -replace "-",""
$filename="unused_$filedate.csv"

$results=Get-AzureRmSubscription | where-object {$_.Name -like "*SUBSCRIPTION_NAME*"} | ForEach-Object {
    Select-AzureRmSubscription -Subscription $_ | Out-Null
    $allDisks=$null
    $unManaged=$null
    $deallocatedVms=$null
    $allDisks=Get-AzureRmDisk
    $deallocatedVms=get-azurermvm -Status | ? {$_.PowerState -eq 'VM deallocated'}
    $unManaged = $allDisks | Where-Object {$_.ManagedBy -eq $null}
    foreach($disk in $allDisks){
        New-Object -TypeName psobject -Property ([ordered]@{
            name = $disk.name
            sku = $disk.sku.Tier
            resourcegroupname = $disk.ResourceGroupName
            disksizegb = $disk.disksizegb
            timecreated = $disk.timecreated
            connected = if($disk.ManagedBy -eq $null){
                         "False"
                        }elseif(
                          $deallocatedVms.id -contains $disk.ManagedBy){
                         "DeallocatedVM"
                        }else{
                         "True"
                        }
            subscription = $_.Name
        })
    }
}

$unManaged = $results | ? {$_.connected -ne "True"}
$stor=0
foreach($unManage in $unManaged){$stor += $unManage.DiskSizeGB}
[int]$monthly = ($stor / 4000) * 450

$Body = "Unused Totals:`n$(($results.count).ToString("N0")) disks total`n$(($unmanaged.count).ToString("N0")) are unmanaged or deallocated`n$(($stor).ToString("N0"))`(GB) of unused storage`n~ `$$(($monthly).tostring("N0"))/month`n" 
$results | export-csv -notypeinformation -path $filename

#Send email
$sendgridpw = Get-AutomationVariable -Name sendgridpw
$Username = Get-AutomationVariable -Name sendgridname
$Password = ConvertTo-SecureString $sendgridpw -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $Username, $Password
$SMTPServer = "smtp.sendgrid.net"
$EmailFrom = "AzureAdmin-noreply@email.com"
[string[]]$EmailTo = "Email1@email.com","email2@email.com"  #"AddToEmailAddressessHere. To add multiple use comma separated values."
$Subject = "UnusedResources $filedate"

Send-MailMessage -smtpServer $SMTPServer -Credential $credential -Usessl -Port 587 -from $EmailFrom -to $EmailTo -subject $Subject -Body $Body -BodyAsHtml -attachment $filename

#Output time taken to run
$end=get-date
$totaltime=$end-$start
write-output "This took: $totaltime"