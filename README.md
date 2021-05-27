# Summary
This script reports on AD computer objects in a given OU which have a LastLoginTimeStamp older than a given age.  
By default this data is reported to the console screen.  
There are optional switches for exporting data to a CSV-formatted file, disabling the objects, modifying their descriptions, and moving them.  

# Setup and Requirements

### Requirements

- A Powershell console run as your SU account

### Installation:

1. Download `Audit-StaleADComputersInOU.psm1` to `$HOME\Documents\WindowsPowerShell\Modules\Audit-StaleADComputersInOU\Audit-StaleADComputersInOU.psm1`.
    - The module is now already available for use with your regular account, however for many features to work, it needs to modify AD objects which likely only your SU account will have access to.
    - To make the module available as your SU account: see [here](https://github.com/engrit-illinois/how-to-run-custom-powershell-modules-as-another-user).
2. Run it using the provided example syntax as a guide.

### Permissions:

You may need to set the Powershell ExecutionPolicy for the script if it is not digitally signed.  
You can do this temporarily by setting the execution policy to bypass for only the current PowerShell session:  

`PS> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

# Usage and parameters

See top of script file for documentation. A copy of this is provided below for convenience.  
Once the module is imported, you can run the following command to output the documentation to the console:  

`PS> Get-Help Audit-StaleADComputersInOU -Full`

# Output

See included `test.log` and `test.csv` files for example output.

# Examples

### Example #1

This example will do the following:
1. Return all computers objects in the `Engineering/MobileDevices/BasicSupport/MechSE/Muskin` OU which have a LastLogonTimeStamp older than 1 year
1. Display these objects and their relevant (current) data to the console screen
1. Output everything seen on the screen to `.\test.log`
1. Output the data in CSV format to `.\test.csv`, overwriting that file if it exists
1. Nothing else
	
```
PS> Import-Module .\Audit-StaleADComputersInOU.psm1
PS> Audit-StaleADComputersInOU -OUDNs "OU=Muskin,OU=MechSE,OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu" -DaysInactive 365 -OverwriteCSV -ExportToCSV .\test.csv -Log .\test.log
```

### Example #2

This example will do the following:
1. Return all computers objects in the `Engineering/MobileDevices/BasicSupport/MechSE/Muskin` OU which have a LastLogonTimeStamp older than 1 year
1. Display these objects and their relevant (current) data to the console screen
1. Output everything seen on the screen to `.\test.log`
1. Output the data in CSV format to `.\test.csv`, overwriting that file if it exists
1. Modify the objects' descriptions by prepending them with the string: `Note: <Date> Moved from ad.uillinois.edu/Urbana/Engineering/MobileDevices/BasicSupport/MechSE/Muskin, `
1. Disable all the objects, regardless of whether they are already disabled
1. Move all the objects to the `Engineering/MobileDevices/BasicSupport/2019-stale-object-audit` OU
	
```
PS> Import-Module .\Audit-StaleADComputersInOU.psm1
PS> Audit-StaleADComputersInOU -OUDNs "OU=Muskin,OU=MechSE,OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu" -DaysInactive 365 -AddNote "Moved from <ou>" -Disable -MoveToOUDN "OU=2019-stale-object-audit,OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu" -OverwriteCSV -ExportToCSV .\test.csv -Log .\test.log
```
    
# Copy of in-script documentation (v1.1)

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
	e.g. `OU=BasicSupport,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu`  
	or `OU=BasicSupport,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu;OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu`  

.PARAMETER DaysInactive  
	Number of preceding days during which objects returned must have been inactive (based on the `LastLogonTimeStamp` AD attribute).  
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
	Specify to prepend object descriptions with given string in the format "Note: <Date> <AddNote>, ".  
	If the 4 characters "<ou>" are found in the given string, they will be replaced with the object's original OU (useful in combination with -MoveToOUDN).  
	If modified description is calculated to be longer than the max AD description length (1024), the note will be truncated from the end to fit.  
	Omit to leave descriptions unchanged.  

.PARAMETER MoveToOUDN  
	Specify an OU DN to which returned objects should be moved.  
	Omit to leave objects in place.  
	
.PARAMETER OSFilter  
	Specify a string which will be compared to the "operatingSystem"   attribute of returned objects.  
	If the string does not match the value of the attribute, the object will be ignored entirely.  
	If omitted, a default value of "\*windows\*" will be used.  
	
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
		Return all computers objects in the `Engineering/MobileDevices/BasicSupport/MechSE/Muskin` OU which have a LastLogonTimeStamp older than 1 year  
		Display these objects and their relevant (current) data to the console screen, and output the data in CSV format to .\test.csv, overwriting that file if it exists  
		Modify the objects' descriptions by prepending them with `Note: <Date> Moved from ad.uillinois.edu/Urbana/Engineering/MobileDevices/BasicSupport/MechSE/Muskin, `  
		Disable all the objects, regardless of whether they are already disabled  
		Move all the objects to the `Engineering/MobileDevices/BasicSupport/2019-stale-object-audit` OU  
```	
	PS> Import-Module .\Audit-StaleADComputersInOU.psm1
	PS> Audit-StaleADComputersInOU -OUDNs "OU=Muskin,OU=MechSE,OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu" -DaysInactive 365 -AddNote "Moved from <ou>" -Disable -MoveToOUDN "OU=2019-stale-object-audit,OU=BasicSupport,OU=MobileDevices,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu" -OverwriteCSV -ExportToCSV .\test.csv -Log .\test.log
```

.NOTES  
	This script supports the -WhatIf flag, but know that it will make the output very hard to read.  
	To reload the script as a module after making an edit when the module is already loaded, use: `PS> Import-Module <script>.psm1 -Force`  
	By Matt Seng (mseng3) and Kaiwen Xue (kxue2), Summer 2019  
	
# Notes
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
