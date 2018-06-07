Function Test-Print
{
    Param(
        # Parameter help description
        [Parameter(Position = 0)]
        [String]
        $PrintMe
    )
    Write-Host "$($PrintMe)"
}
# -- Azure Login Check --
Function Get-AzureLoginCheck
{
    Param(
        # Parameter help description
        [Parameter(Position = 0)]
        [String]
        $Subscription
    )
    if($Subscription -ne ""){
        try
        {
            $subscriptionDetails = Get-AzureRmSubscription -SubscriptionName $Subscription
            if ($subscriptionDetails.Count -ge 1)
            {
                try
                {
                   Select-AzureRmSubscription -Subscription $subscriptionDetails.ID -Verbose
                }
                catch
                {
                    Write-Host "Stopping Script Choose Right Subscription"
                    break
                }
            }
        }
        catch
        {
            Write-Host "Looks like you've not logged in" -BackgroundColor Magenta
            Login-AzureRmAccount
            Get-AzureLoginCheck
        }
    }
    elseif($Subscription -ne $null){
    $i = 0
    $subscriptionHash = @()
        try
        {
            $subscriptionDetails = Get-AzureRmSubscription
            if ($subscriptionDetails.Count -ge 1)
            {
                Write-Host 'Indexno,SubscriptionName,SubscriptionID,SubscriptionState' -BackgroundColor DarkCyan
                $subscriptionDetails | % {
                    Write-Host "$($i),$($_.Name),$($_.Id),$($_.State)" -ForegroundColor Green
                    $subscriptionHash += @{"Indexno" = $i; "SubscriptionName" = $_.Name; "SubscriptionID" = $_.Id; "SubscriptionState" = $_.State}
                    $i++
                }
                #Write-Output $subscriptionHash
                try
                {
                    [int]$Indexno = Read-Host "More Subscriptions Identified. Choose Right Index Number:"

                    Select-AzureRmSubscription -Subscription $subscriptionHash[$Indexno].SubscriptionID -Verbose
                }
                catch
                {
                    Write-Host "Stopping Script Choose Right Subscription"
                    break
                }
                # return $subscriptionHash
            }
            else
            {
                $subscriptionHash = @{"Indexno" = $i; "SubscriptionName" = $_.Name; "SubscriptionID" = $_.Id; "SubscriptionState" = $_.State}
                return $subscriptionHash
            }
        }
        catch
        {
            Write-Host "Looks like you've not logged in" -BackgroundColor Magenta
            Login-AzureRmAccount
            Get-AzureLoginCheck
        }
    }

}

Function Get-VMAllDisks
{
    Param(
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $VMDetails
    )



}

