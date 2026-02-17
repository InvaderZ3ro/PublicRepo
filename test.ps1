$ip = ipconfig /all
$ip | out-file -filepath "Z:\$env:computername.txt

$USBDrive = "Z\:"
#Apply FFU
$FFUFileToInstall = '$USBDrive\Win11_current.ffu'
$PhysicalDeviceID = '\\.\PhysicalDisk0'
#In order for Applying Image progress bar to show up, need to call dism directly. Might be a better way to handle, but must have progress bar show up on screen.
dism /apply-ffu /ImageFile:$FFUFileToInstall /ApplyDrive:$PhysicalDeviceID
Invoke-Process bcdedit.exe "/set {fwbootmgr} displayorder {bootmgr} /addfirst"
Invoke-Process bcdedit.exe "/set {bootmgr} displayorder {default} /addfirst"
