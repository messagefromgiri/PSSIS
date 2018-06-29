#Subscription ID of the Application subscription with the FE machines
$subscriptionId = "8adc65ab-342a-48ca-ba24-c0a43042c519"

#Resource Group that has the Public Load balancer
$lbResourceGroup = "TIER-PD-NW-01-T0-RG001"

#Name of the load balancer
$lbname = "SIS-PD-FE-EGRESS-ELB001"

#backend pool name
$bepoolname = "SIS-FE-POOL"

#Front End Resource Group  
$feresourcegroup = 'SIS-PD-ST-00-FE-RG001'

#Path to CSV
$pathtocsv = "C:\Users\bhushanb\OneDrive - Microsoft\PowerSchool\sisnicnames.csv"

#Login to Azure
Login-AzureRmAccount

#Select Subscription
Select-AzureRmSubscription -Subscription $subscriptionId

#Get Load Balancer
$Loadbalancer = Get-AzureRmLoadBalancer -ResourceGroupName $lbResourceGroup -Name $lbname

#Get the Backend pool of the load balancer
$backend = Get-AzureRmLoadBalancerBackendAddressPoolConfig -name $bepoolname -LoadBalancer $Loadbalancer

#Get CSV with NIC names
$niccsv = $pathtocsv

#Import CSV
$nicnames = Import-Csv $niccsv

#Assign NIC to backend pool.
#Validate column names from CSV and update as necessary
foreach ($nicname in $nicnames)
{
    $nic = Get-AzureRmNetworkInterface –name $nicname.name -resourcegroupname $feresourcegroup
    $nic.IpConfigurations[0].LoadBalancerBackendAddressPools=$backend
    Set-AzureRmNetworkInterface -NetworkInterface $nic
}

