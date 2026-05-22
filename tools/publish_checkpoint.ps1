param(
  [string]$Message = '',
  [switch]$SkipManual
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not $Message) {
  $Message = 'checkpoint: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
}

git add -A
$hasStaged = git diff --cached --name-only
if (-not $hasStaged) {
  Write-Output 'NO_CHANGES_TO_COMMIT'
  exit 0
}

git commit -m $Message | Out-Null
Write-Output ('COMMIT_OK:' + $Message)

$hasOrigin = (git remote) -contains 'origin'
if ($hasOrigin) {
  $branch = git branch --show-current
  git push -u origin $branch
  Write-Output ('PUSH_OK:' + $branch)
} else {
  Write-Output 'PUSH_SKIPPED:NO_ORIGIN_REMOTE'
}

if (-not $SkipManual) {
  try {
    $manualScript = Join-Path $PSScriptRoot 'publish_manual_drive.ps1'
    if (Test-Path -LiteralPath $manualScript) {
      $manualOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $manualScript
      Write-Output 'MANUAL_OK'
      Write-Output $manualOut
    } else {
      Write-Output 'MANUAL_WARN:publish_manual_drive.ps1 no encontrado'
    }
  } catch {
    Write-Output ('MANUAL_WARN:' + $_.Exception.Message)
  }
}
