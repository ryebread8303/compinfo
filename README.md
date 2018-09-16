# compinfo.ps1
Script collects computer serialnumber, model number, bios revision, disk size
and freespace, total RAM installed, current time zone, domain, user name,
and computer hostname. Once this information is collected, the script 
an option to send the output file via email.

To run this script against remote machines, call it from the command line and
supply the hostname or ip to the computer parameter.

The script uses PowerShell 2, and should run on any Winows 7 machine without
having to install software.
