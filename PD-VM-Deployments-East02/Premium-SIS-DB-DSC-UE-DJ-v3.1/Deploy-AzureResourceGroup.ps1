#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] $ResourceGroupLocation = 'East US',
    [string] $SubscriptionName = 'PS-EXT-PD-02-SNGL',
    [string] $ResourceLocation = 'East US',
    [string] $ResourceGroupName = 'SIS-PD-ST-02-BE-RG001',
    [switch] $UploadArtifacts = $true,
    [string] $StorageAccountName = "sispd02sragrssa002",
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts',
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '.',
    [string] $DSCSourceFolder = 'DSC',
    # Virtual Machine Name
    [Parameter(Mandatory = $true)]
    [string[]] $AzureVMNames,
    [switch] $ValidateOnly = $false
)
CD $PSScriptRoot
Import-Module '..\..\Scripts\AzureImageFunctions.psm1'
Get-AzureLoginCheck -Subscription $SubscriptionName

foreach ($AzureVMName in $AzureVMNames) {
    try {
        [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
    }
    catch { }

    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 3
    Select-AzureRmSubscription -Subscription $SubscriptionName

    function Format-ValidationOutput {
        param ($ValidationOutput, [int] $Depth = 0)
        Set-StrictMode -Off
        return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
    }

    #region OptionalParameters Information Goes Here...
    $OptionalParameters = New-Object -TypeName Hashtable
    $OptionalParameters['vmName'] = $AzureVMName
    $OptionalParameters['diagnosticsStorageAccountName'] = $StorageAccountName
    $OptionalParameters['diagnosticsStorageAccountId'] = (Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName).Id
    $OptionalParameters['timeZone'] = "Central Standard Time"
    $OptionalParameters['resourceLocation'] = 'East US'
    $OptionalParameters['virtualNetworkResourceGroup'] = 'TIER-PD-NW-02-T0-RG001'
    $OptionalParameters['virtualNetworkName'] = 'PS-EXT-PD-SNGL-02-VN001'
    $OptionalParameters['subnetName'] = 'SIS-DB-SN002-172.21.104.0_21'
    $OptionalParameters['domainToJoin'] = "powerschool.host"
    $OptionalParameters['domainUsername'] = "sundeep.paluru"
    ##Golden Image Value
    $OptionalParameters['templateResourceID'] = '/subscriptions/8e7f0b90-1e44-4729-a2d3-a85c4fdc3625/resourceGroups/SIS-PD-IM-02-T0-RG001/providers/Microsoft.Compute/images/SISPDDB02WIMG001'
    ##Key Vault
    $OptionalParameters['domainPassword'] = (Get-AzureKeyVaultSecret -VaultName 'PS-EXT-PD-SNGL-KV01' -Name 'ServiceAdminCred').SecretValue
    $OptionalParameters['adminPassword'] = (Get-AzureKeyVaultSecret -VaultName 'PS-EXT-PD-SNGL-KV01' -Name '00SISPDAPPWXXX').SecretValue
    $OptionalParameters['pIPAddress'] = Powershell -file ..\..\Scripts\Set-IPAllocator.ps1 -Path ..\..\Scripts\SIS-DB-SN002-172.21.104.0_21.csv -HostName ($AzureVMName + "-Nic")
    $OptionalParameters['sIPAddress'] = Powershell -file ..\..\Scripts\Set-IPAllocator.ps1 -Path ..\..\Scripts\SIS-DB-SN002-172.21.104.0_21.csv -HostName ($AzureVMName + "-BNic")

    #$OptionalParameters['pIPAddress'] = "172.21.104.55"
    #$OptionalParameters['sIPAddress'] = "172.21.104.56"

    #endregion

    $TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
    $TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

    if ($UploadArtifacts) {
        # Convert relative paths to absolute paths if needed
        $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
        $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

        # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present
        $JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
        if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
            $JsonParameters = $JsonParameters.parameters
        }
        $ArtifactsLocationName = '_artifactsLocation'
        $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
        $OptionalParameters[$ArtifactsLocationName] = $JsonParameters | Select -Expand $ArtifactsLocationName -ErrorAction Ignore | Select -Expand 'value' -ErrorAction Ignore
        $OptionalParameters[$ArtifactsLocationSasTokenName] = $JsonParameters | Select -Expand $ArtifactsLocationSasTokenName -ErrorAction Ignore | Select -Expand 'value' -ErrorAction Ignore

        # Create DSC configuration archive
        if (Test-Path $DSCSourceFolder) {
            $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | ForEach-Object -Process {$_.FullName})
            foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
                $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
                Publish-AzureRmVMDscConfiguration $DSCSourceFilePath -OutputArchivePath $DSCArchiveFilePath -Force -Verbose
            }
        }

        # Create a storage account name if none was provided
        if ($StorageAccountName -eq '') {
            $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
        }

        $StorageAccount = (Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $StorageAccountName})

        # Create the storage account if it doesn't already exist
        if ($StorageAccount -eq $null) {
            $StorageResourceGroupName = $ResourceGroupName
            New-AzureRmResourceGroup -Location "$ResourceGroupLocation" -Name $StorageResourceGroupName -Force
            $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourceGroupLocation"
        }

        # Generate the value for artifacts location if it is not provided in the parameter file
        if ($OptionalParameters[$ArtifactsLocationName] -eq $null) {
            $OptionalParameters[$ArtifactsLocationName] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
        }

        # Copy files from the local storage staging location to the storage account container
        New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

        $ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
        foreach ($SourcePath in $ArtifactFilePaths) {
            Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($ArtifactStagingDirectory.length + 1) `
                -Container $StorageContainerName -Context $StorageAccount.Context -Force
        }

        # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
        if ($OptionalParameters[$ArtifactsLocationSasTokenName] -eq $null) {
            $OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString -AsPlainText -Force `
            (New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
        }
    }

    # Create or update the resource group using the specified template file and template parameters file
    if (Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Ignore) {Write-Host "$($ResourceGroupName) Already Exisits" -ForegroundColor Green; }else {Write-Host "Creating New Resource Group" -ForegroundColor Yellow; New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force}

    if ($ValidateOnly) {
        $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                -TemplateFile $TemplateFile `
                -TemplateParameterFile $TemplateParametersFile `
                @OptionalParameters)
        if ($ErrorMessages) {
            Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
        }
        else {
            Write-Output '', 'Template is valid.'
        }
    }
    else {
        New-AzureRmResourceGroupDeployment -Name ((Get-AzureRmContext).Account.Id.Split("@")[0] + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmmss')) `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $TemplateParametersFile `
            @OptionalParameters `
            -Force -Verbose `
            -ErrorVariable ErrorMessages
        if ($ErrorMessages) {
            Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
        }
    }

}