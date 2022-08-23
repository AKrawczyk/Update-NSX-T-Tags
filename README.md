# Update-NSX-T-Tags
PowerShell script to Remove/Add (Reset), Export and Import NSX-T Tags

The script has 4 options;
1. Reset All VMs NSX-T Tags<br> 
  This is done my removing the NST-T Tags from VM and then Restoring the orignal NSX-T Tags to the VM.<br> 
  This process is applied to each VM managed by NSX-T<br> 
  Requires: NSX-T manager IP/FQDN and Admin credentials<br> 
  
2. Reset Single VMs NSX-T Tags<br> 
  This is done my removing the NST-T Tags from VM and then Restoring the orignal NSX-T Tags to the VM.<br> 
  This process is applied to a single VM managed by NSX-T<br> 
  Requires: Name of VM, NSX-T manager IP/FQDN and Admin credentials<br> 
  
3. Export to CSV<br> 
  This exports a list of all VM Names, There NSX-T External UID and There NSX-T Tags<br> 
  This process is applied to each VM managed by NSX-T<br> 
  This can also be considered a backup of the NSX-T Tags applied to the VMs<br> 
  Files is save to the same location as the PowerShell Script.<br> 
  Requires: NSX-T manager IP/FQDN and Admin credentials<br> 
  
4. Import from CSV<br> 
  This imports a list of VM Names, There NSX-T External UID and There NSX-T Tags<br> 
  This process is applied to each VM in the csv and managed by NSX-T<br> 
  This can also be considered a Restore of the NSX-T Tags applied to the VMs<br> 
  The CSV can also be midified to just be applied to specific VM.<br> 
  The CSV file can also be modified to change (Add or Remove) NSX-T Tags<br> 
  Requires: CSV file location, NSX-T manager IP/FQDN and Admin credentials<br> 
  
The PowerShell Script creates a logs file each time it is run.<br> 
The log file contains output for each stem of the process.<br> 
