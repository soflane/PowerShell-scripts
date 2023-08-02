<#
.SYNOPSIS
    This script will save a DUMP of the event logs, NirSoft's BlueScreenView (if present and asked) and BSOD DMP file

    .DESCRIPTION
    Made to be run with Tactical RMM. This script should be triggered by the "Bluescreen - Reports bluescreens" script check,
	And collect dmp files, use NirSoft's BlueScreenView (if present and asked) to add a HTML/TXT report. 
	The zip can be send over a pwpush instance or via telegram.
	Many thanks to damienvanrobaeys for the Export_Event_Logs function

	RMM info's
	----------
	.PARAMETER Company_Name
	The name of the agent's company, can be used as -Company_Name {{client.name}} 
	[String]
	.PARAMETER Site_name
	The name of the agent's site, can be used as -Site_name {{client.name}}
	[String]
	.PARAMETER RMM_Link
    Shows the link to your instance (currently in telegram notification and script output)
	[String]

	Common
	--------
    .PARAMETER Num_Days
    The number of days you want to go backward in logs 
	[Int]
    .PARAMETER Remove_Collected_files
    Remove or not the files that have been exported by this script ($true removes it; $false let the folder on disk)
	[bool] - DEFAULT : $false
    .PARAMETER Show_Output
    Show or not the output of txt files (currently only used for NirSoft Report)
	[bool] - DEFAULT : $true

    .PARAMETER BlueScreenView_Path
    The path to your bluescreenview.exe file
	[String]


	TELEGRAM
	--------
    .PARAMETER Send_File_Over_Telegram
    Sends the file as attachment over telegram or not
	$true  : sends the file 
	$false : doesn't send the file 
	[bool] - DEFAULT : $true
    .PARAMETER Telegramtoken
    The token of your telegram bot
	[String]
    .PARAMETER Telegramchatid
    The chat ID where to send the messages to
	[String]


	Password Pusher
	https://pwpush.com/
	-------------------
	Pass these following parameters to send to a pwpush instance. If not used, there will be no file sending through pwpush
	You will need an API Token with you can create in your pwpush account : https://pwpush.com/en/users/token or https://<your-instance>/en/users/token
    .PARAMETER PWpush_Url
    The url of the password pusher instance (Ex: "https://pwpush.com")
	[String]
    .PARAMETER PWpush_Email
    The auth mail, see https://pwpush.com/en/api
	[String]
    .PARAMETER PWpush_Token
    The auth token, see https://pwpush.com/en/api
	[String]
    .PARAMETER PWpush_File_Password
    If used, this parameter will protect the upload with a chosen password
	[String]
    .PARAMETER PWpush_Show_Passphrase
    If set on $true, it will show the passphrase in the output and telegram notification(if used) 
	[bool] - DEFAULT : $true


    .OUTPUTS
    This script does output some logs during the whole process and output the content of BlueScreenView txt file if the program is present

    .EXAMPLE
    PS C:> .\BSOD_Dump_sender.ps1

    bash
    Copy code
    This example runs the script to 
    .EXAMPLE
    PS C:> .\BSOD_Dump_sender.ps1 -Company_Name {{client.name}} -Site_name {{client.name}}

    bash
    Copy code
    This example runs the script to enable 
    .NOTES
    Version: 1.0
#>

param
(
    [Int]$Num_Days=30,
	[bool]$Remove_Collected_files = $false,
	[bool]$Show_Output=$true,

	[String]$RMM_Link = "https://github.com/amidaware/tacticalrmm",
	[String]$BlueScreenView_Path = "C:\Program Files\Soflane's packages\BlueScreenView\BlueScreenView.exe",

	[bool]$Send_File_Over_Telegram=$true,
	[String]$Telegramtoken,
    [String]$Telegramchatid,

    [String]$PWpush_Url, 
    [String]$PWpush_Email,
    [String]$PWpush_Token,
    [String]$PWpush_File_Password,
    [Bool]$PWpush_Show_Passphrase = $true,

	# -Company_Name {{client.name}} -Site_name {{client.name}}
	# [Parameter(Mandatory=$true)]
	[String]$Company_Name = "Company",
	[String]$Site_name = "HQ"

)


