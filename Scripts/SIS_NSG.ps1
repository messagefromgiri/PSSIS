#Login-AzureRmAccount

<#QA Subscription
$besubnet = "172.22.16.64/26"
$mgmtsubnet = "172.22.1.48/28"
$f5subnet = "172.22.1.32/28"
$fesubnet = "172.22.16.0/26"
$location = "eastus"
$appsubscriptionId = "44bd224d-ef23-4e37-905b-15751d879e43"
$mgmtSubscriptionId = "4df36395-061e-45da-b665-b6eff19dd9c7"#>

<#US East 1 Subscription
$besubnet = "172.21.72.0/21"
$mgmtsubnet = "172.20.216.208/28"
$f5subnet = "172.20.216.128/26"
$fesubnet = "172.21.64.0/22"
$location = "eastus"
$appsubscriptionId = "8adc65ab-342a-48ca-ba24-c0a43042c519"
$mgmtSubscriptionId = "2918909d-37c3-4acd-87ec-480b42826789"
$appnsgrg = "TIER-PD-NW-01-T0-RG001"
$bensg = "NSG-SIS-DB-SN002-172.21.72.0_21"
$fensg = "NSG-SIS-WB-SN001-172.21.64.0_22"
$f5nsgrg = "TIER-PD-USE-T0-RG002"
$f5extnsg = "NSG-TIER-UT-SN003-172.20.216.128_26" #>

#US West 1 Subscription
$besubnet = "172.21.136.0/21"
$mgmtsubnet = "172.20.216.208/28"
$f5subnet = "172.20.232.64/26"
$fesubnet = "172.21.128.0/21"
$location = "westus2"
$appsubscriptionId = "fedb6b9b-8def-4ccb-947b-4a87809a7b2e"
$mgmtSubscriptionId = "6d0b3073-cc4b-4ec9-a3ab-2a5630f28fe5"
$appnsgrg = "TIER-PD-NW-20-T0-RG001"
$bensg = "NSG-SIS-DB-SN002-172.21.136.0_21"
$fensg = "NSG-SIS-WB-SN001-172.21.128.0_21"
$f5nsgrg = "TIER-PD-USW-T0-RG002"
$f5extnsg = "NSG-TIER-UT-SN001-172.20.232.64_26"

Select-AzureRmSubscription -Subscription $appsubscriptionId

 #$besubnet 
 $berule5 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-MGMTSubnet -Description "Rule5" -Access Allow -Protocol * -Direction Inbound  -Priority 460 -SourceAddressPrefix $mgmtsubnet -SourcePortRange * -DestinationAddressPrefix $besubnet -DestinationPortRange 3389,22  
 $berule4 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-BE-Local -Description "Rule4" -Access Allow -Protocol * -Direction Inbound  -Priority 470 -SourceAddressPrefix $besubnet -SourcePortRange * -DestinationAddressPrefix $besubnet -DestinationPortRange *  
 $berule3 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-AzureLoadBalancer -Description "Rule3" -Access Allow -Protocol * -Direction Inbound  -Priority 480 -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *  
 $berule2 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-FESubnet -Description "Rule2" -Access Allow -Protocol * -Direction Inbound  -Priority 490 -SourceAddressPrefix $fesubnet -SourcePortRange * -DestinationAddressPrefix $besubnet -DestinationPortRange *  
 $berule1 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-F5-Oracle -Description "Rule1" -Access Allow -Protocol * -Direction Inbound  -Priority 500 -SourceAddressPrefix $f5subnet -SourcePortRange * -DestinationAddressPrefix $besubnet -DestinationPortRange 1521  
 $berule0 = New-AzureRmNetworkSecurityRuleConfig -Name Deny-Inbound-BESubnet -Description "Rule0" -Access Deny -Protocol * -Direction Inbound  -Priority 510 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix $besubnet -DestinationPortRange *  
 
 #Create NSG
 $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $appnsgrg -Location $location -Name $bensg -SecurityRules $berule0,$berule1,$berule2,$berule3,$berule4,$berule5 -Verbose -Force  
   
   
