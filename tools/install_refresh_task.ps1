param(
  [string]$TaskName = 'Codex-ArtesBuho-Refresh15m',
  [string]$RunnerPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\01_PROYECTOS\artes-buho-contabilidad-ia\tools\run_refresh_cycle.ps1',
  [int]$EveryMinutes = 15
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RunnerPath)) {
  throw ('No existe RunnerPath: ' + $RunnerPath)
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -File "' + $RunnerPath + '"')
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$principal = New-ScheduledTaskPrincipal -UserId ($env:USERDOMAIN + '\' + $env:USERNAME) -LogonType Interactive -RunLevel Limited

$register = Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Description 'Refresco automatico contabilidad Artes Buho cada 15 min' -Force

$runOut = Start-ScheduledTask -TaskName $TaskName
$queryOut = Get-ScheduledTask -TaskName $TaskName

$out = [ordered]@{
  ok = $true
  taskName = $TaskName
  everyMinutes = $EveryMinutes
  runnerPath = $RunnerPath
  createOutput = ($register | Select-Object TaskName,State | ConvertTo-Json -Depth 5)
  runOutput = 'Task started'
  queryOutput = ($queryOut | Select-Object TaskName,State,Author,Description | ConvertTo-Json -Depth 5)
  installedAt = (Get-Date).ToString('o')
}

$out | ConvertTo-Json -Depth 8
