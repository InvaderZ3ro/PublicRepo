$ip = ipconfig /all
$ip | out-file -filepath "Z:\$env:computername.txt
#to invoke the script
#  $scriptContent = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/InvaderZ3ro/PublicRepo/refs/heads/main/test.ps1" -UseBasicParsing
#  $scriptBlock = [Scriptblock]::Create($scriptContent.Content)
#  Invoke-Command -ScriptBlock $scriptBlock




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
Write-Host "Version $version" -ForegroundColor Cyan

# Select target disk - prompt user if multiple disks found
if ($diskCount -eq 1) {
    $selectedDisk = $diskDriveCandidates[0]
    WriteLog "Single fixed disk detected: DiskNumber=$($selectedDisk.Index), Model=$($selectedDisk.Model)"
    Write-Host "Single fixed disk detected: $($selectedDisk.Model)"
}
else {
    WriteLog "Found $diskCount fixed disks. Prompting for selection."
    Write-Host "Found $diskCount fixed disks"
    
    # Build list of available disk indexes for validation
    $validDiskIndexes = @($diskDriveCandidates | ForEach-Object { $_.Index })
    
    # Display disk list using actual disk index as the selection value
    $displayList = @()
    foreach ($currentDisk in $diskDriveCandidates) {
        $sizeGB = [math]::Round(($currentDisk.Size / 1GB), 2)
        $displayList += [PSCustomObject]@{
            Disk         = $currentDisk.Index
            'Size (GB)'  = $sizeGB
            'Sector'     = $currentDisk.BytesPerSector
            'Bus Type'   = $currentDisk.InterfaceType
            Model        = $currentDisk.Model
        }
    }
    $displayList | Format-Table -AutoSize -Property Disk, 'Size (GB)', Sector, 'Bus Type', Model

    do {
        try {
            $var = $true
            [int]$diskSelection = Read-Host 'Enter the disk number to apply the FFU to'
        }
        catch {
            Write-Host 'Input was not in correct format. Please enter a valid disk number'
            $var = $false
        }
        # Validate selected disk is in the list of available disks
        if ($var -and $validDiskIndexes -notcontains $diskSelection) {
            Write-Host "Invalid disk number. Please select from the available disks."
            $var = $false
        }
    } until ($var)

    $selectedDisk = $diskDriveCandidates | Where-Object { $_.Index -eq $diskSelection }
    WriteLog "Disk selection: DiskNumber=$($selectedDisk.Index), Model=$($selectedDisk.Model), SizeGB=$([math]::Round(($selectedDisk.Size / 1GB), 2)), BusType=$($selectedDisk.InterfaceType)"
    Write-Host "`nDisk $($selectedDisk.Index) selected: $($selectedDisk.Model)"
}

# Set variables from selected disk
$PhysicalDeviceID = $selectedDisk.DeviceID
$BytesPerSector = $selectedDisk.BytesPerSector
$DiskID = $selectedDisk.Index
$diskSizeGB = [math]::Round(($selectedDisk.Size / 1GB), 2)

# Create hardDrive object for Get-SystemInformation compatibility
$hardDrive = [PSCustomObject]@{
    DeviceID       = $PhysicalDeviceID
    BytesPerSector = $BytesPerSector
    DiskSize       = $selectedDisk.Size
    DiskNumber     = $DiskID
}

WriteLog "Physical DeviceID is $PhysicalDeviceID"
WriteLog "DiskNumber is $DiskID with size $diskSizeGB GB"

# Gather and write system information
$sysInfoObject = Get-SystemInformation -HardDrive $hardDrive
Write-SystemInformation -SystemInformation $sysInfoObject

#Find FFU Files
Write-SectionHeader 'FFU File Selection'
[array]$FFUFiles = @(Get-ChildItem -Path $USBDrive*.ffu)
$FFUCount = $FFUFiles.Count

