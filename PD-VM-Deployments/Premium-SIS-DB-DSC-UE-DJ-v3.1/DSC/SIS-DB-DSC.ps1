Configuration Main
{
	[CmdletBinding()]
		Param (
			[Parameter(Position=0)]
			[string] $nodeName,
			[Parameter(Position=1)]
			[string] $timeZone
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
@'
select disk 5
Convert dynamic
select disk 6
Convert dynamic
create volume stripe disk=5,6
format quick fs=ntfs label="Data"  
assign letter="G"  
'@ | Out-File 'script.txt' -Encoding ascii

DISKPART /S Script.txt


							# Change Dvd Drive
								$drv = Get-WmiObject win32_volume -filter 'DriveType = "5"'
                              If($drv -ne $null){
								  $drv.DriveLetter = "I:"
								  $drv.Put()
							  }

								$Disks = Get-Disk | Where-Object PartitionStyle -Eq "RAW" | select *,@{Name='TotalDiskSize';Expression={[math]::Round((($_.Size/1024)/1024)/1024)}}

								

							foreach($disk in $disks)
								{

									if(!($disk.Number -match '0|1|2'))
									{
										switch ($disk.Number)
										{
														3 {
															$Disk | Initialize-Disk
															New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter R

															Format-Volume -DriveLetter R -FileSystem NTFS -Force -Confirm:$false -NewFileSystemLabel "Redo"

															}
														4 {
															$Disk | Initialize-Disk
															New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter U

															Format-Volume -DriveLetter U -FileSystem NTFS -Force -Confirm:$false -NewFileSystemLabel "Undo"

															}

										  }
									}
								}
							}
								######################

								    $Partitions = Get-Partition | ? {!($_.Driveletter -match "^C|^D|^I")}

								  	$DriveEH = $Partitions | %{if((((($_.Size/1024)/1024)/1024) -ge '199') -and (((($_.Size/1024)/1024)/1024) -le '202')){$_}}
									$DriveEH | % {if($_.DriveLetter -eq 'E'){Set-Partition -InputObject $_ -NewDriveLetter J}}
									
									$MaxSize = (Get-PartitionSupportedSize -DriveLetter J).sizeMax
									Resize-Partition -DriveLetter J -Size $MaxSize

								######################
								Start-Sleep -Seconds 30


						}
            TestScript = {
				$Partitions = Get-Partition | where {!($_.Driveletter -match "^C|^D|^I")}
                      if(($Partitions.driveletter -contains "U") -and ($Partitions.driveletter -contains "R") -and ($Partitions.driveletter -contains "J"))
						{
                          return $true
                        }
                     else
						{
                          return $false
                        }
			  }
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
			else{
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
						Rename-NetAdapter -Name $interfaceName -NewName "Backup"
					}

				}
			}
			catch{
				Write-Output "Unable to Set Static IPAddress"
			}
		}
		DependsOn = '[Script]DiskRenaming'
	}
	Script Allow_OraclePort_1521
	{
		GetScript = {
			@{Result = "Allow_OraclePort_1521"}
		}
		TestScript = {
			if(Get-NetFirewallRule -DisplayName "Allow_OraclePort_1521" -ErrorAction Ignore){return $true}else{return $false}
		}
		SetScript = {
			New-NetFirewallRule -Name Allow_OraclePort_1521 -DisplayName Allow_OraclePort_1521 -Description "PowerSchoolOracleCustomPort " -Direction Inbound `
				-Action Allow -Enabled True -Profile Any -LocalPort 1521 -Protocol TCP
		}
	}
	Script Allow_135_139_445
	{
		GetScript = {
			@{Result = "Allow_135_139_445"}
		}
		TestScript = {
			if(Get-NetFirewallRule -DisplayName "Allow_135_139_445" -ErrorAction Ignore){return $true}else{return $false}
		}
		SetScript = {
			New-NetFirewallRule -Name Allow_135_139_445 -DisplayName Allow_135_139_445 -Description "SMB Ports for file share" -Direction Inbound `
				-Action Allow -Enabled True -Profile Any -LocalPort 135,137,139,445 -Protocol TCP
		}
		DependsOn = '[Script]Allow_OraclePort_1521'
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
		DependsOn = '[Script]Allow_OraclePort_1521','[Script]Allow_135_139_445'
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
		DependsOn = '[Script]Allow_OraclePort_1521','[Script]Allow_135_139_445','[Script]Allow_RemoteScheduleTasks'
	}
	Script SetCredSSP
	{
		GetScript = {
			@{Result = "SetCredSSP"}
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
		DependsOn = '[Script]Allow_OraclePort_1521','[Script]Allow_135_139_445','[Script]Allow_RemoteScheduleTasks','[Script]Allow_RemoteAdministration'
	}
	Script InstallNewRelic
	{
		GetScript = {
		    @{Result = "NewRelic-Installed"}
		}
		TestScript = {
			if(Get-Service -Name newrelic-infra -ErrorAction Ignore){return $true}else{$false}
		}
		SetScript = {
            $acctKey = ConvertTo-SecureString -String "pj+7mV4N0Wjufm4Vf/dBbaY0fHnXqh6IoWMgF4w75YwGKimYh4CUBvwdjjLqgRy1ZEcr7igleta3qy9WK+XOoQ==" -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\sispd00sragrssa003", $acctKey
            New-PSDrive -Name Z -PSProvider FileSystem -Root "\\sispd00sragrssa003.file.core.windows.net\pssis" -Credential $credential -Persist
                    New-Item -Path D:\ -ItemType Directory -Name NEWRELIC -ErrorAction SilentlyContinue

					Copy-Item -Path Z:\NEWRELIC\newrelic-infra.msi -Destination D:\NEWRELIC\newrelic-infra.msi -Force -Verbose

                    msiexec /i D:\NEWRELIC\newrelic-infra.msi /L*v install.log /qn
                    
					Start-Sleep -Seconds 200
			
					Rename-Item -Path 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.yml' -NewName 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.txt'
					"license_key: aa3c1a32f97de2f370e8813575a5f660d2b3f26b" > 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.txt'
					Rename-Item -NewName 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.yml' -Path 'C:\Program Files\New Relic\newrelic-infra\newrelic-infra.txt'														
					Start-Service -Name newrelic-infra -ErrorAction Ignore
            
                 Remove-PSDrive -Name Z
		}
		DependsOn = '[Script]DiskRenaming'
	}
	Script DBRoboCopy
	{
		GetScript = {
			@{Result = "RoboCopy"}
		}
		TestScript = {
			if((Get-ChildItem -Path G:\ -Depth 1).count -gt 2){Return $true}else{Return $false}
		}
		SetScript = {
			Stop-Service -Name msdtc -Force
			Start-Sleep -Seconds 10

			Get-Service -Name Oracle* | Stop-Service
			Start-Sleep -Seconds 10

			######### Copying Oracle to New Disk					
				ROBOCOPY.exe J:\ G:\ /E /MT:32 /V /W:5 /NP /LOG:C:\CopyTemp.log /E /SEC
		}
		DependsOn = '[Script]DiskRenaming','[Script]InstallNewRelic','[Script]DisableServerMgrStartUp','[Script]SetComputerDescription','[Script]SetStaticIPaddress','[Script]Allow_OraclePort_1521','[Script]Allow_135_139_445','[Script]Allow_RemoteScheduleTasks','[Script]Allow_RemoteAdministration','[Script]SetCredSSP'
	}
  }
}