Function Get-StorageDetails
{
    Param(

        [string]$Location,
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$SKU

    )

    if ((Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) -eq $null)
    {

        # Create the storage account.
        $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName `
            -Name $StorageAccountName `
            -Location $Location `
            -SkuName $SKU

        # Retrieve the context.
        Return (Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName)
    }
    else
    {
        Return (Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName)
    }
}

Function Copy-SnapshotToStorageAccount
{
    Param(
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]
        $Snapshot,
        # Parameter help description
        [Parameter(Position = 1)]
        [Int]
        $MigrationTime = 36000,
        [Parameter(Mandatory = $true, Position = 2)]
        [psobject]
        $StorageAccount,
        [Parameter(Mandatory = $true)]
        [string]$TargetResourceGroupName,
        # Account Type
        [ValidateSet('StandardLRS', 'PremiumLRS')]
        [string]
        $AccountType = "PremiumLRS",
        # Target Azure Region
        [Parameter(Mandatory = $true)]
        [string]
        $TargetImageLocation
    )

    $snapSasUrl = Grant-AzureRmSnapshotAccess -ResourceGroupName $Snapshot.ResourceGroupName -SnapshotName $Snapshot.Name -DurationInSecond 36000 -Access Read

    $targetStorageContext = (Get-AzureRmStorageAccount -ResourceGroupName $TargetResourceGroupName -Name $StorageAccount.StorageAccountName).Context
    try
    {
        $null = New-AzureStorageContainer -Name ($($Snapshot.Name) + "-Container").ToLower() -Context $targetStorageContext -Permission Container -ErrorAction Ignore
    }
    Catch [Microsoft.WindowsAzure.Commands.Storage.Blob.Cmdlet.RemoveAzureStorageContainerCommand.]
    {
        if ($_.Exception.Message -match 'ResourceAlreadyExistException')
        {
            Write-Error "Resource Already Exists"
        }
        else
        {
            break
        }
    }
    # Copying to Target Region Storage Container

    $null = Start-AzureStorageBlobCopy -AbsoluteUri $snapSasUrl.AccessSAS -DestContainer ($($Snapshot.Name) + "-Container").ToLower() -DestContext $targetStorageContext -DestBlob ($($Snapshot.Name) + "-Blob").ToLower()
    $null = Get-AzureStorageBlobCopyState -Container ($($Snapshot.Name) + "-Container").ToLower() -Blob ($($Snapshot.Name) + "-Blob").ToLower() -Context $targetStorageContext -WaitForComplete
    $DiskVhdUri = ($targetStorageContext.BlobEndPoint + ($($Snapshot.Name) + "-Container").ToLower() + "/" + ($($Snapshot.Name) + "-Blob").ToLower())

    $snapshotConfig = New-AzureRmSnapshotConfig -AccountType $AccountType `
        -OsType Windows `
        -Location $TargetImageLocation `
        -CreateOption Import `
        -SourceUri $DiskVhdUri `
        -StorageAccountId (Get-AzureRmStorageAccount -Name $StorageAccount.StorageAccountName -ResourceGroupName $TargetResourceGroupName).Id

    $null = if ((New-AzureRmSnapshot -ResourceGroupName $TargetResourceGroupName -SnapshotName ($($Snapshot.Name) + "-" + $($TargetImageLocation.Replace(" ", ""))) -ErrorAction Ignore) -ne $null)
    {New-AzureRmSnapshot -ResourceGroupName $TargetResourceGroupName -SnapshotName ($($Snapshot.Name) + "-" + $($TargetImageLocation.Replace(" ", ""))) -Snapshot $snapshotConfig
    }

    $tartSSN = ($($Snapshot.Name) + "-" + $($TargetImageLocation.Replace(" ", "")))

    Return "$tartSSN"
}

Function New-SnapshotTargetResourceGroup
{
    Param(
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject]
        $Snapshot,
        # Parameter help description
        [Parameter(Position = 1)]
        [Int]
        $MigrationTime = 36000,
        [Parameter(Mandatory = $true, Position = 2)]
        [psobject]
        $StorageAccount,
        [Parameter(Mandatory = $true)]
        [string]$TargetResourceGroupName,
        # Account Type
        [ValidateSet('StandardLRS', 'PremiumLRS')]
        [string]
        $AccountType = "PremiumLRS",
        # Target Azure Region
        [Parameter(Mandatory = $true)]
        [string]
        $TargetImageLocation
    )

    $targetStorageContext = (Get-AzureRmStorageAccount -ResourceGroupName $TargetResourceGroupName -Name $StorageAccount.StorageAccountName).Context

    ($($Snapshot.Name) + "-Container").ToLower()
    ($($Snapshot.Name) + "-Blob").ToLower()

    $DiskVhdUri = ($targetStorageContext.BlobEndPoint + ($($Snapshot.Name) + "-Container").ToLower() + "/" + ($($Snapshot.Name) + "-Blob").ToLower())

    $snapshotConfig = New-AzureRmSnapshotConfig -AccountType $AccountType `
        -OsType Windows `
        -Location $TargetImageLocation `
        -CreateOption Import `
        -SourceUri $DiskVhdUri `
        -StorageAccountId (Get-AzureRmStorageAccount -Name $StorageAccount.StorageAccountName -ResourceGroupName $TargetResourceGroupName).Id

    $null = if ((New-AzureRmSnapshot -ResourceGroupName $TargetResourceGroupName -SnapshotName ($($Snapshot.Name) + "-" + $($TargetImageLocation.Replace(" ", ""))) -ErrorAction Ignore) -ne $null)
    {New-AzureRmSnapshot -ResourceGroupName $TargetResourceGroupName -SnapshotName ($($Snapshot.Name) + "-" + $($TargetImageLocation.Replace(" ", ""))) -Snapshot $snapshotConfig
    }

    $tartSSN = ($($Snapshot.Name) + "-" + $($TargetImageLocation.Replace(" ", "")))

    Return "$tartSSN"
}
Function Create-TargetImage
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string[]]$SnapShots,

        # Target Azure Region
        [Parameter(Mandatory = $true)]
        [string]
        $TargetImageLocation,

        [Parameter(Mandatory = $true)]
        [string]
        $targetimageName,

        # Account Type
        [ValidateSet('StandardLRS', 'PremiumLRS')]
        [string]
        $AccountType = "PremiumLRS"
    )

    $imageConfig = New-AzureRmImageConfig -Location $TargetImageLocation
    $i = 1
    foreach ($tssn in $SnapShots)
    {

        if ($tssn -match "OSDisk")
        {
            $snap = Get-AzureRmSnapshot -ResourceGroupName $TargetResourceGroupName -SnapshotName $tssn
            Set-AzureRmImageOsDisk -Image $imageConfig `
                -OsType Windows `
                -OsState Generalized `
                -SnapshotId $snap.Id
        }
        else
        {
            $datasnap = Get-AzureRmSnapshot -ResourceGroupName $TargetResourceGroupName -SnapshotName $tssn
            Add-AzureRmImageDataDisk -Image $imageConfig -Lun $i -SnapshotId $datasnap.Id -StorageAccountType $AccountType
            $i++
        }

    }

    New-AzureRmImage -ResourceGroupName $TargetResourceGroupName `
        -ImageName $targetimageName `
        -Image $imageConfig

}


Export-ModuleMember -Function '*'
