$resourceGroupName = "your primary resource group name"
$webappname = "your primary web app name"
$targetResourceGroupName = "your secondary resource group name"
$targetWebappName = "your secondary web app name"
$trafficManagerProfileName = "your Traffic Manager Profile name"
$trafficManagerEndpoint = "your Traffic Manager secondary endpoint name"
$slotName = "staging"

# Retrieve backup configuration
Write-Output "Retrieving backup configuration..."
$backupConfig = Get-AzWebAppBackupConfiguration -ResourceGroupName $resourceGroupName -Name $webappname

# Create new backup
Write-Output "Creating backup of primary site..."
$backup = New-AzWebAppBackup -ResourceGroupName $resourceGroupName -Name $webappname -StorageAccountUrl $backupConfig.StorageAccountUrl

# Check status of the backup that are complete or currently executing.
do
{
    Start-Sleep -Seconds 60
    $backup = Get-AzWebAppBackup -ResourceGroupName $resourceGroupName -Name $webappname -BackupId $backup.BackupId
} until ($backup.BackupStatus -ne "InProgress")

if ($backup.BackupStatus -eq "Succeeded")
{
    Write-Output "Backup of primary site succeeded!"
    
    # Disable Traffic Manager Endpoint
    Write-Output "Disabling Traffic Manager Endpoint for secondary site..."
    $disableResult = Disable-AzTrafficManagerEndpoint -Name $trafficManagerEndpoint -Type AzureEndpoints -ProfileName $trafficManagerProfileName -ResourceGroupName $resourceGroupName -Force
    if ($disableResult)
    {
        # Restore backup to secondary site
        Write-Output "Restoring backup to secondary site..."
        Restore-AzWebAppBackup -ResourceGroupName $targetResourceGroupName -Name $targetWebappName -StorageAccountUrl $backupConfig.StorageAccountUrl -BlobName $backup.BlobName -Slot $slotName -Overwrite
        Start-Sleep -Seconds 900

        # Swap slots
        az webapp deployment slot swap  -g $targetResourceGroupName -n $targetWebappName --slot $slotName --target-slot production
        Write-Output "Restore of backup to secondary site succeeded!"

        # Enable Traffic Manager Endpoint
        Write-Output "Enabling Traffic Manager Endpoint for secondary site..."
        $enableResult = Enable-AzTrafficManagerEndpoint -Name $trafficManagerEndpoint -Type AzureEndpoints -ProfileName $trafficManagerProfileName -ResourceGroupName $resourceGroupName
    }
}
