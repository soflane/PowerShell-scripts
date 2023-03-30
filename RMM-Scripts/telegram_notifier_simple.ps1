param (
  [string] $alerttime="",
  [string] $alertmessage="Test",
  [string] $alertseverity="Critical",
  [string] $alertstatus="testing",
  [string] $alerttitle="RMM-Alert"
)

$Telegramtoken = "xxxxxxxxxx:xxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxx"
$Telegramchatid = "xxxxxxxxx"



$content = @"
[$alerttitle]
Une nouvelle alerte
Sévérité : $alertseverity 
Statut : $alertstatus 
Message : 
$alertmessage
"@

$hookUrl = "https://api.telegram.org/bot$($Telegramtoken)/sendMessage?chat_id=$($Telegramchatid)&text=$($content)"
Invoke-RestMethod -Uri $hookUrl -ContentType 'charset=utf-8'