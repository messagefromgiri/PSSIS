Param(
		# IPAddress CSV File Path
		[Parameter(Mandatory = $true)]
		[string]
		$Path,
		# HostName and SID Name
		[Parameter(Mandatory = $true)]
		[string]
		$HostName
)

Function Read-IPAddressList{
	Param(
		# IPAddress CSV File Path
		[Parameter(Mandatory = $true)]
		[string]
		$Path
	)
	$IPAddress = Import-Csv -Path $Path
	$IPAddress = $IPAddress | select "IPAddress","Status"
	$hashTable = [ordered]@{}
	foreach($IP in $IPAddress)
	{
		#Write-Host $IP.IPAddress $IP.Status
		$hashTable[$IP.IPAddress] = $IP.Status
	}

	Return $hashTable
}
Function Update-IPAddressList
{
	Param(
		# Hash Array
		[Parameter(Mandatory = $true)]		
		$HashTable,
		# HostName and SID Name
		[Parameter(Mandatory = $true)]
		[string]
		$Host1,
        # IPAddress
		[Parameter(Mandatory = $true)]
		[string]
		$IP,
        # IPList
		[Parameter(Mandatory = $true)]	
        $IPList
	)
    $myarray = @()
    $i = 0
    foreach($key in ($HashTable.GetEnumerator() |select Key,Value)){
          $myobj = New-Object -TypeName PSObject
          if(($key.Value -ne 'Status')-and($key.Key -eq $IP)){
              Add-Member -InputObject $myobj -MemberType 'NoteProperty' -Name 'IPAddress' -Value $key.Key
              Add-Member -InputObject $myobj -MemberType 'NoteProperty' -Name 'Status' -Value $key.Value
			  Add-Member -InputObject $myobj -MemberType 'NoteProperty' -Name 'HostName' -Value $Host1
              $myarray += $myobj
          }
          elseif(($key.Value -ne 'Status')-and($IP -ne "")){
              Add-Member -InputObject $myobj -MemberType 'NoteProperty' -Name 'IPAddress' -Value $key.Key
              Add-Member -InputObject $myobj -MemberType 'NoteProperty' -Name 'Status' -Value $key.Value
			  Add-Member -InputObject $myobj -MemberType 'NoteProperty' -Name 'HostName' -Value $IPList[$i].HostName
              $myarray += $myobj
          }
          $i++
      }
      Return $myarray
}

$IPList = Import-Csv -Path $Path

$HashTable = Read-IPAddressList -Path $Path

try{
    
    $IP = ($IPList | where {$_.status -ne 'Allocated'})[0]

    if($IP -ne $null)
    {

        $HashTable[$IP.IPAddress] = 'Allocated'

        #Write-Host "IPAddress:$($IP.IPAddress) is Allocated" -ForegroundColor Green -BackgroundColor Black

        $aIPList = Update-IPAddressList -HashTable $HashTable -Host1 $HostName -IP $IP.IPAddress -IPList $IPList

        Remove-Item -Path $Path -Force

        $aIPList | Export-Csv $Path -NoClobber -NoTypeInformation -Force
        
    }

    return $IP.IPAddress

}
catch
{

    Write-Host "IPAddress Range is Exhausted" -ForegroundColor Red -BackgroundColor Black

}
