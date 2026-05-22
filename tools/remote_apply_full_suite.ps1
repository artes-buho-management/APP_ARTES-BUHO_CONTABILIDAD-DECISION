param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$TokenProfile = 'default',
  [ValidateSet('oauth','service_account')]
  [string]$AuthMode = 'service_account',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json'
)

$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$run1 = & "$toolsDir\remote_build_accounting_sheet.ps1" -SpreadsheetId $SpreadsheetId -TokenProfile $TokenProfile -AuthMode $AuthMode -ServiceAccountKeyPath $ServiceAccountKeyPath | Out-String
$run2 = & "$toolsDir\remote_upgrade_full_app.ps1" -SpreadsheetId $SpreadsheetId -TokenProfile $TokenProfile -AuthMode $AuthMode -ServiceAccountKeyPath $ServiceAccountKeyPath | Out-String
$run3 = & "$toolsDir\remote_upgrade_lineas_negocio.ps1" -SpreadsheetId $SpreadsheetId -TokenProfile $TokenProfile -AuthMode $AuthMode -ServiceAccountKeyPath $ServiceAccountKeyPath | Out-String

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  authMode = $AuthMode
  executed = @(
    'remote_build_accounting_sheet.ps1',
    'remote_upgrade_full_app.ps1',
    'remote_upgrade_lineas_negocio.ps1'
  )
  timestamp = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 5
