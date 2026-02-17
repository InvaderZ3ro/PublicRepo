$ip = ipconfig /all
$ip | out-file -filepath "Z:\$env:computername.txt
#to invoke the script
#  $scriptContent = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/InvaderZ3ro/PublicRepo/refs/heads/main/test.ps1" -UseBasicParsing
#  $scriptBlock = [Scriptblock]::Create($scriptContent.Content)
#  Invoke-Command -ScriptBlock $scriptBlock


$LogFileName = 'ScriptLog.txt'
$USBDrive = "Z\:"
New-item -Path $USBDrive -Name $LogFileName -ItemType "file" -Force | Out-Null
$LogFile = $USBDrive + $LogFilename

# Display banner and version
$banner = @"

███████╗███████╗██╗   ██╗    ██████╗ ██╗   ██╗██╗██╗     ██████╗ ███████╗██████╗ 
██╔════╝██╔════╝██║   ██║    ██╔══██╗██║   ██║██║██║     ██╔══██╗██╔════╝██╔══██╗
█████╗  █████╗  ██║   ██║    ██████╔╝██║   ██║██║██║     ██║  ██║█████╗  ██████╔╝
██╔══╝  ██╔══╝  ██║   ██║    ██╔══██╗██║   ██║██║██║     ██║  ██║██╔══╝  ██╔══██╗
██║     ██║     ╚██████╔╝    ██████╔╝╚██████╔╝██║███████╗██████╔╝███████╗██║  ██║
╚═╝     ╚═╝      ╚═════╝     ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝
                                                                                                                                                                
"@
Write-Host $banner -ForegroundColor Cyan
#Apply FFU
$FFUFileToInstall = "Z:\Win11_current.ffu"
$PhysicalDeviceID = "\\.\PhysicalDisk0"
#In order for Applying Image progress bar to show up, need to call dism directly. Might be a better way to handle, but must have progress bar show up on screen.
dism /apply-ffu /ImageFile:$FFUFileToInstall /ApplyDrive:$PhysicalDeviceID

Write-Host "Setting Windows Boot Manager to be first in the firmware display order."
Invoke-Process bcdedit.exe "/set {fwbootmgr} displayorder {bootmgr} /addfirst"
Write-Host "Setting Windows Boot Manager to be first in the default display order."
Invoke-Process bcdedit.exe "/set {bootmgr} displayorder {default} /addfirst"