#If multiple FFUs found, ask which to install
If ($FFUCount -gt 1) {
    WriteLog "Found $FFUCount FFU Files"
    Write-Host "Found $FFUCount FFU Files"
    $array = @()

    for ($i = 0; $i -le $FFUCount - 1; $i++) {
        $Properties = [ordered]@{Number = $i + 1 ; FFUFile = $FFUFiles[$i].FullName }
        $array += New-Object PSObject -Property $Properties
    }
    $array | Format-Table -AutoSize -Property Number, FFUFile | Out-Host
    do {
        try {
            $var = $true
            [int]$FFUSelected = Read-Host 'Enter the FFU number to install'
            $FFUSelected = $FFUSelected - 1
        }

        catch {
            Write-Host 'Input was not in correct format. Please enter a valid FFU number'
            $var = $false
        }
    } until (($FFUSelected -le $FFUCount - 1) -and $var) 

    $FFUFileToInstall = $array[$FFUSelected].FFUFile
    WriteLog "$FFUFileToInstall was selected"
}
elseif ($FFUCount -eq 1) {
    WriteLog "Found $FFUCount FFU File"
    Write-Host "Found $FFUCount FFU File"
    $FFUFileToInstall = $FFUFiles[0].FullName
    WriteLog "$FFUFileToInstall will be installed"
    Write-Host "$FFUFileToInstall will be installed"
} 
else {
    $errorMessage = 'No FFU files found.'
    Writelog $errorMessage
    Stop-Script -Message $errorMessage
}

#FindAP
$APFolder = $USBDrive + "Autopilot\"
If (Test-Path -Path $APFolder) {
    [array]$APFiles = @(Get-ChildItem -Path $APFolder*.json)
    $APFilesCount = $APFiles.Count
    if ($APFilesCount -ge 1) {
        $autopilot = $true
    }
}
 
#Find Drivers
$DriversPath = $USBDrive + "Drivers"
$DriverSourcePath = $null
$DriverSourceType = $null # Will be 'WIM' or 'Folder'
$driverMappingPath = Join-Path -Path $DriversPath -ChildPath "DriverMapping.json"

If (Test-Path -Path $DriversPath) {
    Write-SectionHeader -Title 'Drivers Selection'
}

# --- Automatic Driver Detection using DriverMapping.json ---
if (Test-Path -Path $driverMappingPath -PathType Leaf) {
    WriteLog "DriverMapping.json found at $driverMappingPath. Attempting automatic driver selection."
    Write-Host "DriverMapping.json found. Attempting automatic driver selection."
    try {
        $driverMappings = Get-Content -Path $driverMappingPath | Out-String | ConvertFrom-Json -ErrorAction Stop
        $driverMappings = @($driverMappings) | Where-Object { $null -ne $_ }
        if ($driverMappings.Count -eq 0) {
            throw "DriverMapping.json does not contain any entries."
        }

        if ($null -eq $sysInfoObject) {
            $sysInfoObject = Get-SystemInformation -HardDrive $hardDrive
        }

        $identifierLabelForLog = $null
        $identifierValueForLog = $null
        if ($sysInfoObject.PSObject.Properties['Machine Type'] -and -not [string]::IsNullOrWhiteSpace($sysInfoObject.'Machine Type')) {
            $identifierLabelForLog = 'Machine Type'
            $identifierValueForLog = $sysInfoObject.'Machine Type'
        }
        elseif ($sysInfoObject.PSObject.Properties['System ID'] -and -not [string]::IsNullOrWhiteSpace($sysInfoObject.'System ID')) {
            $identifierLabelForLog = 'System ID'
            $identifierValueForLog = $sysInfoObject.'System ID'
        }
        else {
            $identifierLabelForLog = 'System ID'
            $identifierValueForLog = 'Not Detected'
        }
        WriteLog ("Detected System: Manufacturer='{0}', Model='{1}', {2}='{3}'" -f $sysInfoObject.Manufacturer, $sysInfoObject.Model, $identifierLabelForLog, $identifierValueForLog)
        Write-Host ("Detected System: Manufacturer='{0}', Model='{1}'" -f $sysInfoObject.Manufacturer, $sysInfoObject.Model)

        $matchedRule = Find-DriverMappingRule -SystemInformation $sysInfoObject -DriverMappings $driverMappings

        if ($null -ne $matchedRule) {
            WriteLog "Automatic match found: Manufacturer='$($matchedRule.Manufacturer)', Model='$($matchedRule.Model)'"
            Write-Host "Automatic match found: Manufacturer='$($matchedRule.Manufacturer)', Model='$($matchedRule.Model)'"
            $potentialDriverPath = Join-Path -Path $DriversPath -ChildPath $matchedRule.DriverPath

            if (Test-Path -Path $potentialDriverPath) {
                $DriverSourcePath = $potentialDriverPath
                if ($DriverSourcePath -like '*.wim') {
                    $DriverSourceType = 'WIM'
                }
                else {
                    $DriverSourceType = 'Folder'
                }
                WriteLog "Automatically selected driver source. Type: $DriverSourceType, Path: $DriverSourcePath"
                Write-Host "Automatically selected driver source. Type: $DriverSourceType, Path: $DriverSourcePath"
            }
            else {
                WriteLog "Matched driver path '$potentialDriverPath' not found. Falling back to manual selection."
                Write-Host "Matched driver path '$potentialDriverPath' not found. Falling back to manual selection."
            }
        }
        else {
            WriteLog "No automatic driver mapping rule matched identifiers for this system. Falling back to manual selection."
            Write-Host "No matching driver mapping rule was found for this system. Falling back to manual selection."
        }
    }
    catch {
        WriteLog "An error occurred during automatic driver detection: $($_.Exception.Message). Falling back to manual selection."
        Write-Host "An error occurred during automatic driver detection: $($_.Exception.Message). Falling back to manual selection."
    }
}
else {
    WriteLog "DriverMapping.json not found. Proceeding with manual driver selection."
}

