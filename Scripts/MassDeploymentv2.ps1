Param(
    # FE or BE
    [Parameter(Mandatory = $true)]
    [ValidateSet("FE", "BE")]
    [string]
    $Tier,
    # Subscription
    #[Parameter(Mandatory = $true)]
    [string]
    $SubscriptionName = "PS-EXT-PD-03-SNGL",
    # Total No of Expected Machine in a Resource Group
    [Parameter(Mandatory = $true)]
    [ValidateScript( {if ($_ -gt 56) {Throw "You are trying to deploy more than ($_) Machines"; $false}else {
                $true
            }})]
    [Int]
    $TotalOfMachines,
    # Starting From Number
    [int]$startingFromNumber = 26
)
Set-Location -Path $PSScriptRoot
$greencolor = @{
    "ForegroundColor" = "Black";
    "BackgroundColor" = "DarkGreen"
}
$yellowcolor = @{
    "ForegroundColor" = "Black";
    "BackgroundColor" = "DarkYellow"
}
Get-Job | ForEach-Object { if ($_.state -ne "Running") { $_ | Remove-Job } else { $_|Stop-Job; $_|Remove-Job}}
$Error.Clear()
if ($Tier -eq 'FE') {$srvPatteren = "03SISP1APPW"}elseif ($Tier -eq 'BE') {$srvPatteren = "03SISP1ODBW"}
Import-Module '..\Scripts\AzureImageFunctions.psm1'
Get-AzureLoginCheck -Subscription $SubscriptionName
Save-AzureRmContext -Path .\AzureProfile_Temp.json
$numOfMachines = $TotalOfMachines

for ($i = $startingFromNumber; $i -le $numOfMachines; $i++) {
    $mName = if ($i -le 9) {($srvPatteren + "00" + $i)}elseif (($i -gt 9) -and ($i -lt 100)) {($srvPatteren + "0" + $i)}elseif ($i -gt 99) {($srvPatteren + $i)}
    Write-Host "Starting Deployment of....$mName" @greencolor
    $mrGP = ((Get-AzureRmResourceGroup).Resourcegroupname -match "-$Tier-")[0].ToString()
    $mOutput1 = Get-AzureRmVM -Name $mName -ResourceGroupName $mrGP -ErrorAction SilentlyContinue -WarningAction SilentlyContinue    
    if ($true) {
        Start-Job -ScriptBlock {
            try {
                Import-AzureRmContext -Path .\AzureProfile_Temp.json | Out-Null
                Write-Host "Successfully logged in using saved profile file" @greencolor
                Select-AzureRmSubscription -Subscription $args[1]
                $rGP = ((Get-AzureRmResourceGroup).Resourcegroupname -match ("-" + $args[2] + "-"))[0].ToString()
                #Write-Output $rGP
                #Write-Host $rGP
                $mOutput = Get-AzureRmVM -Name $args[0] -ResourceGroupName $rGP -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                #Write-Output $mOutput
                #Write-Host $mOutput
                if ($true) {
                    if ($args[2] -eq "BE") {
                        # DB Deployments
                        Set-Location -Path 'D:\SIS-Repo\Powerschool%20SIS\PD-VM-Deployments-East03\Premium-SIS-DB-DSC-UE-DJ-v3.1'
                        .\Deploy-AzureResourceGroup.ps1 -AzureVMNames $args[0]
                        Write-Host "Deploying BE ==>...$($args[0]) in the job" @yellowcolor
                    }
                    elseif ($args[2] -eq "FE") {
                        # Web Deployments
                        Set-Location -Path 'D:\SIS-Repo\Powerschool%20SIS\PD-VM-Deployments-East03\Premium-SIS-WEB-DSC-UE-DJ-v2'
                        .\Deploy-AzureResourceGroup.ps1 -AzureVMNames $args[0]
                        Write-Host "Deploying FE ==>...$($args[0]) in the job" @yellowcolor
                    }
                }
                else {
                    Write-Host "Already Found...$($mOutput).Name" @greencolor
                }
            }
            catch {
                Write-Host $Error
            }
        } -ArgumentList $mName, $SubscriptionName, $Tier
        
        Start-Sleep -Seconds 30
    }

    #Get-Job | Receive-Job
}

#Stopping Jobs Running more than 10 mins
while ((Get-Job).count -ge 1) {
    Get-Job | ForEach-Object {if (((get-date) - ($_).PSBeginTime).Minutes -gt 3) {$_ | Stop-Job; $_ | Remove-Job}else {$_|Receive-Job}}
    Start-Sleep -Seconds 60
}

