# Documentation home: https://github.com/engrit-illinois/Audit-StaleADComputersInOU
# By mseng3 and kxue2, Summer 2019

function Audit-StaleADComputersInOU {
<#
.SYNOPSIS
	Version 1.1
	Exports a list of AD Computer objects to the screen, and optionally to a CSV formatted file.
	Optionally take other actions on returned objects.
	Results are from one or more given OU DNs, and filtered by LastLogonTimeStamp.

.DESCRIPTION
	Exports a list of AD Computer objects to the screen, and optionally to a CSV formatted file.
	Results are from one or more given OU DNs, and filtered by LastLogonTimeStamp.

.PARAMETER OUDNs
	Semicolon-separated list of Distinguished Names (DN) of the OUs to parse.
	e.g. "OU=BasicSupport,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"
	or "OU=BasicSupport,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu;OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"

.PARAMETER DaysInactive
	Number of preceding days during which objects returned must have been inactive (based on "LastLogonTimeStamp" AD attribute).
	Will not return/operate on objects with a LastLoginTimeStamp attribute that has not been set (i.e. have never been logged into).

.PARAMETER OverwriteCSV
	Specify with -ExportToCSV to allow an existing CSV file to be overwritten.
	Must be specified before -ExportToCSV in the parameter order.

.PARAMETER ExportToCSV
	Specify the full filepath to a file.
	Results will be exported in CSV format to that file.
	Parent directory must exist.
	Omit to export nothing and create no file.
	
.PARAMETER Disable
	Specify to disable the returned objects.
	Omit to not do that.

.PARAMETER AddNote
	Specify to prepend object descriptions with given string in the format "Note: <Date> <AddNote>, "
	If the 4 characters "<ou>" are found in the given string, they will be replaced with the object's original OU (useful in combination with -MoveToOUDN).
	If modified description is calculated to be longer than the max AD description length (1024), the note will be truncated from the end to fit.
	Omit to leave descriptions unchanged.

.PARAMETER MoveToOUDN
	Specify an OU DN to which returned objects should be moved.
	Omit to leave objects in place.
	
.PARAMETER OSFilter
	Specify a string which will be compared to the "operatingSystem" attribute of returned objects.
	If the string does not match the value of the attribute, the object will be ignored entirely.
	If omitted, a default value of "*windows*" will be used.
	
.PARAMETER Log
	Specify a filepath to a log file to log all output to.
	Will overwrite an existing log with the same name.
	Omit to generate no log file.

.INPUTS
	Semicolon-separated list of OUDNs and a number of days during which returned objects must not have been logged into.

.OUTPUTS
	Console screen output.
	Optionally logs console output to a log file at the given filepath.
	Optionall outputs returned data to a CSV-formatted file at the given filepath.
	Optionally disables returned objects.
	Optionally moves returned objects to given valid OU.
	Optionally modifies the descriptions of returned objects.

.EXAMPLE
	This example will do the following:
		Return all computers objects in the "Engineering/MobileDevices/BasicSupport/MechSE/Muskin" OU which have a LastLogonTimeStamp older than 1 year
		Display these objects and their relevant (current) data to the console screen
		Output everything seen on the screen to .\test.log
		Output the data in CSV format to .\test.csv, overwriting that file if it exists
		Modify the objects' descriptions by prepending them with "Note: <Date> Moved from ad.uillinois.edu/Urbana/Engineering/MobileDevices/BasicSupport/MechSE/Muskin, "
		Disable all the objects, regardless of whether they are already disabled
		Move all the objects to the "Engineering/MobileDevices/BasicSupport/2019-stale-object-audit" OU
	
	PS> Import-Module .\Audit-StaleADComputersInOU.ps1
	PS> Audit-StaleADComputersInOU -OUDNs "OU=Muskin,OU=MechSE,OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu" -DaysInactive 365 -AddNote "Moved from <ou>" -Disable -MoveToOUDN "OU=2019-stale-object-audit,OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu" -OverwriteCSV -ExportToCSV .\test.csv -Log .\test.log

.NOTES
	This script supports the -WhatIf flag, but know that it will make the output very hard to read.
	To reload the script as a module after making an edit when the module is already loaded, use: Import-Module <script>.ps1 -force
	By Matt Seng (mseng3) and Kaiwen Xue (kxue2), Summer 2019
	
#>


	[CmdletBinding(SupportsShouldProcess=$true)]

	# Comment-based help: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help?view=powershell-6
	# Note: comment-based help syntax cannot be indented
	# Advanced powershell function: https://www.petri.com/anatomy-powershell-advanced-function
	# WhatIf support: https://foxdeploy.com/2014/09/04/adding-whatif-support-to-your-scripts-the-right-way-and-how-you-shouldnt-do-it/

	param(
		[Parameter(Mandatory=$true)]
		[string]$OUDNs,
		
		[Parameter(Mandatory=$true)]
		[string]$DaysInactive = 365,
		
		# Param validation: https://4sysops.com/archives/validating-file-and-folder-paths-in-powershell-parameters/
		[ValidateScript({
			# Parent directory
			$path = Split-Path -Path $_
			
			# Check parent directory exists
			if(!(Test-Path $path)) {
				throw "$path directory doesn't exist!"
			}
			# Check parent directory is actually a directory
			if(!(Test-Path $path -PathType Container)) {
				throw "$path is not a directory!"
			}
			# Check file doesn't already exist
			if(Test-Path $_){
				if($OverwriteCSV) {
					
				}
				else {
					throw "$_ already exists!"
				}
			}
			return $true
		})]
		[System.IO.FileInfo]$ExportToCSV,
		
		[switch]$OverwriteCSV,
		
		[switch]$Disable,
		
		[string]$AddNote,
		
		[ValidateScript({
			$ou = $_
		
			# Check that OU exists
			$exists = $false
			
			# https://stackoverflow.com/questions/32581359/check-if-ou-exists-not-working-properly
			try{
				(Get-ADOrganizationalUnit -Identity $_)
				$exists = $true
			}
			catch{
				#write-output $test | out-file ".\test.log"
				throw "`nMoveToOUDN could not be found: `"$ou`"`n"
			}
			return $true
		})]
		[string]$MoveToOUDN,
		
		[string]$OSFilter="*windows*",
		
		[ValidateScript({
			# Parent directory
			$path = Split-Path -Path $_
			
			# Check parent directory exists
			if(!(Test-Path $path)) {
				throw "$path directory doesn't exist!"
			}
			# Check parent directory is actually a directory
			if(!(Test-Path $path -PathType Container)) {
				throw "$path is not a directory!"
			}
			return $true
		})]
		[System.IO.FileInfo]$Log
	)
	
	# Static variables
	$MAX_AD_DESC_LENGTH = 1024
	
	# A hack because I can't use $PSBoundParameters inside a function, since it is local to the function
	$global:logSpecified = $PSBoundParameters.ContainsKey('Log')
	
	$global:logCreated = $false
	function log {
		param(
			[string]$Msg = " ",
			[int]$level = 0,
			[switch]$NoStamp
		)
		
		# Generate indentation based on $level
		$indent = "    "
		for($i = 0; $i -lt $level; $i += 1) {
			$Msg = $indent + $Msg
		}
		
		# Timestamp the msg
		$timestamp = get-date -uformat "%Y-%m-%d %T"
		if(!$NoStamp) {
			$Msg = "[$timestamp] $Msg"
		}
		
		# If the log hasn't been created yet, either create it by logging a msg without -append,
		if(!$global:logCreated) {
			if($global:logSpecified) {
				$logCreatedMsg = "[$timestamp] Starting log file: $Log."
				write-output $logCreatedMsg
				write-output $logCreatedMsg | out-file $Log
			}
			# or output a msg that it will not be created
			else {
				write-output "[$timestamp] -Log was not specified. Skipping log file creation."
			}
			# Mark log as created either way to avoid checking again
			$global:logCreated = $true
		}
				
		# If -Log was specified, log the msg
		if($global:logSpecified) {
			write-output $Msg | out-file $Log -append
		}
		
		# Output the msg
		write-output $Msg
	}
	
	# Check whether a string is null or empty and if so, give it a value represent those states
	# Otherwise return the original value
	function translateNullOrEmpty($t) {
		if($t -eq $null) {
			return "[null]"
		}
		if($t.length -lt 1) {
			return "[empty string]"
		}
		return $t
	}
	
	# True if a value was determined to me null or empty
	# Not ideal for values that are ACTUALLY "[null]" or "[empty string]", but this should never happen in practice
	function isNullOrEmpty($t) {
		if($t -eq "[null]") {
			return $true
		}
		if($t -eq "[empty string]") {
			return $true
		}
		return $false
	}
	
	# Dates in AD are usually stored in FileTime (a.k.a. ticks) format
	# Translate to DateTime
	function FileTimeToDateTime($t) {
		$t = translateNullOrEmpty($t)
		if(isNullOrEmpty($t)) {
			return $t
		}
		return [DateTime]::FromFileTime($t)
	}
	
	# Translate DateTime to ISO date format
	function DateTimeToISODate($t) {
		$t = translateNullOrEmpty($t)
		if(isNullOrEmpty($t)) {
			return $t
		}
		return Get-Date $t -UFormat "%Y-%m-%d %T"
	}
	
	# Translate FileTime to ISO date format
	function FileTimeToISODate($t) {
		$t = translateNullOrEmpty($t)
		if(isNullOrEmpty($t)) {
			return $t
		}
		return DateTimeToISODate(FileTimeToDateTime($t))
	}
	
	# Log relevant object properties
	function logObject($object) {
		log -nostamp
		log "Object: $($object.Name)"
		log -level 1 "Current attributes:"
		
		$LastLogonTimeStamp = FileTimeToISODate($object.LastLogonTimeStamp)
		log -level 2 "LastLogonTimeStamp: $LastLogonTimeStamp ($($object.LastLogonTimeStamp))"
		
		$LastLogonDate = DateTimeToISODate($object.LastLogonDate)
		log -level 2 "LastLogonDate: $LastLogonDate ($($object.LastLogonDate))"
		
		$LastLogon = FileTimeToISODate($object.LastLogon)
		log -level 2 "LastLogon: $LastLogon ($($object.LastLogon))"
		
		$LastLogoff = translateNullOrEmpty($object.LastLogoff)
		log -level 2 "LastLogoff: $LastLogoff ($($object.LastLogoff))"
		
		log -level 2 "Enabled: $($object.Enabled)"
		log -level 2 "OperatingSystem: $($object.OperatingSystem)"
		log -level 2 "Description: $($object.Description)"
		log -level 2 "OU: $($object.CanonicalName)"
		log -level 2 "OUDN: $($object.DistinguishedName)"
	}
	
	# Export relevant info in CSV format about given objects to given file
	function exportObjects($objects, $ouNum) {
		# Select only desired properties from filtered objects
		$csvObjects = $objects | select-object `
			Name,`
			LastLogonTimestamp,`
			@{Name="LastLogonTimeStampFormatted";Expression={FileTimeToISODate($_.LastLogonTimeStamp)}},`
			LastLogonDate,`
			@{Name="LastLogonDateFormatted";Expression={DateTimeToISODate($_.LastLogonDate)}},`
			LastLogon,`
			@{Name="LastLogonFormatted";Expression={FileTimeToISODate($_.LastLogon)}},`
			LastLogoff,`
			@{Name="LastLogoffFormatted";Expression={translateNullOrEmpty($_.LastLogoff)}},`
			Enabled,`
			OperatingSystem,`
			Description,`
			CanonicalName,`
			DistinguishedName
			
		if($ouNum -eq 1) {
			$csvObjects | export-csv $ExportToCSV -notypeinformation
		}
		else {
			$csvObjects | export-csv $ExportToCSV -notypeinformation -append
		}
	}
	
	# Disable given AD object
	function disableObject($object) {
		log -level 1 "Disabling object..."
		
		if($object.Enabled) {
			# Do it
			Disable-ADAccount -Identity $object.DistinguishedName -ErrorVariable errorDisable
			
			# Disable-ADAccount returns no output, so check for errors instead
			$errorDisable = translateNullOrEmpty($errorDisable)
			if(isNullorEmpty($errorDisable)) {
				$errorDisable = "None"
			}
			log -level 2 "Error: $errorDisable"
		}
		else {
			log -level 2 "Object is already disabled."
		}
	}
	
	# Prepend given object's description with given note
	function addNoteToDesc($object) {
		log -level 1 "Prepending note to description..."
		
		log -level 2 "Note: `"$AddNote`""
		
		$noteDate = Get-Date -UFormat "%Y-%m-%d"
		$noteReplaced = $AddNote.replace('<ou>',$object.canonicalname)
		$noteDated = "Note: $noteDate $noteReplaced"
		log -level 2 "Final Note: `"$noteDated`""
		
		$newDesc = "$noteDated, $($object.Description)"
		$newDescLength = $newDesc.length
		log -level 2 "New description ($newDescLength chars): `"$newDesc`""
		
		# Truncate note if resulting description is too long
		if($newDescLength > $MAX_AD_DESC_LENGTH) {
			log -level 2 "New description length is greater than max AD description length ($MAX_AD_DESC_LENGTH)."
			log -level 2 "Truncating note to fit..."
			
			$noteOverBy = $newDescLength - $MAX_AD_DESC_LENGTH
			$newNoteLength = $noteDate.length - $noteOverBy
			$newNote = $noteDated.substring(0, $newNoteLength)
			log -level 3 "Truncated note: `"$newNote`""
			
			$newDesc = "$newNote, $($object.Description)"
			$newDescLength = $newDesc.length
			log -level 3 "New description ($newDescLength chars): `"$newDesc`""
		}
		
		# Do it
		Set-ADComputer -Identity $object.DistinguishedName -Description $newDesc -ErrorVariable errorDesc
		
		# Set-ADComputer returns no output, so check for errors instead
		$errorDesc = translateNullOrEmpty($errorDesc)
		if(isNullorEmpty($errorDesc)) {
				$errorDesc = "None"
		}
		log -level 2 "Error: $errorDesc"
	}
	
	# Move given object to given OUDN
	function moveObject($object) {
		log -level 1 "Moving object to $MoveToOUDN..."
		
		# Do it
		Move-ADObject -Identity $object.DistinguishedName -TargetPath $MoveToOUDN -ErrorVariable errorMove
		
		# Move-ADObject returns no output, so check for errors instead
		$errorMove = translateNullOrEmpty($errorMove)
		if(isNullorEmpty($errorMove)) {
				$errorMove = "None"
		}
		log -level 2 "Error: $errorMove"
	}
	
	# Get timestamp of "last inactive date"
	$time = (Get-Date).Adddays(-($DaysInactive))
	# Track number of OUDN. Used to avoid improper CSV formatting when multiple OUDNs are given
	$ouNum = 0
	
	$oudnArray = $OUDNs -split ";"
	foreach($oudn in $oudnArray) {
		$ouNum += 1
		
		# Get all objects from desired OU, appropriately filtered by LastLogonTimStamp
		# Definitions of the different "Last Logon" fields: https://serverfault.com/questions/734615/lastlogon-vs-lastlogontimestamp-in-active-directory
		# Note, this doesn't return objects which have no LastLoginTimeStamp set (i.e. have never been logged into)
		# I feel like I should need to quote $OSFilter in $filterString, but can't figure out how
		# https://stackoverflow.com/questions/51623182/filter-by-two-properties-with-get-aduser
		#$filterString = "LastLogonTimeStamp -lt `"$time`" -and OperatingSystem -like `"$OSFilter`""
		$filterString = 'LastLogonTimeStamp -lt $time -and OperatingSystem -like $OSFilter'
		$objects = Get-ADComputer -SearchBase $oudn -Filter $filterString -Properties *
		$objects = $objects | Sort-Object LastLogonTimeStamp
		$objects = $objects | Select-Object Name,LastLogonTimeStamp,LastLogonDate,LastLogon,LastLogoff,Enabled,Description,CanonicalName,DistinguishedName,OperatingSystem
		
		# Export results if requested
		# How to (properly) tell if a string param was specified:
		# https://stackoverflow.com/questions/48643250/how-to-check-if-a-powershell-optional-argument-was-set-by-caller
		if($PSBoundParameters.ContainsKey('ExportToCSV')) {
			exportObjects $objects $ouNum
		}
		else {
			log "-ExportToCSV was omitted. No data will be exported."
		}
		
		foreach($object in $objects) {
			# Log relevant object properties
			logObject $object
			
			# Disable objects if requested
			if($Disable) {
				disableObject $object
			}
			else {
				log -level 1 "-Disable was omitted. Object will not be disabled."
			}
			
			# Add note to object descriptions if requested
			if($PSBoundParameters.ContainsKey('AddNote')) {
				addNoteToDesc $object
			}
			else {
				log -level 1 "-AddNote was omitted. Object description will not be modified."
			}
			
			# Move objects if requested
			if($PSBoundParameters.ContainsKey('MoveToOUDN')) {
				moveObject $object
			}
			else {
				log -level 1 "-MoveTo was omitted. Object will not be moved."
			}
		}
		
		# Output number of objects for quick reference
		$objectCount = @($objects).count
		log -nostamp
		log "$objectCount matching objects in OU: `"$oudn`""
	}
}