#$fesubnet 
 #$ferule6 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-SIF-MA-ZIS-Access -Description "Rule6" -Access Allow -Protocol * -Direction Inbound  -Priority 450 -SourceAddressPrefix $f5subnet -SourcePortRange * -DestinationAddressPrefix $fesubnet -DestinationPortRange 60000-60200
 $ferule5 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-MGMTSubnet -Description "Rule5" -Access Allow -Protocol * -Direction Inbound  -Priority 460 -SourceAddressPrefix $mgmtsubnet -SourcePortRange * -DestinationAddressPrefix $fesubnet -DestinationPortRange 3389,22  
 $ferule4 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-F5subnet -Description "Rule4" -Access Allow -Protocol * -Direction Inbound  -Priority 470 -SourceAddressPrefix $f5subnet -SourcePortRange * -DestinationAddressPrefix $fesubnet -DestinationPortRange 443,80,8443,7980  
 $ferule3 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-BEsubnet -Description "Rule3" -Access Allow -Protocol * -Direction Inbound  -Priority 480 -SourceAddressPrefix $besubnet -SourcePortRange * -DestinationAddressPrefix $fesubnet -DestinationPortRange *  
 $ferule2 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-FE-Local -Description "Rule2" -Access Allow -Protocol * -Direction Inbound  -Priority 490 -SourceAddressPrefix $fesubnet -SourcePortRange * -DestinationAddressPrefix $fesubnet -DestinationPortRange *  
 $ferule1 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-AzureLoadBalancer -Description "Rule1" -Access Allow -Protocol * -Direction Inbound  -Priority 500 -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *  
 $ferule0 = New-AzureRmNetworkSecurityRuleConfig -Name Deny-Inbound-FEsubnet -Description "Rule0" -Access Deny -Protocol * -Direction Inbound  -Priority 510 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix $fesubnet -DestinationPortRange *  
 
 $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $appnsgrg -Location $location -Name $fensg -SecurityRules $ferule0,$ferule1,$ferule2,$ferule3,$ferule4,$ferule5 -Verbose -Force  

 
 Select-AzureRmSubscription -Subscription $mgmtSubscriptionId
 #F5subnet  
 $f5rule3 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-F5-Internet -Description "Rule3" -Access Allow -Protocol * -Direction Inbound  -Priority 480 -SourceAddressPrefix 72.201.254.70,64.191.84.50/32,38.133.125.0/25,96.46.147.226/32,12.27.214.2/32,108.178.83.26/32,68.105.207.100/32,170.249.180.130/32,4.16.50.66/32,72.237.31.230/32,45.62.176.85/32,103.206.114.108,183.83.215.116,223.230.105.24  -SourcePortRange * -DestinationAddressPrefix $f5subnet -DestinationPortRange 443,80,8443  
 $f5rule2 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-F5-Local -Description "Rule2" -Access Allow -Protocol * -Direction Inbound  -Priority 490 -SourceAddressPrefix $f5subnet -SourcePortRange * -DestinationAddressPrefix $f5subnet -DestinationPortRange *  
 $f5rule1 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-AzureLoadBalancer -Description "Rule1" -Access Allow -Protocol * -Direction Inbound  -Priority 500 -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *  
 $f5rule0 = New-AzureRmNetworkSecurityRuleConfig -Name Deny-Inbound-F5subnet -Description "Rule0" -Access Deny -Protocol * -Direction Inbound  -Priority 510 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix $f5subnet -DestinationPortRange *  
 
 $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $f5nsgrg -Location $location -Name $f5extnsg -SecurityRules $f5rule0,$f5rule1,$f5rule2,$f5rule3 -Verbose -Force

 
   
#MGMT  
#mgmtrule3 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-RDP-MGMT -Description "Rule3" -Access Allow -Protocol TCP -Direction Inbound  -Priority 480 -SourceAddressPrefix 72.201.254.70,64.191.84.50/32,38.133.125.0/25,96.46.147.226/32,12.27.214.2/32,108.178.83.26/32,68.105.207.100/32,170.249.180.130/32,4.16.50.66/32,72.237.31.230/32,45.62.176.85/32,103.206.114.108,183.83.215.116,223.230.105.24  -SourcePortRange * -DestinationAddressPrefix $mgmtsubnet -DestinationPortRange 3389,22  
#$mgmtrule2 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-Subnet-Inbound -Description "Rule2" -Access Allow -Protocol * -Direction Inbound  -Priority 490 -SourceAddressPrefix $mgmtsubnet -SourcePortRange * -DestinationAddressPrefix $mgmtsubnet -DestinationPortRange *  
#$mgmtrule1 = New-AzureRmNetworkSecurityRuleConfig -Name Allow-Inbound-AzureLoadBalancer -Description "Rule1" -Access Allow -Protocol * -Direction Inbound  -Priority 500 -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange *  
#$mgmtrule0 = New-AzureRmNetworkSecurityRuleConfig -Name Deny-inbound-$mgmtsubnet -Description "Rule0" -Access Deny -Protocol * -Direction Inbound  -Priority 510 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix $mgmtsubnet -DestinationPortRange *  
 
#$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName "TIER-QA-NW-00-T0-RG001" -Location $location -Name "********" -SecurityRules $mgmtrule0,$mgmtrule1,$mgmtrule2,$mgmtrule3 -Verbose -Force  
  
 
 

  
 
 