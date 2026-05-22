param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$PreferredTokenProfile = 'booking_workspace_full_bella',
  [ValidateSet('oauth','service_account')]
  [string]$AuthMode = 'oauth',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$reportsDir = Join-Path $repoRoot 'audit\reports'
if (-not (Test-Path -LiteralPath $reportsDir)) {
  New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null
}
Set-Location $repoRoot

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$auditPath = Join-Path $reportsDir ("remote_sheet_deep_audit_{0}_scheduler_cycle.json" -f $stamp)
$suiteScript = Join-Path $PSScriptRoot 'remote_apply_full_suite.ps1'
$auditScript = Join-Path $PSScriptRoot 'audit_sheet_remote_deep.ps1'
$logPath = Join-Path $reportsDir 'scheduler_refresh_log.jsonl'

$entry = [ordered]@{
  startedAt = (Get-Date).ToString('o')
  spreadsheetId = $SpreadsheetId
  mode = 'sheets_api_suite'
  fallbackApplied = $false
  authMode = $AuthMode
  tokenProfile = $PreferredTokenProfile
  auditFile = $auditPath
  ok = $false
  error = ''
}

try {
  if (-not (Test-Path -LiteralPath $suiteScript)) {
    throw ('No existe suite script: ' + $suiteScript)
  }
  if (-not (Test-Path -LiteralPath $auditScript)) {
    throw ('No existe audit script: ' + $auditScript)
  }

  $suiteRaw = & $suiteScript -SpreadsheetId $SpreadsheetId -TokenProfile $PreferredTokenProfile -AuthMode $AuthMode -ServiceAccountKeyPath $ServiceAccountKeyPath | Out-String
  $entry.suiteOutput = $suiteRaw.Trim()

  $auditRaw = & $auditScript -SpreadsheetId $SpreadsheetId -TokenProfile $PreferredTokenProfile -AuthMode $AuthMode -ServiceAccountKeyPath $ServiceAccountKeyPath -OutputJson $auditPath | Out-String
  $entry.auditOutput = $auditRaw.Trim()
  $entry.ok = $true
}
catch {
  $entry.ok = $false
  $entry.error = [string]$_.Exception.Message
}
finally {
  $entry.finishedAt = (Get-Date).ToString('o')
  ($entry | ConvertTo-Json -Depth 20 -Compress) + [Environment]::NewLine | Add-Content -Path $logPath -Encoding UTF8
}

$entry | ConvertTo-Json -Depth 20
