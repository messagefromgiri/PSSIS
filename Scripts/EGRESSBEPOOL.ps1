#Subscription ID of the Application subscription with the FE machines
$subscriptionId = "8e7f0b90-1e44-4729-a2d3-a85c4fdc3625"

#Resource Group that has the Public Load balancer
$lbResourceGroup = "TIER-PD-NW-02-T0-RG001"

#Name of the load balancer
$lbname = "SIS-PD-FE-02-EGRESS-ELB001"

#backend pool name
$bepoolname = "SIS-FE-POOL"

#Front End Resource Group  
$feresourcegroup = 'SIS-PD-ST-02-FE-RG001'

#Path to CSV
#$pathtocsv = "C:\Users\bhushanb\OneDrive - Microsoft\PowerSchool\sisnicnames.csv"

#Login to Azure
#Login-AzureRmAccount

#Select Subscription
Select-AzureRmSubscription -Subscription $subscriptionId

#Get Load Balancer
$Loadbalancer = Get-AzureRmLoadBalancer -ResourceGroupName $lbResourceGroup -Name $lbname

#Get the Backend pool of the load balancer
$backend = Get-AzureRmLoadBalancerBackendAddressPoolConfig -name $bepoolname -LoadBalancer $Loadbalancer

#Get CSV with NIC names
#$niccsv = $pathtocsv

#Import CSV
#$nicnames = Import-Csv $niccsv
$vmList = Get-AzureRmVM -ResourceGroupName $feresourcegroup | Where-Object {$_.Name -match "APPW"}
$NicList = $vmList | % { $_.NetworkProfile.NetworkInterfaces | ? {$_.primary -eq $true}}
#Assign NIC to backend pool.
#Validate column names from CSV and update as necessary
foreach ($nicname in $NicList) {
    $nic = Get-AzureRmNetworkInterface –name ($nicname.id).Substring(135) -resourcegroupname $feresourcegroup
    if (!(($nic.IpConfigurations|? {$_.Name -eq "Main-IP"}).LoadBalancerBackendAddressPools[0].ID -match $bepoolname)) {
        Write-Host "Adding ($nicname.id).Substring(135) to $bepoolname"
        $nic.IpConfigurations[0].LoadBalancerBackendAddressPools = $backend
        Set-AzureRmNetworkInterface -NetworkInterface $nic
    }
}