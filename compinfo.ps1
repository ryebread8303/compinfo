﻿#______________________________________________________________________________
# compinfo.ps1
# O'Ryan Hedrick 09/12/2018
# 
# Script collects computer serialnumber, model number, bios revision, disk size
# and freespace, total RAM installed, current time zone, domain, user name,
# and computer hostname. Once this information is collected, the script 
# an option to send the output file via email.
# 
# To run this script against remote machines, call it from the command line and
# supply the hostname or ip to the computer parameter.
# 
# The script uses PowerShell 2, and should run on any Winows 7 machine without
# having to install software.
# _____________________________________________________________________________

#requires -Version 2.0

# pass the computer argument to the script to run against a remote host, or by
# default run against the localhost
Param(
    [Parameter(Mandatory=$true)]
    $computer = "localhost", 
    [system.management.automation.credentialattribute()]
    $credential,
    [switch]
    $noemail
    )

# *** function declaration ***
function send-assetinfo {
<#
  .SYNOPSIS
    Sends the asset information to an email box as an attachment.
  .EXAMPLE
    send-assetinfo
    No arguments are needed, the function will prompt the user for needed information.
#>
    if ($credential -eq $null) {$credential = get-credential}
    if ($email -eq $null) {$email = read-host -prompt "Enter the email address you wish to send the computer information to."}
    $name = $computersystem.dnshostname # used to provide an identifier in the subject line of the email
    $subject = "Asset information for $name"
    send-mailmessage -to $email -from $email -Subject $subject -attachments $file -smtp $smtp -credential $credential
} # end send-assetinfo

<#
    .SYNOPSIS
    Prompt user to make a selection.
    
    .DESCRIPTION
    The new-menu function provides a cmdlet front-end to the $host.ui.promptforchoice prompts.
    
    .PARAMETER Options
    This is an array containing the options being presented to the user.
    
    .PARAMETER Caption
    This is a string containing the caption of the prompt.
    
    .PARAMETER Message
    This is a string containing the message in the prompt.

    .PARAMETER Multiple
    This is a switch that allows multiple selections from the menu

    .PARAMETER Default
    This should be an integer if Multiple is False, or an INT array if Multiple is True. This sets 
    an item or items as a default choice, so it will be selected if the user makes no selections.
    If -1, no defaults will be picked.
    
    .INPUTS
    This function does not accept input from the pipeline.
    
    .OUTPUTS
    This function outputs the index of the chosen menu option.
    
    .NOTES
    Author: O'Ryan Hedrick
    Date: 05/22/2018
#>
function New-Menu {
    param([Parameter(mandatory = $true)][array]$Options,
        [string]$Caption,
        [string]$Message,
        [switch]$Multiple,
        $Default = -1)
    if ($Multiple) {$style = [int[]]($default)} else {$style = $default}
    $choices = [system.management.automation.host.choicedescription[]] $options
    $prompt = $host.ui.promptforchoice($caption,$message,$choices,$style)
    $prompt
} # function new-menu


# *** query WMI for information ***
$gwmiargs = @{'computername'=$computer}

# if a computername was provided, add the credentials to the arguments sent to Get-WMIObject
# if no computername was provided, then credentials are not needed
if ($computer -ne "localhost"){$gwmiargs.add('credential',$credential)}

#write-debug $credential.username

$disks = get-wmiobject @gwmiargs -query "SELECT deviceid,description,providername FROM win32_logicaldisk" | 
select-object deviceid,description,providername
$bios = get-wmiobject @gwmiargs -query "SELECT serialnumber,smbiosbiosversion FROM win32_bios" | 
select-object serialnumber,smbiosbiosversion
$computersystem = get-wmiobject @gwmiargs -query "SELECT currenttimezone,domain,model,totalphysicalmemory,username,dnshostname FROM win32_computersystem" | 
select-object currenttimezone,domain,model,totalphysicalmemory,username,dnshostname
$operatingsystem = Get-WmiObject @gwmiargs -Query "SELECT freephysicalmemory,freespaceinpagingfiles,caption,csdversion,osarchitecture FROM win32_operatingsystem" |
Select-Object freephysicalmemory,freespaceinpagingfiles,caption,csdversion,osarchitecture
$paging = Get-WmiObject @gwmiargs -query "SELECT name,percentusage,percentusagepeak FROM Win32_PerfFormattedData_PerfOS_PagingFile" |
Select-Object name,percentusage,percentusagepeak
$diskperf = Get-WmiObject @gwmiargs -Query "SELECT name,freemegabytes,percentfreespace,percentidletime,currentdiskqueuelength FROM Win32_PerfFormattedData_PerfDisk_LogicalDisk" |
Select-Object name,freemegabytes,percentfreespace,percentidletime,currentdiskqueuelength
$printer = Get-WmiObject @gwmiargs -query "SELECT name,deviceid,default FROM win32_printer" |
Select-Object name,deviceid,default

 
# *** change the byte measurements to GB ***
# the conversion is accomplished by dividing the measurements by 2 raised to the 30th power
$computersystem.totalphysicalmemory = [math]::round(($computersystem.totalphysicalmemory / [math]::pow(2,30)),2)
$operatingsystem.freephysicalmemory = [math]::round(($operatingsystem.freephysicalmemory / [math]::pow(2,20)),2)
$operatingsystem.freespaceinpagingfiles = [math]::round(($operatingsystem.freespaceinpagingfiles / [math]::pow(2,20)),2)

# compute freespace on logical disks
#$disks | ForEach-Object {$_ | add-member -type noteproperty -name PercentFreespace -value ([math]::round($_.freespace / $_.size,2) * 100)}

# *** change time zone to hours offset instead of minutes offset by divideing by 60 ***
$computersystem.currenttimezone = $computersystem.currenttimezone / 60

# *** output to a text file ***
New-Variable -Name file -Description "The name of the ASCII text file that will hold the output" -Value "compinfo-$($computersystem.dnshostname).txt" -ErrorAction "silentlycontinue"

write-debug "Creating $file and writing information to it."
get-date -uformat "%T %D" | out-file $file
$bios | format-list | out-file $file -append
$computersystem | out-file $file -append
$operatingsystem | Out-File $file -append
$disks | format-table | out-file $file -append
$diskperf | Format-Table | Out-File $file -Append
$printer | Format-Table | Out-File $file -Append
$paging | Out-File $file -Append




#display a menu asking if the user wants to email this file
$options = @("&Yes","&No")
$message = "Do you want to send this info to an email address?"
$caption = "Email?"
$prompt = new-menu -options $options -Message $message -Caption $caption
if ($prompt -eq 0) {send-assetinfo}
