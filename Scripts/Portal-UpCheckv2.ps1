Function Get-ArrayValue{
    Param(
    [string]$LookFor,
    $CustomerServer
    )
    [Int]$i = 0
    $CustomerServer | % {
            if($_ -Match $LookFor)
            {
                    return $i
            }
            $i++
    }        
}

$r = gc $PSScriptRoot\list.txt
$r = $r | %{if($_.split('-').count -gt 2){($_.split('-')[0]+"-"+$_.split('-')[1])}else{$_.split('-')[0]}}
$customerDetails = @()
$r | %{
    $cust = New-Object -TypeName PSObject
    $url = ('https://'+$_+'.powerschool.com/public')
        try{
            $o = (Invoke-WebRequest $url -Method Options -ErrorAction SilentlyContinue)
            $o.Content | Out-File $PSScriptRoot\TmpHParse.txt
            $cOut = gc $PSScriptRoot\TmpHParse.txt
            $check = try{$cOut[(Get-ArrayValue -LookFor "Student and Parent Sign In" -CustomerServer $cOut)].Trim()}catch{"NA"}            
            Add-Member -InputObject $cust -MemberType NoteProperty -Name "Customer" -Value ($_+'.powerschool.com')
            Add-Member -InputObject $cust -MemberType NoteProperty -Name "Status" -Value $check[0]
            Write-Host $cust -BackgroundColor Black -ForegroundColor Green
            $customerDetails += $cust
            Remove-Item -Path $PSScriptRoot\TmpHParse.txt
            $o = $null
        }
        catch{
            $check = "UnAvailable"
            Add-Member -InputObject $cust -MemberType NoteProperty -Name "Customer" -Value $url.Replace("https://","").Replace("/public","")
            Add-Member -InputObject $cust -MemberType NoteProperty -Name "Status" -Value $check
            Write-Host $cust -BackgroundColor Black -ForegroundColor Green
            $customerDetails += $cust
        }
        
}
$cOnline = (($customerDetails|Where-Object{$_.Status -match 'Student and Parent Sign In'})).Count
$oOnline = (($customerDetails|Where-Object{$_.Status -match 'UnAvailable'})).Count
Write-Host "Totalno:$($customerDetails.Count)`nCustomersOnline:$cOnline`nCustomersOffline:$oOnline"

$customerDetails |epcsv -Path $PSScriptRoot\$("PSUPCheck_"+(Get-Date).ToString("MM-dd-yyyy-hh-mm-ss")+".csv") -NoClobber -NoTypeInformation
#$customerDetails |Out-GridView -Title PowerSchool-CustomerStatus

