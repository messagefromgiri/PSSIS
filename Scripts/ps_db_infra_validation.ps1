#####################################################
# PowerSchool Infra Build Validation script
# Version: 1.0
# Author: Vetrikumaran Ananthapandian
# Reviewer(s): Mohammad Zafar Khan / Sundeep Paluru / Bhushan Bendapudy
# Description:
#
###################################################


$ErrorActionPreference = 'stop'

function PowerSchool_Infra_Validation {                     

        [CmdletBinding()]
        param ([parameter(Mandatory=$true,ValueFromPipeline=$true)][ValidateNotNullOrEmpty()][String[]]$inputFile)

        $az_db_web_server_list = Import-Csv -Path $inputFile
         
        Foreach ($line in $az_db_web_server_list | ?{$_.role -eq 'db'}) {
        $server = $($line.server) 

        $ps_remote_az_server = New-PSSession -ComputerName $server

        Invoke-Command -Session $ps_remote_az_server -ScriptBlock {
        
        Write-host -ForegroundColor DarkYellow "Post Infra Build Validation Started for : $using:server"
        write-host -ForegroundColor DarkYellow "--------------------------------------------------------"

        #G drive checking

      $G_drive_check = Get-Volume -DriveLetter G

      if ($G_drive_check) {Write-Host -ForegroundColor Green " G: drive exists for $using:server"} else {Write-Host -ForegroundColor Red " G: drive NOT exists for $using:server"}

#SIS Adapter verificatiion
      $Net = (Get-NetIPInterface | Where-Object{$_.InterfaceAlias -match 'SIS'}).Dhcp
      $Net = $Net.Tostring()
      if ($Net = 'Disabled') {Write-Host -ForegroundColor Green " IP Static for $using:server"} else { Write-Host "IP Dynamic for $using:server"}

        $Allow_OraclePort_1521 =  netsh advfirewall firewall show rule name=Allow_OraclePort_1521

if ($Allow_OraclePort_1521) {Write-Host -ForegroundColor DarkGreen "Allow Oracle Port exists"} else {Write-Host -ForegroundColor DarkRed "Allow Oracle Port Not exists"}


$Allow_RemoteScheduleTasks =  netsh advfirewall firewall show rule name='Remote Scheduled Tasks Management (RPC-EPMAP)'

if ($Allow_RemoteScheduleTasks) {Write-Host -ForegroundColor DarkGreen "Allow_RemoteScheduleTasks is exists"} else {Write-Host -ForegroundColor DarkRed "Allow_RemoteScheduleTasks not Exist"}

$Allow_135_139_445 =  netsh advfirewall firewall show rule name=Allow_135_139_445

if ($Allow_135_139_445) {Write-Host -ForegroundColor DarkGreen "Allow_135_139_445 Port exists"} else {Write-Host -ForegroundColor DarkRed "Allow_135_139_445 Not exists"}


$RemoteAdministration1 =  netsh advfirewall firewall show rule name='Windows Management Instrumentation (WMI-In)'
$RemoteAdministration2 =  netsh advfirewall firewall show rule name='COM+ Remote Administration (DCOM-In)'


if ($RemoteAdministration1 -and $RemoteAdministration2) {Write-Host -ForegroundColor DarkGreen "WMI, Remote Adminstration exists"} else {Write-Host -ForegroundColor DarkRed "WMI, Remote Adminstration not exist"}


$Allow_OraclePort_1521 =  netsh advfirewall firewall show rule name=Allow_OraclePort_1521

if ($Allow_OraclePort_1521) {Write-Host -ForegroundColor DarkGreen "Allow Oracle Port exists"} else {Write-Host -ForegroundColor DarkRed "Allow Oracle Port Not exists"}

$NewRelic_Infra_Check = (Get-Service -Name newrelic-infra).Status

if($NewRelic_Infra_Check -eq 'Running') {write-host -BackgroundColor DarkBlue "New Relic installation is fine"} else {write-host "new-relic not installed"}
        
        }
        }

        }
        

        

        PowerSchool_Infra_Validation -inputFile "C:\Users\vetri.ananthapandian\Desktop\cc\servers.csv"