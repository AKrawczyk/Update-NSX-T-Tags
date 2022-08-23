 <#
.SYNOPSIS
  
   Removes and Restores NSX-T Tags from VMs
 
.DESCRIPTION
  
   This script is designed to fix a bug in NSX-T 4.0 where some members of a tag are not appering in groups.
   The issue effects members of a tag that were added in NSX-V, were migration to NSX-T 3.2 and then upgraded to NSX-T 4.0.
   The fix is to untag a VM and re-tag a VM, after this all groups with these tags will show the VMs again.
 
.Credits
    Created by Aaron Krawczyk (Cloud Support MTU)
    Inspired and aided by the script created by derstich (https://derstich.wordpress.com) 
 
.EXAMPLE
 
    Update-NSX-T-Tags-V2.ps1
#>

# Function to write logs to file and screen
Function Write-And-Log 
{
 
[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True,Position=1)]
   [ValidateNotNullOrEmpty()]
   [string]$LogFile,
   [Parameter(Mandatory=$True,Position=2)]
   [ValidateNotNullOrEmpty()]
   [string]$line,
 
   [Parameter(Mandatory=$False,Position=3)]
   [int]$Severity=0,
 
   [Parameter(Mandatory=$False,Position=4)]
   [string]$type="terse"
 )
 
$timestamp = (Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] "))
$ui = (Get-Host).UI.RawUI
 
    switch ($Severity) 
    {
    
            {$_ -gt 0} {$ui.ForegroundColor = "red"; $type ="full"; $LogEntry = $timestamp + ":Error: " + $line; break;}
            {$_ -eq 0} {$ui.ForegroundColor = "green"; $LogEntry = $timestamp + ":Info: " + $line; break;}
            {$_ -lt 0} {$ui.ForegroundColor = "yellow"; $LogEntry = $timestamp + ":Warning: " + $line; break;}
    
    }
    switch ($type) 
    {
    
            "terse"   {Write-Output $LogEntry; break;}
            "full"    {Write-Output $LogEntry; $LogEntry | Out-file $LogFile -Append; break;}
            "logonly" {$LogEntry | Out-file $LogFile -Append; break;}
        
    }
 
$ui.ForegroundColor = "white"
 
}

$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path
$StartTime = Get-Date -Format "yyMMddHHmmss_"
$logfilename = $ScriptRoot + "\" + $StartTime + "Update-NSX-T-Tags-V2.log"
$csvoutfile  = $ScriptRoot + "\" + $StartTime + "Update-NSX-T-Tags-V2.csv"
$error.Clear()

#Get NSX manager and credentials
[int]$MenuSelection = Read-Host -Prompt "1 = Reset Multiple VMs Tags, 2 = Reset Single VMs Tags, 3 = Export CSV, 4 = Import CSV. Enter Selection:"
while (($MenuSelection -isnot [int]) -or ($MenuSelection -lt 1) -or ($MenuSelection -gt 4))
{
    $MenuSelection = Read-Host -Prompt "Invalid option; Enter Selection 1-4:"
}
if ($MenuSelection -eq 2)
{
    #<--- Uncomment if you only want to remove single VMs tag ---->
    $display_name = Read-Host -Prompt 'VM Name'
    #<--- Uncomment if you only want to remove single VMs tag ---->
}
elseif ($MenuSelection -eq 4)
{
    $csvinfile = Read-Host -Prompt "Enter CSV to Import"
    while (-not (test-path "$csvinfile"))
    {
        $csvinfile = Read-Host -Prompt "File does not exist; Enter CSV to Import"
    }
}
$nsxmanager = Read-Host -Prompt "Enter NSX Manager FQDN/IP"
$nsxcred = Get-Credential -Message "NSX Credentials"
write-and-log $logfilename "Connecting to NSX Manager $($nsxmanager) please wait...." 0 "full"

