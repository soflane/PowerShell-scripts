<#
.SYNOPSIS
    This script will send a notification to the user with the message given in parameter

    .DESCRIPTION
    Made to be run with Tactical RMM. 
	Many thanks to damienvanrobaeys for the original script notification script.

	RMM info's
	----------
	.PARAMETER Header_URL

	.PARAMETER App_title

	.PARAMETER Logo_URL

    .PARAMETER Header_Title

    .PARAMETER Header_Subtitles

    .PARAMETER Header_Attribution

    .PARAMETER Body_Texts

    .PARAMETER Btn_Dissmiss

    .PARAMETER Show_Action_Button

    .PARAMETER Btn_Action

    .PARAMETER Action_Script

    .OUTPUTS
    This script has no output (if everything goes fine)

    .EXAMPLE
    PS C:> .\send_desktop_notification.ps1

    bash
    Copy code
    This example runs the script to 

    .NOTES
    Version: 0.1
#>



[CmdletBinding()]
param (
    [String]
    $Header_URL,
    [String]
    $App_title,
    [String]
    $Logo_URL,
    [String]
    $Header_Title = "Titre de la notification",
    [String[]]
    $Header_Subtitles = @("Lorem ipsum", "Lorem ipsum"),
    [String]
    $Header_Attribution,
    [String[]]
    $Body_Texts = @("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris commodo arcu vestibulum pharetra varius. Donec ut aliquet diam, sit amet maximus dui. Suspendisse potenti.","Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris commodo arcu vestibulum pharetra varius. Donec ut aliquet diam, sit amet maximus dui. Suspendisse potenti."),
    [String]
    $Btn_Dissmiss = "Effacer",
    $Show_Action_Button = $false, # It will add a button to execute wanted action in action_script
    [String]
    $Btn_Action = "OK",
    [String]
    $Action_Script = @"
Add-Type -AssemblyName PresentationCore,PresentationFramework
[System.Windows.MessageBox]::Show("This is a test", "Hello")
"@
)

chcp 1252 
$OutputEncoding = [System.Console]::OutputEncoding = [System.Console]::InputEncoding = [System.Text.Encoding]::Unicode
$PSDefaultParameterValues['*:Encoding'] = 'Unicode'


# ***************************************************************************
# 								Export picture
# ***************************************************************************
If($Header_URL)
	{
        $fileName = [System.IO.Path]::GetFileName($Header_URL)
		$HeroImage = "$env:temp\$fileName"		
		invoke-webrequest -Uri $Header_URL -OutFile $HeroImage -usebasicparsing
	}

if ($Logo_URL){
    $fileName = [System.IO.Path]::GetFileName($Logo_URL)
	$LogoImage = "$env:temp\$fileName"		
	invoke-webrequest -Uri $Logo_URL -OutFile $LogoImage -usebasicparsing
} 
# TODO Set_Action
Function Set_Action
	{
		param(
		$Action_Name		
		)	
		
		$Main_Reg_Path = "HKCU:\SOFTWARE\Classes\$Action_Name"
		$Command_Path = "$Main_Reg_Path\shell\open\command"
		$CMD_Script = "$env:temp\$Action_Name.cmd"
		New-Item $Command_Path -Force
		New-ItemProperty -Path $Main_Reg_Path -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
		Set-ItemProperty -Path $Main_Reg_Path -Name "(Default)" -Value "URL:$Action_Name Protocol" -Force | Out-Null
		Set-ItemProperty -Path $Command_Path -Name "(Default)" -Value $CMD_Script -Force | Out-Null		
	}




$Script_Export_Path = "$env:temp"

If($Show_Action_Button -eq $True)
	{
		$Action_Script | out-file "$Script_Export_Path\ActionScript.ps1" -Force -Encoding ASCII
        "powershell $Script_Export_Path\ActionScript.ps1" | out-file "$Script_Export_Path\ActionScript.cmd" -Force -Encoding ASCII
		Set_Action -Action_Name ActionScript	
	}