$DMP_Date = "{0:yy-MM-dd}_{0:HH-mm}" -f (Get-Date)
$Log_File = "C:\Windows\Debug\BSOD_Remediation.log"
$Temp_folder = "C:\Windows\Temp"
$DMP_Logs_folder = "$Temp_folder\DMP_Logs_folder"
$DMP_Logs_folder_ZIP = "$Temp_folder\BSOD_$env:computername_$DMP_Date.zip"

Function Write_Log
	{
		param(
		$Message_Type,	
		$Message,
		$Remove_Collected_files
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"	
		write-host "$MyDate - $Message_Type : $Message"	
	}


Function Install_Import_Module
	{
		$Is_Nuget_Installed = $False     
		If(!(Get-PackageProvider | where {$_.Name -eq "Nuget"}))
			{                                         
				Write_Log -Message_Type "INFO" -Message "The package Nuget is not installed"                                                                          
				Try
				{
						Write_Log -Message_Type "INFO" -Message "The package Nuget is being installed"                                                                             
						[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
						Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force -Confirm:$False | out-null                                                                                                                 
						Write_Log -Message_Type "SUCCESS" -Message "The package Nuget has been successfully installed"              
						$Is_Nuget_Installed = $True                                                                                     
					}
				Catch
					{
						Write_Log -Message_Type "ERROR" -Message "An issue occured while installing package Nuget"  
						write-output "An issue occured while installing package Nuget"  
						EXIT 1
						Break
					}
			}
		Else
			{
				$Is_Nuget_Installed = $True      
				Write_Log -Message_Type "SUCCESS" -Message "The package Nuget is already installed"                                                                                                                                         
			}

		If($Is_Nuget_Installed -eq $True)
			{
				$Script:PnP_Module_Status = $False
				$Module_Name = "PnP.PowerShell"
				If (!(Get-InstalledModule $Module_Name -ErrorAction silentlycontinue)) 				
				{ 
					Write_Log -Message_Type "INFO" -Message "The module $Module_Name has not been found"      
					Try
						{
							Write_Log -Message_Type "INFO" -Message "The module $Module_Name is being installed"                                                                                                           
							Install-Module $Module_Name -Force -Confirm:$False -ErrorAction SilentlyContinue -RequiredVersion 1.12.0 -AllowClobber | out-null   
							$Module_Version = (Get-Module $Module_Name -listavailable).version
							Write_Log -Message_Type "SUCCESS" -Message "The module $Module_Name has been installed"      
							Write_Log -Message_Type "INFO" -Message "$Module_Name version $Module_Version"   
							$PnP_Module_Status = $True								
						}
					Catch
						{
							Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been installed"   
							write-output "The module $Module_Name has not been installed" 
							EXIT 1							
						}                                                                                                                                                                                                                    
				} 
				Else
				{
					Try
						{
							Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been found"                                                                                                                                                                      
							Import-Module $Module_Name -Force -ErrorAction SilentlyContinue 
							$PnP_Module_Status = $True	
							Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been imported"     
						}
					Catch
						{
							Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been imported"       
							write-output "The module $Module_Name has not been imported" 
							EXIT 1								
						}                                                         
				}                                                       
			}	
	} 

Function Export_Event_Logs
	{
		param(
		$Log_To_Export,	
		$File_Name
		)	
		
		Write_Log -Message_Type "INFO" -Message "Collecting logs from: $Log_To_Export"
		Try
			{	
				$days = $Num_Days * 86400000
				WEVTUtil export-log $Log_To_Export -ow:true /q:"*[System[TimeCreated[timediff(@SystemTime) <= $days ]]]" "$DMP_Logs_folder\$File_Name.evtx" | out-null
				Write_Log -Message_Type "SUCCESS" -Message "Event log $File_Name.evtx has been successfully exported"
			}
		Catch
			{
				Write_Log -Message_Type "ERROR" -Message "An issue occured while exporting event log $File_Name.evtx"
			}
	}		

If(!(test-path $Log_File)){new-item $Log_File -type file -force | out-null}
If(test-path $DMP_Logs_folder){remove-item $DMP_Logs_folder -Force -Recurse}
new-item $DMP_Logs_folder -type Directory -force | out-null
If(test-path $DMP_Logs_folder_ZIP){Remove-Item $DMP_Logs_folder_ZIP -Force}

Write_Log -Message_Type "INFO" -Message "A recent BSOD has been found"
Write_Log -Message_Type "INFO" -Message "Date: $Last_DMP"


# If nirsoft is installed
if (Test-Path -Path $BlueScreenView_Path){
	Write_Log -Message_Type "INFO" -Message "Creating a report with NirSoft BlueScreenView"	
	Start-Process -FilePath $BlueScreenView_Path -Wait -ArgumentList "/sverhtml `"$DMP_Logs_folder\BlueScreenReport.html`""
	Start-Process -FilePath $BlueScreenView_Path -Wait -ArgumentList "/stext `"$DMP_Logs_folder\BlueScreen.txt`""
	if ($Show_Output){
		$NirSoftOutput = Get-Content -Path "$DMP_Logs_folder\BlueScreen.txt" -Raw
		$NirSoftOutput = $NirSoftOutput.Substring(0,$NirSoftOutput.Length-4)
		Write_Log -Message_Type "INFO" -Message $NirSoftOutput
	}
}




# Export EVTX from last x days
Export_Event_Logs -Log_To_Export System -File_Name "System"		
Export_Event_Logs -Log_To_Export Application -File_Name "Applications"		
Export_Event_Logs -Log_To_Export Security -File_Name "Security"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Power/Thermal-Operational" -File_Name "KernelPower"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Driver Watchdog" -File_Name "KernelPnP_Watchdog"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-PnP/Configuration" -File_Name "KernelPnp_Conf"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-LiveDump/Operational" -File_Name "KernelLiveDump"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-ShimEngine/Operational" -File_Name "KernelShimEngine"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-Boot/Operational" -File_Name "KernelBoot"		
Export_Event_Logs -Log_To_Export "Microsoft-Windows-Kernel-IO/Operational" -File_Name "KernelIO"		


# Copy Dump files
$Minidump_Folder = "C:\Windows\Minidump"
If(test-path $Minidump_Folder){copy-item $Minidump_Folder $DMP_Logs_folder -Recurse -Force}
# If(test-path "C:\WINDOWS\MEMORY.DMP"){copy-item "C:\WINDOWS\MEMORY.DMP" $DMP_Logs_folder -Recurse -Force}

# $Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)[0]
$Get_BugCheck_Event = (Get-EventLog system -Source bugcheck -ea silentlycontinue)
If($Get_BugCheck_Event -ne $null)
	{
		$Get_last_BugCheck_Event = $Get_BugCheck_Event[0]
		$Get_last_BugCheck_Event_Date = $Get_last_BugCheck_Event.TimeGenerated
		$Get_last_BugCheck_Event_MSG = $Get_last_BugCheck_Event.Message	
		$Get_last_BugCheck_Event_MSG | out-file "$DMP_Logs_folder\LastEvent_Message.txt"		
	}



# ZIP DMP folder
Try
	{
		Add-Type -assembly "system.io.compression.filesystem"
		[io.compression.zipfile]::CreateFromDirectory($DMP_Logs_folder, $DMP_Logs_folder_ZIP) 
		# Compress-Archive -Path $DMP_Logs_folder -DestinationPath "$DMP_Logs_folder_ZIP"
		Write_Log -Message_Type "SUCCESS" -Message "The ZIP file has been successfully created"	
		Write_Log -Message_Type "INFO" -Message "The ZIP is located in :$DMP_Logs_folder_ZIP"				
		# Write_Log -Message_Type "INFO" -Message "The ZIP is located in :$Logs_Collect_Folder_ZIP"				
	}
Catch
	{
		Write_Log -Message_Type "ERROR" -Message "An issue occured while creating the ZIP file"		
		write-output "Failed step: Creating ZIP file"
		write-output $DMP_Logs_folder
		write-output $DMP_Logs_folder_ZIP

		write-output $_
		EXIT 1			
	}	
	


# IF asked to upload zip to pwpush 
# you can push the zip fileto a own Password Pusher instance or pwpush.com

if (($PWpush_Url -ne $null) -And ($PWpush_Email -ne $null) -And ($PWpush_Token -ne $null)) {
	Try {
		# Create HTTP Client 
		Add-Type -AssemblyName 'System.Net.Http'
		$client = New-Object System.Net.Http.HttpClient

		# Read file 
		$fileStream = [System.IO.File]::OpenRead($DMP_Logs_folder_ZIP)
		$fileName = [System.IO.Path]::GetFileName($DMP_Logs_folder_ZIP)
		$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
	
		# Add headers for password pusher
		$client.DefaultRequestHeaders.Add("X-User-Email", $PWpush_Email);
		$client.DefaultRequestHeaders.Add("X-User-Token", $PWpush_Token);
		# Create body
		$content = New-Object System.Net.Http.MultipartFormDataContent
		# adding content to it (if asked)
		if (($PWpush_File_Password -ne $null) -And ($PWpush_File_Password -is [String])) {
			Write_Log -Message_Type "INFO" -Message "Add Upload Passphrase to pwpush"
			$strContent = New-Object System.Net.Http.StringContent($PWpush_File_Password)
			$content.Add($strContent, "file_push[passphrase]")
		} 
		if (($PWpush_File_Expire_Days -ne $null) -And ($PWpush_File_Expire_Days -is [Int])) {
			Write_Log -Message_Type "INFO" -Message "Setting Custom expire days to pwpush"
			$strContent = New-Object System.Net.Http.StringContent($PWpush_File_Expire_Days)
			$content.Add($strContent, "file_push[expire_after_days]")
		} 
		if (($PWpush_File_Expire_Views -ne $null) -And ($PWpush_File_Expire_Views -is [Int])) {
			Write_Log -Message_Type "INFO" -Message "Setting Custom expire views to pwpush"
			$strContent = New-Object System.Net.Http.StringContent($PWpush_File_Expire_Views)
			$content.Add($strContent, "file_push[expire_after_views]")
		} 
		# Add file to body
		$content.Add($fileContent, "file_push[files][]", $fileName)
	
		# Uploading file 
		$result = $client.PostAsync("$PWpush_Url/f.json", $content).Result
		# $result.EnsureSuccessStatusCode()
		if ($result.IsSuccessStatusCode) {
			Write_Log -Message_Type "SUCCESS" -Message "File Uploaded!"
			# Retrieve link from JSON data returned
			$data = ConvertFrom-JSON -InputObject $result.Content.ReadAsStringAsync().Result 
			$link = "$PWpush_Url/f/$($data.url_token)"
			Write_Log -Message_Type "INFO" -Message "File is uploaded at the following link : $link"
			if (($PWpush_File_Password -ne $null) -And $PWpush_Show_Passphrase) {
				Write_Log -Message_Type "INFO" -Message "Passphrase : $PWpush_File_Password"
			}
		}else {
			$Remove_Collected_files = $false
			Write_Log -Message_Type "ERROR" -Message "File Not uploaded"
			$result.EnsureSuccessStatusCode()
		}
	}
	Catch {
		$Remove_Collected_files = $false
		Write_Log -Message_Type "ERROR" -Message "Problem uploading file!"
		Write_Log -Message_Type "ERROR" -Message $_
		# exit 1
	}
	Finally {
		if ($client -ne $null) { $client.Dispose() }
		if ($content -ne $null) { $content.Dispose() }
		if ($fileStream -ne $null) { $fileStream.Dispose() }
		if ($fileContent -ne $null) { $fileContent.Dispose() }
	}
}


# IF asked, send message to telegram
# you can push the zip fileto a own Password Pusher instance or pwpush.com
if (($Telegramtoken -ne $null) -And ($Telegramchatid -ne $null) ) {
	$Message = "[RMM alert - BSOD Dump]`nA BSOD has been found on <b><u>$env:computername</u></b>`n"
	$Message = $Message + "Company : $Company_Name (<u>$Site_name</u>)`n"
	if (($PWpush_Url -ne $null) -And ($PWpush_Email -ne $null) -And ($PWpush_Token -ne $null)) {
		$Message = $Message + "File is uploaded at the following <a href='$link'>link</a>`n"
		if (($PWpush_File_Password -ne $null) -And $PWpush_Show_Passphrase) {
			$Message = $Message + "With password '<b>$PWpush_File_Password</b>'`n"
		}
	}elseif ($Send_File_Over_Telegram) {
		$Message = $Message + "You can find the full dump in attachment`n"
	}
	if ($NirSoftOutput -ne $null){
		$Message = $Message + "<pre>$NirSoftOutput</pre>`n"	
	}
	$Message = $Message + "<a href='$RMM_Link'>Tactical RMM</a>"
	$payload = @{
		"chat_id"                   = $Telegramchatid;
		"text"                      = $Message
		"parse_mode"                = "HTML";
	}
	try {
		Write-Verbose -Message "Sending Telegram text message..."
		$eval = Invoke-RestMethod `
			-Uri ("https://api.telegram.org/bot{0}/sendMessage" -f $Telegramtoken) `
			-Method Post `
			-ContentType "application/json; charset=utf-8" `
			-Body (ConvertTo-Json -Compress -InputObject $payload) `
			-ErrorAction Stop
		if (!($eval.ok -eq "True")) {
			Write-Warning -Message "Message did not send successfully"
		}#if_StatusDescription
	}#try_messageSend
	catch {
		Write-Warning "An error was encountered sending the Telegram message:"
		Write-Error $_
	}


	if ($Send_File_Over_Telegram){
		Try {
			# Create HTTP Client 
			Add-Type -AssemblyName 'System.Net.Http'
			$client = New-Object System.Net.Http.HttpClient
		
			# Read file 
			$fileStream = [System.IO.File]::OpenRead($DMP_Logs_folder_ZIP)
			$fileName = [System.IO.Path]::GetFileName($DMP_Logs_folder_ZIP)
			$fileContent = New-Object System.Net.Http.StreamContent($fileStream)
		
			# Add headers for password pusher
			# $client.DefaultRequestHeaders.Add("X-User-Email", $PWpush_Email);
			# $client.DefaultRequestHeaders.Add("X-User-Token", $PWpush_Token);
			# Create body
			$content = New-Object System.Net.Http.MultipartFormDataContent
			# adding content to it
			$strContent = New-Object System.Net.Http.StringContent($Telegramchatid)
			$content.Add($strContent, "chat_id")
			# Add file to body
			$content.Add($fileContent, "document", $fileName)
		
			# Uploading file 
			$result = $client.PostAsync("https://api.telegram.org/bot$($Telegramtoken)/sendDocument", $content).Result
			# $result.EnsureSuccessStatusCode()
			if ($result.IsSuccessStatusCode) {
				Write_Log -Message_Type "SUCCESS" -Message "File sent to telegram!"
				# Retrieve link from JSON data returned
				$data = ConvertFrom-JSON -InputObject $result.Content.ReadAsStringAsync().Result 
			}else {
				$Remove_Collected_files = $false
				Write_Log -Message_Type "ERROR" -Message "File not sent at telegram"
				$result.EnsureSuccessStatusCode()
			}
		}
		Catch {
			$Remove_Collected_files = $false
			Write_Log -Message_Type "ERROR" -Message "Problem sending file on telegram!"
			Write_Log -Message_Type "ERROR" -Message $_
			# exit 1
		}
		Finally {
			if ($client -ne $null) { $client.Dispose() }
			if ($content -ne $null) { $content.Dispose() }
			if ($fileStream -ne $null) { $fileStream.Dispose() }
			if ($fileContent -ne $null) { $fileContent.Dispose() }
		}
	}
}




																				
if ($Remove_Collected_files){
	Remove-Item $DMP_Logs_folder -Force -Recurse
	Remove-Item $DMP_Logs_folder_ZIP -Force 
}
Write_Log -Message_Type "Info" -Message "Finished! More info at $RMM_Link"
