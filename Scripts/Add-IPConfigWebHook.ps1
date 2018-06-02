
[CmdletBinding()]
param(
    [string]$VMName,
    [string]$ResourceGroupName,
    [string]$SubscriptionID,
    [string]$ipconfig,
    [string]$ipconfigAddress
)

$webhookurl = 'https://s1events.azure-automation.net/webhooks?token=RfNWalFuh4sJg43Ay6Wy5LtV64uF7quAJtIE8F7sy2s%3d'

$body = @{"VMNAME"=$VMName;"RESOURCEGROUPNAME"=$ResourceGroupName;"SUBSCRIPTIONID"=$SubscriptionID;"IPCONFIG"=$ipconfig;"IPCONFIGADDRESS"=$ipconfigAddress}

$params = @{
    ContentType = 'application/json'
    Headers = @{'from' = 'SundeepPaluru'; 'Date' = "$(Get-Date)"}
    Body = ($body | convertto-json)
    Method = 'Post'
    URI = $webhookurl
}

Invoke-RestMethod @params -Verbose