#Connects to NSX manager
Connect-NsxtServer -Server $nsxmanager -Credential $nsxcred -ErrorAction SilentlyContinue
if ($error.Count -eq 0)
{
    $error.clear()
    write-and-log $logfilename "[SUCCESS] - NSX Manager $($nsxmanager) connected successfully." 0 "full"
    write-and-log $logfilename "Collecting all VM tag data." 0 "full"

    #Collects all VM data and creates object containg VM Name, VM ID and tags 
    $vmdata = Get-NsxtPolicyService -Name com.vmware.nsx_policy.infra.realized_state.enforcement_points.virtual_machines

    if (($MenuSelection -ne 4))
    {
        $vmdatatags = $vmdata.list("default").results | select-object -property display_name, external_id, tags
        write-and-log $logfilename "All VM tags imported from NSX-T" 0 "full"
        if ($MenuSelection -eq 2)
        {
            #<--- Uncomment if you only want to remove single VMs tag ---->
            $vmdatatags = $vmdatatags | Where-Object {$_.display_name -eq $display_name}
            #<--- Uncomment if you only want to remove single VMs tag ---->
            write-and-log $logfilename "Single VMs $($display_name) tags to be reset" 0 "full"
        }
        elseif ($MenuSelection -eq 3)
        {
            $vmdatatags |  Export-Csv -Path $csvoutfile -NoTypeInformation
            write-and-log $logfilename "All VM tags exported to csv" 0 "full"
        }
    }
    else
    {
        $vmdatatags = Import-Csv -Path $csvinfile -Header "display_name", "external_id", "tags"
        write-and-log $logfilename "All VM tags imported from csv" 0 "full"
    }

    

    #Process to gather VMs tags, then remove and restore the tags
    foreach ($vm in $vmdatatags) 
    {
        $vmname = $vm.display_name.ToString()
        $vmdataid = $vm.external_id.ToString()
        if ($vm.tags -ne $null)
        {
            #Converting tags into object
            $vmdataentry = $vm.tags.tostring()
            $vmdataentrytags=$vmdataentry -replace ("\[struct ") -replace ("\]")
            $vmdataentrytags = $vmdataentrytags -replace ("struct ") -replace ("'") -replace ("}}"),("}") -replace (":"),("=") -replace (" ") -replace ("},"),("};")
            $vmdataentrytags = @($vmdataentrytags.split(";"))
            $vmdataentrytags = $vmdataentrytags -replace ("{") -replace ("}")
            
            #Get VM to apply tags to
            $vmdatacontent = $vmdata.Help.updatetags.virtual_machine_tags_update.Create()  
            $vmdatacontent.virtual_machine_id = $vmdataid
            $vmdatacontentAdd = $vmdata.Help.updatetags.virtual_machine_tags_update.Create()  
            $vmdatacontentAdd.virtual_machine_id = $vmdataid

            write-and-log $logfilename "-------------------------------------------------------" 0 "full"
            write-and-log $logfilename "--------------- <        $($vmname)       > ---------------" 0 "full"
            write-and-log $logfilename "-------------------------------------------------------" 0 "full"
            write-and-log $logfilename "External VM ID = $($vmdataid)" 0 "full"
            write-and-log $logfilename "Tagged VM = $($vmname)" 0 "full"
            foreach ($scopetag in $vmdataentrytags) 
            {
                write-and-log $logfilename "$($scopetag)" 0 "full"
            }
               
            #Process to sptit Tag and Scope
            $EmptyTag = "scope=,tag="
            $EmptyTag=@($EmptyTag.split(","))
            $vmdatatags1=$EmptyTag|ConvertFrom-StringData
            $vmdatatagsRemove=$vmdata.Help.updatetags.virtual_machine_tags_update.tags.Element.Create()
            $vmdatatagsRemove.tag=$vmdatatags1.tag
            $vmdatatagsRemove.scope=$vmdatatags1.scope
                
            if (($MenuSelection -ne 3))
            {
                #<--- Removes Tags to VM (Comment out for testing)---->
                $vmdatacontent.tags.Add($vmdatatagsRemove) |Out-Null
                $vmdata.updatetags("default", $vmdatacontent)
                #<--- Removes Tags to VM (Comment out for testing)---->

                write-and-log $logfilename "All tags removed from VM $($vmname)" 0 "full"
            }

            #Process to sptit each object item into Tag and Scope
            foreach ($item in $vmdataentrytags) 
            {
                $item=@($item.split(","))
                $vmdatatags2=$item|ConvertFrom-StringData
                $vmdatatagsAdd=$vmdata.Help.updatetags.virtual_machine_tags_update.tags.Element.Create()
                $vmdatatagsAdd.tag=$vmdatatags2.tag
                $vmdatatagsAdd.scope=$vmdatatags2.scope
                
                if (($MenuSelection -ne 3))
                {
                    #<--- Restores Tags to VM (Comment out for testing)---->
                    $vmdatacontentAdd.tags.Add($vmdatatagsAdd) |Out-Null
                }
            }
            if (($MenuSelection -ne 3))
            {
                #<--- Restores Tags to VM (Comment out for testing)---->
                $vmdata.updatetags("default", $vmdatacontentAdd)
          
                write-and-log $logfilename "All tags restored to VM $($vmname)" 0 "full"
            }
            else
            {
                write-and-log $logfilename "All VM $($vmname) tags exported to csv" 0 "full"
            }
        }
        else
        {
            write-and-log $logfilename "-------------------------------------------------------" 0 "full"
            write-and-log $logfilename "--------------- <        $($vmname)       > ---------------" 0 "full"
            write-and-log $logfilename "-------------------------------------------------------" 0 "full"
            write-and-log $logfilename "This VM $($vmname) has no NSX-T Tags." -1 "full"
        }
    }
    #Disconnects from NSX manager
    Disconnect-NsxtServer -Server $nsxmanager -ErrorAction SilentlyContinue
    if ($error.Count -eq 0)
    {
        $error.clear()
        write-and-log $logfilename "[SUCCESS] - NSX Manager $($nsxmanager) Disconnected successfully." 0 "full"
    }
    else
    {
        write-and-log $logfilename "[FAILED] - There was an issue Disconnecting NSX Manager server ($($nsxmanager))." 1 "full"
    }
}
else
{
    write-and-log $logfilename "[FAILED] - There was an issue COnnecting NSX Manager server ($($nsxmanager))." 1 "full"
} 