# --- Manual Driver Selection (Fallback) ---
if ($null -eq $DriverSourcePath) {
    If (Test-Path -Path $DriversPath) {
        WriteLog "Searching for driver WIMs and folders in $DriversPath"
    
        # Collect all WIM-based driver sources anywhere under Drivers
        $wimFiles = Get-ChildItem -Path $DriversPath -Filter *.wim -File -Recurse -ErrorAction SilentlyContinue
        
        # Treat each immediate child folder as a manufacturer container (supports known and unknown vendors)
        $manufacturerFolders = Get-ChildItem -Path $DriversPath -Directory -ErrorAction SilentlyContinue
        $driversRootFullPath = (Get-Item -Path $DriversPath).FullName.TrimEnd('\')
        $relativePathResolver = {
            param(
                [string]$candidatePath,
                [string]$rootPath
            )
            try {
                $normalizedPath = [System.IO.Path]::GetFullPath($candidatePath)
                if ($normalizedPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $relativeSegment = $normalizedPath.Substring($rootPath.Length).TrimStart('\', '/')
                    if ([string]::IsNullOrWhiteSpace($relativeSegment)) {
                        return Split-Path -Path $normalizedPath -Leaf
                    }
                    return $relativePath = $relativeSegment
                }
                return $normalizedPath
            }
            catch {
                return $candidatePath
            }
        }

        # Create a combined list
        $DriverSources = @()
        foreach ($wimFile in $wimFiles) {
            $relativePath = & $relativePathResolver -candidatePath $wimFile.FullName -rootPath $driversRootFullPath
            $DriverSources += [PSCustomObject]@{
                Type         = 'WIM'
                Path         = $wimFile.FullName
                RelativePath = $relativePath
            }
        }
        foreach ($manufacturerFolder in $manufacturerFolders) {
            $modelFolders = Get-ChildItem -Path $manufacturerFolder.FullName -Directory -ErrorAction SilentlyContinue

            if ($null -eq $modelFolders -or $modelFolders.Count -eq 0) {
                if (Test-DriverFolderHasInstallableContent -Path $manufacturerFolder.FullName) {
                    $relativePath = & $relativePathResolver -candidatePath $manufacturerFolder.FullName -rootPath $driversRootFullPath
                    $DriverSources += [PSCustomObject]@{
                        Type         = 'Folder'
                        Path         = $manufacturerFolder.FullName
                        RelativePath = $relativePath
                    }
                    WriteLog "Using manufacturer folder '$($manufacturerFolder.FullName)' as a driver source because it contains installable content."
                }
                else {
                    WriteLog "Skipping '$($manufacturerFolder.FullName)' because it has no model folders with installable content."
                }
                continue
            }

            foreach ($modelFolder in $modelFolders) {
                if (-not (Test-DriverFolderHasInstallableContent -Path $modelFolder.FullName)) {
                    WriteLog "Skipping driver folder '$($modelFolder.FullName)' because no installable files were found."
                    continue
                }
                $relativePath = & $relativePathResolver -candidatePath $modelFolder.FullName -rootPath $driversRootFullPath
                $DriverSources += [PSCustomObject]@{
                    Type         = 'Folder'
                    Path         = $modelFolder.FullName
                    RelativePath = $relativePath
                }
            }
        }

        $DriverSourcesCount = $DriverSources.Count

        if ($DriverSourcesCount -gt 0) {
            WriteLog "Found $DriverSourcesCount total driver sources (WIMs and folders)."
            if ($DriverSourcesCount -eq 1) {
                $DriverSourcePath = $DriverSources[0].Path
                $DriverSourceType = $DriverSources[0].Type
                $selectedRelativePath = $DriverSources[0].RelativePath
                WriteLog "Single driver source found. Type: $DriverSourceType, Path: $DriverSourcePath, RelativePath: $selectedRelativePath"
                Write-Host "Single driver source found. Type: $DriverSourceType, RelativePath: $selectedRelativePath"
            }
            else {
                # Multiple sources found, prompt user
                WriteLog "Multiple driver sources found. Prompting for selection."
                $displayArray = @()
                for ($i = 0; $i -lt $DriverSourcesCount; $i++) {
                    $displayArray += [PSCustomObject]@{
                        Number       = $i + 1
                        Type         = $DriverSources[$i].Type
                        RelativePath = $DriverSources[$i].RelativePath
                        Path         = $DriverSources[$i].Path
                    }
                }
                $displayArray | Format-Table -Property Number, Type, RelativePath -AutoSize
                
                $DriverSelected = -1
                $skipDriverInstall = $false
                do {
                    try {
                        $var = $true
                        [int]$userSelection = Read-Host 'Enter the number of the driver source to install (0 to skip)'
                        if ($userSelection -eq 0) {
                            $skipDriverInstall = $true
                            break
                        }
                        $DriverSelected = $userSelection - 1
                    }
                    catch {
                        Write-Host 'Input was not in correct format. Please enter a valid number.'
                        $var = $false
                    }
                } until ((($DriverSelected -ge 0 -and $DriverSelected -lt $DriverSourcesCount) -or $skipDriverInstall) -and $var)
                
                if ($skipDriverInstall) {
                    $DriverSourcePath = $null
                    $DriverSourceType = $null
                    $selectedRelativePath = $null
                    WriteLog 'User chose to skip driver installation.'
                    Write-Host "`nDriver installation was skipped."
                }
                else {
                    $DriverSourcePath = $DriverSources[$DriverSelected].Path
                    $DriverSourceType = $DriverSources[$DriverSelected].Type
                    $selectedRelativePath = $DriverSources[$DriverSelected].RelativePath
                    WriteLog "User selected Type: $DriverSourceType, Path: $DriverSourcePath, RelativePath: $selectedRelativePath"
                    Write-Host "`nUser selected Type: $DriverSourceType, RelativePath: $selectedRelativePath"
                }
            }
        }
        else {
            WriteLog "No driver WIMs or folders found in Drivers directory."
            Write-Host "No driver WIMs or folders found in Drivers directory."
        }
    }
    else {
        WriteLog "Drivers folder not found at $DriversPath. Skipping driver installation."
    }
}
#Partition drive
Writelog 'Clean Disk'
$originalProgressPreference = $ProgressPreference
try {
    $ProgressPreference = 'SilentlyContinue'
    $Disk = Get-Disk -Number $DiskID
    if ($Disk.PartitionStyle -ne "RAW") {
        $Disk | clear-disk -RemoveData -RemoveOEM -Confirm:$false
    }
}
catch {
    WriteLog 'Cleaning disk failed. Exiting'
    throw $_
}
finally {
    $ProgressPreference = $originalProgressPreference
}

Writelog 'Cleaning Disk succeeded'

#Apply FFU
Write-SectionHeader -Title 'Applying FFU'
WriteLog "Applying FFU to $PhysicalDeviceID"
WriteLog "Running command dism /apply-ffu /ImageFile:$FFUFileToInstall /ApplyDrive:$PhysicalDeviceID"
#In order for Applying Image progress bar to show up, need to call dism directly. Might be a better way to handle, but must have progress bar show up on screen.
dism /apply-ffu /ImageFile:$FFUFileToInstall /ApplyDrive:$PhysicalDeviceID
$dismExitCode = $LASTEXITCODE

if ($dismExitCode -ne 0) {
    $errorMessage = "Failed to apply FFU. LastExitCode = $dismExitCode."
    if ($dismExitCode -eq 1393) {
        WriteLog "Failed to apply FFU - LastExitCode = $dismExitCode"
        WriteLog "This is likely due to a mismatched LogicalSectorSizeBytes"
        WriteLog "BytesPerSector value from Win32_Diskdrive is $BytesPerSector"
        if ($BytesPerSector -eq 4096) {
            WriteLog "The FFU build process by default uses a 512 LogicalSectorSizeBytes. Rebuild the FFU by adding -LogicalSectorSizeBytes 4096 to the command line"
        }
        elseif ($BytesPerSector -eq 512) {
            WriteLog "This FFU was likely built with a LogicalSectorSizeBytes of 4096. Rebuild the FFU by adding -LogicalSectorSizeBytes 512 to the command line"
        }
        $errorMessage += " This is likely due to a mismatched logical sector size. Check logs for details."
    }
    else {
        Writelog "Failed to apply FFU - LastExitCode = $dismExitCode also check dism.log on the USB drive for more info"
        $errorMessage += " Check dism.log on the USB drive for more info."
    }
    Stop-Script -Message $errorMessage
}

WriteLog 'Successfully applied FFU'

# Verify Windows partition exists and assign drive letter
$windowsPartition = Get-Partition -DiskNumber $DiskID | Where-Object { $_.PartitionNumber -eq 3 }
if ($null -eq $windowsPartition) {
    $errorMessage = "Windows partition (Partition 3) not found after applying FFU, even though DISM reported success."
    WriteLog $errorMessage
    Stop-Script -Message $errorMessage
}

WriteLog "Assigning drive letter 'W' to Windows partition."
Set-Partition -InputObject $windowsPartition -NewDriveLetter W

# Verify the drive letter was set
$windowsVolume = Get-Volume -DriveLetter W -ErrorAction SilentlyContinue
if ($null -eq $windowsVolume) {
    $errorMessage = "Failed to assign drive letter 'W' to the Windows partition after applying FFU."
    WriteLog $errorMessage
    Stop-Script -Message $errorMessage
}
WriteLog "Successfully assigned drive letter 'W'."

$recoveryPartition = Get-Partition -DiskNumber $DiskID | Where-Object PartitionNumber -eq 4
if ($recoveryPartition) {
    WriteLog 'Setting recovery partition attributes'
    $diskpartScript = @(
        "SELECT DISK $($Disk.Number)",
        "SELECT PARTITION $($recoveryPartition.PartitionNumber)",
        "GPT ATTRIBUTES=0x8000000000000001",
        "EXIT"
    )
    $diskpartScript | diskpart.exe | Out-Null
    WriteLog 'Setting recovery partition attributes complete'
}

#Copy modified WinRE if folder exists, else copy inbox WinRE
$WinRE = $USBDrive + "WinRE\winre.wim"
If (Test-Path -Path $WinRE) {
    WriteLog 'Copying modified WinRE to Recovery directory'
    Get-Disk | Where-Object Number -eq $DiskID | Get-Partition | Where-Object Type -eq Recovery | Set-Partition -NewDriveLetter R
    Invoke-Process xcopy.exe "/h $WinRE R:\Recovery\WindowsRE\ /Y"
    WriteLog 'Copying WinRE to Recovery directory succeeded'
    WriteLog 'Registering location of recovery tools'
    Invoke-Process W:\Windows\System32\Reagentc.exe "/Setreimage /Path R:\Recovery\WindowsRE /Target W:\Windows"
    Get-Disk | Where-Object Number -eq $DiskID | Get-Partition | Where-Object Type -eq Recovery | Remove-PartitionAccessPath -AccessPath R:
    WriteLog 'Registering location of recovery tools succeeded'
}
#Autopilot JSON
If ($APFileToInstall) {
    Write-SectionHeader -Title 'Applying Autopilot Configuration'
    WriteLog "Copying $APFileToInstall to W:\windows\provisioning\autopilot"
    Invoke-process xcopy.exe "$APFileToInstall W:\Windows\provisioning\autopilot\"
    WriteLog "Copying $APFileToInstall to W:\windows\provisioning\autopilot succeeded"
    # Rename file in W:\Windows\Provisioning\Autopilot to AutoPilotConfigurationFile.json
    try {
        Rename-Item -Path "W:\Windows\Provisioning\Autopilot\$APFileName" -NewName 'W:\Windows\Provisioning\Autopilot\AutoPilotConfigurationFile.json'
        WriteLog "Renamed W:\Windows\Provisioning\Autopilot\$APFilename to W:\Windows\Provisioning\Autopilot\AutoPilotConfigurationFile.json"
    }
    
    catch {
        Writelog "Copying $APFileToInstall to W:\windows\provisioning\autopilot failed with error: $_"
        throw $_
    }
}
#Apply PPKG
If ($PPKGFileToInstall) {
    Write-SectionHeader -Title 'Applying Provisioning Package'
    try {
        #Make sure to delete any existing PPKG on the USB drive
        Get-Childitem -Path $USBDrive\*.ppkg | ForEach-Object {
            Remove-item -Path $_.FullName
        }
        WriteLog "Copying $PPKGFileToInstall to $USBDrive"
        Write-Host "Copying $PPKGFileToInstall to $USBDrive"
        # Quote paths to handle PPKG filenames with spaces
        Invoke-process xcopy.exe """$PPKGFileToInstall"" ""$USBDrive"""
        WriteLog "Copying $PPKGFileToInstall to $USBDrive succeeded"
        Write-Host "Copying $PPKGFileToInstall to $USBDrive succeeded"
    }

    catch {
        Writelog "Copying $PPKGFileToInstall to $USBDrive failed with error: $_"
        Write-Host "Copying $PPKGFileToInstall to $USBDrive failed with error: $_"
        throw $_
    }
}
#Set DeviceName
If ($computername) {
    Write-SectionHeader -Title 'Applying Computer Name and Unattend Configuration'
    try {
        $PantherDir = 'w:\windows\panther'
        If (Test-Path -Path $PantherDir) {
            Writelog "Copying $UnattendFile to $PantherDir"
            Write-Host "Copying $UnattendFile to $PantherDir"
            Invoke-process xcopy "$UnattendFile $PantherDir /Y"
            WriteLog "Copying $UnattendFile to $PantherDir succeeded"
            Write-Host "Copying $UnattendFile to $PantherDir succeeded"
        }
        else {
            Writelog "$PantherDir doesn't exist, creating it"
            New-Item -Path $PantherDir -ItemType Directory -Force
            Writelog "Copying $UnattendFile to $PantherDir"
            Write-Host "Copying $UnattendFile to $PantherDir"
            Invoke-Process xcopy.exe "$UnattendFile $PantherDir"
            WriteLog "Copying $UnattendFile to $PantherDir succeeded"
            Write-Host "Copying $UnattendFile to $PantherDir succeeded"
        }
    }
    catch {
        WriteLog "Copying Unattend.xml to name device failed"
        Stop-Script -Message "Copying Unattend.xml to name device failed with error: $_"
    }   
}

# Add Drivers
if ($null -ne $DriverSourcePath) {
    Write-SectionHeader -Title 'Installing Drivers'
    if ($DriverSourceType -eq 'WIM') {
        WriteLog "Installing drivers from WIM: $DriverSourcePath"
        Write-Host "Installing drivers from WIM: $DriverSourcePath"
        $TempDriverDir = "W:\TempDrivers"
        try {
            WriteLog "Creating temporary directory for drivers at $TempDriverDir"
            New-Item -Path $TempDriverDir -ItemType Directory -Force | Out-Null
            
            WriteLog "Mounting WIM contents to $TempDriverDir"
            Write-Host "Mounting WIM contents to $TempDriverDir"
            # For some reason can't use /mount-image with invoke-process, so using dism.exe directly
            dism.exe /Mount-Image /ImageFile:$DriverSourcePath /Index:1 /MountDir:$TempDriverDir /ReadOnly /optimize
            WriteLog "WIM mount successful."

            WriteLog "Injecting drivers from $TempDriverDir"
            Write-Host "Injecting drivers from $TempDriverDir"
            Write-Host "This may take a while, please be patient."
            Invoke-Process dism.exe "/image:W:\ /Add-Driver /Driver:""$TempDriverDir"" /Recurse"
            WriteLog "Driver injection from WIM succeeded."
            Write-Host "Driver injection from WIM succeeded."

        }
        catch {
            WriteLog "An error occurred during WIM driver installation: $_"
            # Copy DISM log to USBDrive for debugging
            invoke-process xcopy.exe "X:\Windows\logs\dism\dism.log $USBDrive /Y"
            throw $_
        }
        finally {
            if (Test-Path -Path $TempDriverDir) {
                WriteLog "Unmounting WIM from $TempDriverDir"
                Write-Host "Unmounting WIM from $TempDriverDir"
                Invoke-Process dism.exe "/Unmount-Image /MountDir:""$TempDriverDir"" /Discard"
                WriteLog "Unmount successful."
                Write-Host "Unmount successful."
                WriteLog "Cleaning up temporary driver directory: $TempDriverDir"
                Write-Host "Cleaning up temporary driver directory: $TempDriverDir"
                Remove-Item -Path $TempDriverDir -Recurse -Force
                WriteLog "Cleanup successful."
                Write-Host "Cleanup successful."
            }
        }
    }
    elseif ($DriverSourceType -eq 'Folder') {
        $substMapping = $null
        try {
            $substMapping = New-DriverSubstMapping -SourcePath $DriverSourcePath
            $shortDriverPath = $substMapping.DrivePath
            WriteLog "Injecting drivers from folder via SUBST. Source: $DriverSourcePath, Mapped: $($substMapping.DriveName)"
            Write-Host "Injecting drivers from folder: $shortDriverPath"
            Write-Host "This may take a while, please be patient."
            Invoke-Process dism.exe "/image:W:\ /Add-Driver /Driver:$shortDriverPath /Recurse"
            WriteLog "Driver injection from folder succeeded."
            Write-Host "Driver injection from folder succeeded."
        }
        catch {
            WriteLog "An error occurred during folder driver installation: $_"
            Invoke-Process xcopy.exe "X:\Windows\logs\dism\dism.log $USBDrive /Y"
            throw $_
        }
        finally {
            if ($null -ne $substMapping) {
                Remove-DriverSubstMapping -DriveLetter $substMapping.DriveLetter
            }
        }
    }
}
else {
    WriteLog "No drivers to install."
}
Write-SectionHeader -Title 'Setting Boot Configuration'
WriteLog "Setting Windows Boot Manager to be first in the firmware display order."
Write-Host "Setting Windows Boot Manager to be first in the firmware display order."
Invoke-Process bcdedit.exe "/set {fwbootmgr} displayorder {bootmgr} /addfirst"
WriteLog "Setting Windows Boot Manager to be first in the default display order."
Write-Host "Setting Windows Boot Manager to be first in the default display order."
Invoke-Process bcdedit.exe "/set {bootmgr} displayorder {default} /addfirst"
#Copy DISM log to USBDrive
WriteLog "Copying dism log to $USBDrive"
invoke-process xcopy "X:\Windows\logs\dism\dism.log $USBDrive /Y" 
WriteLog "Copying dism log to $USBDrive succeeded"




