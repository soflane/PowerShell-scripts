# With the help of : https://theitbros.com/remove-old-unused-drivers-using-powershell/

[CmdletBinding()]
param (
    [String]
    $DevCleanCmd_Path = "C:\Program Files\Tools-Soflane\DeviceCleanupCmd\", 
    [bool]
    $DevCleanCmd = $true
)

# Creating Restore point 

$Backup_Name = "PointBeforeDeleteUnusedDrivers"
Enable-ComputerRestore -drive "c:\"
Checkpoint-Computer -Description $Backup_Name


# Verifying Restore point 
# To restore last created point, do the following command :
# "Restore-Computer -RestorePoint (Get-ComputerRestorePoint)[-1].sequencenumber"

$Last_Restore_Point = (Get-ComputerRestorePoint)[-1]
$Last_Restore_Point_Date= (Get-WmiObject Win32_OperatingSystem).ConvertToDateTime($Last_Restore_Point.creationtime)
$diff= NEW-TIMESPAN -Start $Last_Restore_Point_Date -End (Get-Date)
# Write-Output "Time difference is: $($diff.TotalHours)"
if (((Get-ComputerRestorePoint)[-1].description -eq $Backup_Name) -and ($diff.TotalMinutes -lt 10)) {
    Write-Host "Restore point done, continuing..."
}else {
    Write-Host "Failed to create restore point, exiting..."
    # exit 1
}

#Get drivers 
$dismOut = dism /online /get-drivers
$Lines = $dismOut | select -Skip 10


$Operation = "theName"
$Drivers = @()
foreach ( $Line in $Lines ) {
    $tmp = $Line
    $txt = $($tmp.Split( ':' ))[1]
    switch ($Operation) {
        'theName' { $Name = $txt
                     $Operation = 'theFileName'
                     break
                   }
        'theFileName' { $FileName = $txt.Trim()
                         $Operation = 'theEntr'
                         break
                       }
        'theEntr' { $Entr = $txt.Trim()
                     $Operation = 'theClassName'
                     break
                   }
        'theClassName' { $ClassName = $txt.Trim()
                          $Operation = 'theVendor'
                          break
                        }
        'theVendor' { $Vendor = $txt.Trim()
                       $Operation = 'theDate'
                       break
                     }
        'theDate' { # change the date format for easy sorting
                     $tmp = $txt.split( '.' )
                     $txt = "$($tmp[2]).$($tmp[1]).$($tmp[0].Trim())"
                     $Date = $txt
                     $Operation = 'theVersion'
                     break
                   }
        'theVersion' { $Version = $txt.Trim()
                        $Operation = 'theNull'
                        $params = [ordered]@{ 'FileName' = $FileName
                                              'Vendor' = $Vendor
                                              'Date' = $Date
                                              'Name' = $Name
                                              'ClassName' = $ClassName
                                              'Version' = $Version
                                              'Entr' = $Entr
                                            }
                        $obj = New-Object -TypeName PSObject -Property $params
                        $Drivers += $obj
                        break
                      }
         'theNull' { $Operation = 'theName'
                      break
                     }
    }
}
# Write-Host "All installed third-party  drivers"
# $Drivers | sort Filename | ft


# Different versions
$last = ''
$NotUnique = @()
foreach ( $Dr in $($Drivers | sort Filename) ) {
    if ($Dr.FileName -eq $last  ) {  $NotUnique += $Dr  }
    $last = $Dr.FileName
}
# Write-Host "Different versions"
# $NotUnique | sort FileName | ft


# Write-Host "Outdated drivers"
$list = $NotUnique | select -ExpandProperty FileName -Unique
$ToDel = @()
foreach ( $Dr in $list ) {
    $sel = $Drivers | where { $_.FileName -eq $Dr } | sort date -Descending | select -Skip 1
    # Write-Host "duplicate found" -ForegroundColor Yellow
    # $sel | ft
    $ToDel += $sel
}
Write-Host "Drivers to remove" -ForegroundColor Red
$ToDel | ft



# removing old drivers
foreach ( $item in $ToDel ) {
    $Name = $($item.Name).Trim()
    # Write-Host "pnputil.exe -d $Name" -ForegroundColor Yellow
    Invoke-Expression -Command "pnputil.exe -d $Name"
}
Write-Host "Deleted !" -ForegroundColor red


# remove all devices not used for 1 year or more with Device Cleanup Cmd
# https://www.uwe-sieber.de/misc_tools_e.html
# Non-PnP devices and 'soft' devices are not deleted because they are not automatically reinstalled. 
# These are devices whose ID begins with one of these : "HTREE\ROOT\", "ROOT\", "SWD\", "SW\{"
# DeviceCleanupCmd * -m:1y -e:"HTREE\ROOT\*" -e:"ROOT\*" -e:"SWD\*" -e:"SW\{*"

if ($DevCleanCmd -eq $true) {
    $output_file = "$env:temp\DeviceCleanupCmd-Output.txt"
    if ([System.Environment]::Is64BitOperatingSystem){ 
        Write-Host "64-Bit OS Detected"
        $exec = "$DevCleanCmd_Path\x64\DeviceCleanupCmd.exe"
    } else { 
        Write-Host "32-Bit OS Detected"
        $exec = "$DevCleanCmd_Path\Win32\DeviceCleanupCmd.exe" 
    }
    if (Test-Path -Path $exec){
        Write-Host "Executing DeviceCleanupCmd ...."
        Start-Process -FilePath $exec -Wait -ArgumentList "-n * -m:1y -e:`"HTREE\ROOT\*`" -e:`"ROOT\*`" -e:`"SWD\*`" -e:`"SW\{*`"" -RedirectStandardOutput $output_file
        # Start-Process -FilePath $exec -Wait -ArgumentList "-n -t * -m:32d -e:`"HTREE\ROOT\*`" -e:`"ROOT\*`" -e:`"SWD\*`" -e:`"SW\{*`"" -RedirectStandardOutput $output_file
        Get-Content $output_file
    }else {
        Write-Host "Downloading DeviceCleanupCmd ...."
        $ZIP_File = "$env:temp\DeviceCleanupCmd.zip"		
        $Extracted_Scripts = "$env:temp\DeviceCleanupCmd"
        $Link = "https://www.uwe-sieber.de/files/DeviceCleanupCmd.zip"
        if ([System.Environment]::Is64BitOperatingSystem){ $exec = "$Extracted_Scripts\x64\DeviceCleanupCmd.exe"} else { $exec = "$Extracted_Scripts\Win32\DeviceCleanupCmd.exe" }

        Invoke-WebRequest -Uri $Link -OutFile $ZIP_File -UseBasicParsing | out-null			
        Expand-Archive -Path $ZIP_File -DestinationPath $Extracted_Scripts -Force	
        Remove-Item $ZIP_File -Force

        Write-Host "Executing DeviceCleanupCmd ...."
        # Start-Process -FilePath $exec -Wait -ArgumentList "-n * -m:1y -e:`"HTREE\ROOT\*`" -e:`"ROOT\*`" -e:`"SWD\*`" -e:`"SW\{*`"" -RedirectStandardOutput $output_file
        Start-Process -FilePath $exec -Wait -ArgumentList "-n -t * -m:32d -e:`"HTREE\ROOT\*`" -e:`"ROOT\*`" -e:`"SWD\*`" -e:`"SW\{*`"" -RedirectStandardOutput $output_file

        Get-Content $output_file

        Remove-Item -recurse $output_file -Force
        Remove-Item -recurse $Extracted_Scripts -Force

    }

}

