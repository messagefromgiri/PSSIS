Configuration Main
{
	[CmdletBinding()]
		Param (
			[Parameter(Position=0)]
			[string] $nodeName
		)

Import-DscResource -ModuleName PSDesiredStateConfiguration

Node $nodeName
  {

  	LocalConfigurationManager {
            ConfigurationMode = "ApplyOnly"
			ActionAfterReboot = "ContinueConfiguration"			
    } 

	Script DiskRenaming
    {

			GetScript = {
                               Return @{
								     Result = "DiskRenaming"
			                     }
                        }

			SetScript = {
				              Invoke-Command -ScriptBlock {

                                $Disks = Get-Disk | Where-Object PartitionStyle -Eq "RAW" | select *,@{Name='TotalDiskSize';Expression={[math]::Round((($_.Size/1024)/1024)/1024)}}

								$Disks | Initialize-Disk

								    #$Partitions = Get-Partition | ? {!($_.Driveletter -match "^C|^D|^A|^F")}

								    #$DriveG = $Partitions | %{if((((($_.Size/1024)/1024)/1024) -ge '509') -and (((($_.Size/1024)/1024)/1024) -le '515')){$_}}
    								#if($DriveG.DriveLetter -ne 'G'){Set-Partition -InputObject $DriveG -NewDriveLetter G}
                                foreach($disk in $disks)
								{

									if(!($disk.Number -match '0|1'))
									{
										switch ($disk.Number)
										{

														2 {
															New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter G

															Format-Volume -DriveLetter G -FileSystem NTFS -Force -Confirm:$false -NewFileSystemLabel "Data"

														}
										}
									}
								}


							}
						}
            TestScript = {
				$Partitions = Get-Partition | ? {!($_.Driveletter -match "^C|^D|^A|^F")}
                      if($Partitions.driveletter -contains "G")
						{
                          return $true
                        }
                     else
						{
                          return $false
                        }
			  }
			DependsOn = '[Script]AllowHTTPPort_80_7980'
	  }
	Script DisableServerMgrStartUp
	{
		 GetScript = {@{Result = "DisableServerMgrStartUp"}}

		 SetScript = {
			  Invoke-Command -ScriptBlock {
				  Set-ItemProperty -Path HKLM:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Type DWORD -Value "0x1"
			  }
		 }
		 TestScript = {
			if(((Get-ItemProperty -Path HKLM:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon | select DoNotOpenServerManagerAtLogon).DoNotOpenServerManagerAtLogon) -eq '1')
				{
					return $true
				}
			else{
					return $false
				}
		 }
		DependsOn = '[Script]DiskRenaming'

	  }
	Script AllowHTTPPort_80_7980
	{
		GetScript = {
			@{Result = "Set-Firewall-80-7980-toAllow"}
		}
		TestScript = {
			if(Get-NetFirewallRule -DisplayName "Allow-PS-Http-Inbound-Port80-7980" -ErrorAction Ignore){return $true}else{return $false}
		}
		SetScript = {
			New-NetFirewallRule -DisplayName "Allow-PS-Http-Inbound-Port80-7980" -Direction Inbound -LocalPort 80,7980,61616 -Protocol TCP -Action Allow -Name "Allow-PS-Http-Inbound-Port80-7980" -Description "Allow-PS-Http-Inbound-Port80-7980"
		}

	}
    Script Allow_135_139_137_445
	{
		GetScript = {
			@{Result = "Allow_135_137_139_445"}
		}
		TestScript = {
			if(Get-NetFirewallRule -DisplayName "Allow_135_137_139_445" -ErrorAction Ignore){return $true}else{return $false}
		}
		SetScript = {
			New-NetFirewallRule -Name Allow_135_137_139_445 -DisplayName Allow_135_137_139_445 -Description "SMB Ports for file share" -Direction Inbound `
				-Action Allow -Enabled True -Profile Any -LocalPort 135,137,139,445 -Protocol TCP
		}
		DependsOn = '[Script]AllowHTTPPort_80_7980'

	}
	Script Allow_RemoteScheduleTasks
	{
		GetScript = {
			@{Result = "Allow_RemoteScheduleTasks"}
		}
		TestScript = {
			if(Get-NetFirewallRule -DisplayName "remote scheduled tasks management*" -ErrorAction Ignore){return $true}else{return $false}
		}
		SetScript = {
			Netsh advfirewall firewall set rule group="remote scheduled tasks management" new enable=yes
		}
		DependsOn = '[Script]AllowHTTPPort_80_7980','[Script]Allow_135_139_137_445'

	}
	Script Allow_RemoteAdministration
	{
		GetScript = {
			@{Result = "RemoteAdministration"}
		}
		TestScript = {
			if(Get-NetFirewallRule -DisplayGroup 'Remote Administration*' -ErrorAction Ignore){return $true}else{return $false}
		}
		SetScript = {
			Netsh advfirewall firewall set rule group="remote administration" new enable=yes
			netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes
		}
		DependsOn = '[Script]Allow_135_139_137_445','[Script]Allow_RemoteScheduleTasks'

	}
	Script SetComputerDescription
	{
		GetScript = {
			@{Result = "LocalHost"}
		}
		TestScript = {
			$MachineName = (Get-WmiObject -class Win32_OperatingSystem -ComputerName .)
			if($MachineName.Description -eq $MachineName.PSComputerName)
			{
				return $true
			}
			else{
				return $false
			}
		}
		SetScript = {
			$MachineName = (Get-WmiObject -class Win32_OperatingSystem -ComputerName .)
			$MachineName.Description = $MachineName.PSComputerName
			$MachineName.put()
		}
		DependsOn = '[Script]DiskRenaming'
	}
	Script SetStaticIPaddress
	{
		GetScript = {
			@{Result = "SetStaticIPAddress"}
		}
		TestScript = {
			if(Get-NetIPInterface | Where-Object{$_.InterfaceAlias -match 'SIS'})
			{
				return $true
			}
			else
			{
				return $false
			}
		}
		SetScript = {
			try{

				# Get the IPAddress and Set IPAddress

				$NICs = Get-WMIObject Win32_NetworkAdapterConfiguration -computername . | where{$_.IPEnabled -eq $true -and $_.DHCPEnabled -eq $true}
				$NICs = $NICs|sort InterfaceIndex
				<#if($NICs[0].DefaultIPGateway -ne $null)
				{
					$nicgateway = $NIC[0].DefaultIPGateway
				}
				elseif($NICs[1].DefaultIPGateway -ne $null)
				{
					$nicgateway = $NIC[1].DefaultIPGateway
				}#>
				#Set-NetIPInterface -InterfaceAlias 'Ethernet 2' -InterfaceMetric 20
				foreach($NIC in $NICs)
				{
					$interfaceName = (Get-NetAdapter -InterfaceIndex $NIC.InterfaceIndex).Name
					if($NIC.DefaultIPGateway -ne $null)
					{
						# Disable IPv6
						Disable-NetAdapterBinding -Name $interfaceName -ComponentID ms_tcpip6
						Start-Sleep -Seconds 5
						$ip = ($NIC.IPAddress[0])
						$gateway = $NIC.DefaultIPGateway
						$subnet = $NIC.IPSubnet[0]
						$dns = $NIC.DNSServerSearchOrder
						$NIC.EnableStatic($ip, $subnet)
						$NIC.SetGateways($gateway)
						$NIC.SetDNSServerSearchOrder($dns)
						$NIC.SetDynamicDNSRegistration("TRUE")
						Rename-NetAdapter -Name $interfaceName -NewName "SIS"
					}
					else
					{
						# Disable IPv6
						Disable-NetAdapterBinding -Name $interfaceName -ComponentID ms_tcpip6
						Start-Sleep -Seconds 5
						$ip = ($NIC.IPAddress[0])
						$subnet = $NIC.IPSubnet[0]
						$dns = $NIC.DNSServerSearchOrder
						$NIC.EnableStatic($ip, $subnet)
						$NIC.SetDNSServerSearchOrder($dns)
						$NIC.SetDynamicDNSRegistration("TRUE")

					}

				}
			}
			catch{
				Write-Output "Unable to Set Static IPAddress"
			}
		}
		DependsOn = '[Script]DiskRenaming'
	}
    
    Script SetCredSSP
	{
		GetScript = {
			@{Result = "SetCredSSP-Completed"}
		}
		TestScript = {
			return $false					
		}
		SetScript = {
			Push-Location
			Set-Location HKLM:
			
			New-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system\CredSSP\Parameters' -Force
			
			$registrypath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system\CredSSP\Parameters"
			$Name = "AllowEncryptionOracle"
			$value = "2"

			New-ItemProperty -Path $registrypath -Name $Name `
			-Value $value -PropertyType DWORD -Force 
		}
		DependsOn = '[Script]DiskRenaming','[Script]AllowHTTPPort_80_7980','[Script]Allow_135_139_137_445'
	}

	Script InstallNewRelic
	{
		GetScript = {
		
		}
		TestScript = {
			if(Get-Service -Name newrelic-infra -ErrorAction Ignore){return $true}else{$false}
		}
		SetScript = {
            $acctKey = ConvertTo-SecureString -String "pj+7mV4N0Wjufm4Vf/dBbaY0fHnXqh6IoWMgF4w75YwGKimYh4CUBvwdjjLqgRy1ZEcr7igleta3qy9WK+XOoQ==" -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\sispd00sragrssa003", $acctKey
            New-PSDrive -Name Z -PSProvider FileSystem -Root "\\sispd00sragrssa003.file.core.windows.net\pssis" -Credential $credential -Persist
                                              
                    msiexec /i Z:\NEWRELIC\newrelic-infra.msi /L*v install.log /qn

                    Start-Sleep -Seconds 180

                    Rename-Item -Path 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.yml' -NewName 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.txt'

                    "license_key: aa3c1a32f97de2f370e8813575a5f660d2b3f26b" > 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.txt'

                    Rename-Item -NewName 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.yml' -Path 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.txt'

			        Start-Service -Name newrelic-infra -ErrorAction Ignore
            
                Remove-PSDrive -Name Z
		}
		DependsOn = '[Script]DiskRenaming'
	}
  }
}
