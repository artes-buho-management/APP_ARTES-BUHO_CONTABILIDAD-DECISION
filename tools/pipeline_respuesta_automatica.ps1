param(
  [string]$CommitMessage = '',
  [switch]$PublishManual
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Ensure-NodePath {
  $existing = Get-Command node -ErrorAction SilentlyContinue
  if ($existing) { return }

  $candidateDirs = @(
    'C:\Program Files\nodejs',
    (Join-Path ${env:ProgramFiles} 'nodejs'),
    (Join-Path ${env:LOCALAPPDATA} 'Programs\nodejs')
  )
  foreach ($dir in $candidateDirs) {
    if (-not [string]::IsNullOrWhiteSpace($dir) -and (Test-Path -LiteralPath $dir)) {
      if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $dir })) {
        $env:PATH += ';' + $dir
      }
    }
  }
}

Ensure-NodePath

if (-not $CommitMessage) {
  $CommitMessage = 'auto-sync ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' [PC_RUBEN_COTON]'
}

$branch = (git branch --show-current).Trim()
$beforeHead = (git rev-parse --short HEAD).Trim()

git add -A
$stagedFiles = git diff --cached --name-only
$hasChanges = -not [string]::IsNullOrWhiteSpace(($stagedFiles | Out-String))
$manualTouched = $false
if ($hasChanges) {
  foreach ($f in ($stagedFiles -split "`r?`n")) {
    if ($f -match '^docs/MANUAL_USO_CONTABILIDAD_IA\.md$' -or $f -match '^tools/publish_manual_drive\.ps1$') {
      $manualTouched = $true
    }
  }
}

$commitResult = 'NO_CHANGES'
$newHead = $beforeHead
if ($hasChanges) {
  git commit -m $CommitMessage | Out-Null
  $newHead = (git rev-parse --short HEAD).Trim()
  $commitResult = 'COMMIT_OK'
}

git fetch origin --prune | Out-Null
git push origin $branch | Out-Null

$pushApiOutput = ''
$pushApiExitCode = 0
try {
  $pushApiRaw = & powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'appscript\scripts\push_api.ps1') -AuthMode auto -TokenProfile booking_workspace_full_bella 2>&1
  $pushApiExitCode = $LASTEXITCODE
  $pushApiOutput = [string]($pushApiRaw | Out-String).Trim()
} catch {
  $pushApiExitCode = if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { $LASTEXITCODE } else { 1 }
  $pushApiOutput = [string]$_.Exception.Message
}
$decisionOutput = & powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\remote_apply_full_suite.ps1') -AuthMode oauth -TokenProfile booking_workspace_full_bella
$refreshOutput = & powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\run_refresh_cycle.ps1') -PreferredTokenProfile booking_workspace_full_bella

$manualOutput = ''
$manualExitCode = 0
$manualExecuted = $false
if ($PublishManual -or $manualTouched) {
  $manualExecuted = $true
  try {
    $manualRaw = & powershell -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\publish_manual_drive.ps1') -AuthMode oauth -TokenProfile booking_workspace_full_bella 2>&1
    $manualExitCode = $LASTEXITCODE
    $manualOutput = [string]($manualRaw | Out-String).Trim()
  } catch {
    $manualExitCode = if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { $LASTEXITCODE } else { 1 }
    $manualOutput = [string]$_.Exception.Message
  }
}

$postCommitResult = 'NO_POST_CHANGES'
$postHead = (git rev-parse --short HEAD).Trim()
git add -A
$postStaged = git diff --cached --name-only
$hasPostChanges = -not [string]::IsNullOrWhiteSpace(($postStaged | Out-String))
if ($hasPostChanges) {
  $postMessage = 'chore: registrar publicacion automatica ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  git commit -m $postMessage | Out-Null
  git push origin $branch | Out-Null
  $postHead = (git rev-parse --short HEAD).Trim()
  $postCommitResult = 'POST_COMMIT_OK'
}

$result = [ordered]@{
  ok = $true
  repo = $repoRoot
  branch = $branch
  beforeHead = $beforeHead
  afterHead = $postHead
  commitResult = $commitResult
  postCommitResult = $postCommitResult
  manualExecuted = $manualExecuted
  stagedFiles = @($stagedFiles)
  postStagedFiles = @($postStaged)
  pushApiOutput = [string]($pushApiOutput | Out-String).Trim()
  pushApiExitCode = $pushApiExitCode
  manualExitCode = $manualExitCode
  decisionOutput = [string]($decisionOutput | Out-String).Trim()
  refreshOutput = [string]($refreshOutput | Out-String).Trim()
  manualOutput = [string]($manualOutput | Out-String).Trim()
  executedAt = (Get-Date).ToString('o')
}

$reportDir = Join-Path $repoRoot 'audit\reports'
if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$reportPath = Join-Path $reportDir ('pipeline_respuesta_automatica_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.json')
$result | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8

$finalPostCommit = 'NO_FINAL_PIPELINE_CHANGES'
git add -A
$finalStaged = git diff --cached --name-only
$hasFinalChanges = -not [string]::IsNullOrWhiteSpace(($finalStaged | Out-String))
if ($hasFinalChanges) {
  $finalMessage = 'chore: registrar ejecucion pipeline ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  git commit -m $finalMessage | Out-Null
  git push origin $branch | Out-Null
  $finalPostCommit = 'FINAL_PIPELINE_COMMIT_OK'
}

$result.finalPostCommit = $finalPostCommit
$result.finalHead = (git rev-parse --short HEAD).Trim()
$result | ConvertTo-Json -Depth 8
