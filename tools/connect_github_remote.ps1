param(
  [Parameter(Mandatory=$true)]
  [string]$RemoteUrl
)

$ErrorActionPreference='Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Test-Path '.git')) {
  git init -b main | Out-Null
}

$existing = git remote 2>$null
if ($existing -match '^origin$') {
  git remote set-url origin $RemoteUrl
} else {
  git remote add origin $RemoteUrl
}

Write-Output ('REMOTE_SET=' + $RemoteUrl)
Write-Output 'NEXT: git push -u origin codex/unificacion-contabilidad-ia'