Function Register-NotificationApp($AppID,$AppDisplayName) {
    [int]$ShowInSettings = 0

    [int]$IconBackgroundColor = 0
	$IconUri = "C:\Windows\ImmersiveControlPanel\images\logo.png"
	
    $AppRegPath = "HKCU:\Software\Classes\AppUserModelId"
    $RegPath = "$AppRegPath\$AppID"
	
	$Notifications_Reg = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'
	If(!(Test-Path -Path "$Notifications_Reg\$AppID")) 
		{
			New-Item -Path "$Notifications_Reg\$AppID" -Force
			New-ItemProperty -Path "$Notifications_Reg\$AppID" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' -Force
		}

	If((Get-ItemProperty -Path "$Notifications_Reg\$AppID" -Name 'ShowInActionCenter' -ErrorAction SilentlyContinue).ShowInActionCenter -ne '1') 
		{
			New-ItemProperty -Path "$Notifications_Reg\$AppID" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD' -Force
		}	
		
    try {
        if (-NOT(Test-Path $RegPath)) {
            New-Item -Path $AppRegPath -Name $AppID -Force | Out-Null
        }
        $DisplayName = Get-ItemProperty -Path $RegPath -Name DisplayName -ErrorAction SilentlyContinue | Select -ExpandProperty DisplayName -ErrorAction SilentlyContinue
        if ($DisplayName -ne $AppDisplayName) {
            New-ItemProperty -Path $RegPath -Name DisplayName -Value $AppDisplayName -PropertyType String -Force | Out-Null
        }
        $ShowInSettingsValue = Get-ItemProperty -Path $RegPath -Name ShowInSettings -ErrorAction SilentlyContinue | Select -ExpandProperty ShowInSettings -ErrorAction SilentlyContinue
        if ($ShowInSettingsValue -ne $ShowInSettings) {
            New-ItemProperty -Path $RegPath -Name ShowInSettings -Value $ShowInSettings -PropertyType DWORD -Force | Out-Null
        }
		
		New-ItemProperty -Path $RegPath -Name IconUri -Value $IconUri -PropertyType ExpandString -Force | Out-Null	
		New-ItemProperty -Path $RegPath -Name IconBackgroundColor -Value $IconBackgroundColor -PropertyType ExpandString -Force | Out-Null		
		
    }
    catch {}
}



#**************************************************************************************************************************
# 													TOAST NOTIF PART
#**************************************************************************************************************************


$Scenario = 'reminder' 


$Action = "ActionScript:"
# $Action = "powershell://$CMD_Script"
If(($Show_Action_Button -eq $True))
	{
		$Actions = 
@"
  <actions>
        <action activationType="protocol" arguments="$Action" content="$($Btn_Action)" />		
        <action activationType="protocol" arguments="Dismiss" content="$($Btn_Dissmiss)" />
   </actions>	
"@		
	}
Else
	{
		$Actions = 
@"
  <actions>
        <action activationType="protocol" arguments="Dismiss" content="$($Btn_Dissmiss)" />
   </actions>	
"@		
	}	


$xmlString = @"
<toast scenario="$Scenario">
    <visual>
    <binding template="ToastGeneric">
"@
If(($HeroImage) -and (Test-Path $HeroImage)){
    $xmlString = $xmlString + @"

    <image placement="hero" src="$HeroImage"/>
"@
}
If(($LogoImage) -and (Test-Path $LogoImage)){
    $xmlString = $xmlString + @"

    <image id="1" placement="appLogoOverride" hint-crop="circle" src="$LogoImage"/>
"@
}
If($Header_Title){
    $xmlString = $xmlString + @"

    <text id="1">$Header_Title</text>
"@
}
If($Header_Subtitles){
    $Header_Subtitles | ForEach-Object {
        $xmlString = $xmlString + @"
        
        <text>$_</text>
"@
    }
}
If($Header_Attribution){
    $xmlString = $xmlString + @"
    <text placement="attribution">$Header_Attribution</text>
"@
}

If($Body_Texts){
    $Body_Texts | ForEach-Object {
        $xmlString = $xmlString + @"
        
        <group>
            <subgroup>  
                <text hint-style="body" hint-wrap="true" >$_</text>
            </subgroup>
        </group>
"@
    }
}

$xmlString = $xmlString + @"

    </binding>
    </visual>
    $Actions
</toast>
"@


[xml]$xml = $xmlString 

$Toast_Path = "$env:temp\toast.xml"
set-content -Path $Toast_Path -Value $xml.OuterXml -Encoding Default
# d'identificateur bytes  un nom d'numrateur valide. Spcifiez l'un des noms d'numrateur suivants et ressayez :
# Unknown, String, Unicode, Byte, BigEndianUnicode, UTF8, UTF7, UTF32, Ascii, Default, Oem, BigEndianUTF32
[XML]$toast = Get-Content $Toast_Path -Encoding UTF8
remove-item $Toast_Path


$AppID = $App_title
$AppDisplayName = $App_title

Register-NotificationApp -AppID $AppID -AppDisplayName $AppDisplayName 

# Toast creation and display
$Load = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$Load = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
$ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
$ToastXml.LoadXml($Toast.OuterXml)	
# Display the Toast

[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppID).Show($ToastXml)
