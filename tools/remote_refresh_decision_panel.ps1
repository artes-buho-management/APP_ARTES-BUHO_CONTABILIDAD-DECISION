param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$PreferredTokenProfile = 'booking_clasp_admin',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json',
  [string]$AuditOutputJson = '',
  [switch]$SkipDeepAudit,
  [switch]$ForceFallback
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$claspPath = Join-Path $repoRoot 'appscript\.clasp.json'
$clasprcPath = 'C:\Users\elrub\.clasprc.json'
$runUrl = $null

function Get-ExceptionDetails {
  param($ErrorRecord)

  $message = ''
  $status = $null
  $body = ''

  try { $message = [string]$ErrorRecord.Exception.Message } catch {}
  try {
    if ($ErrorRecord.Exception.Response) {
      $status = [int]$ErrorRecord.Exception.Response.StatusCode.value__
      $reader = New-Object IO.StreamReader($ErrorRecord.Exception.Response.GetResponseStream())
      $body = $reader.ReadToEnd()
      $reader.Close()
    }
  } catch {}

  return [ordered]@{
    message = $message
    status = $status
    body = $body
  }
}

function Get-OAuthAccessToken {
  param(
    [string]$Clasprc,
    [object]$TokenCandidate
  )

  if (-not (Test-Path -LiteralPath $Clasprc)) {
    throw ('No existe .clasprc: ' + $Clasprc)
  }

  $cfg = Get-Content $Clasprc -Raw | ConvertFrom-Json

  $kind = [string]$TokenCandidate.kind
  $id = [string]$TokenCandidate.id

  $clientId = ''
  $clientSecret = ''
  $refreshToken = ''
  $accessToken = ''
  $expiryDate = 0

  if ($kind -eq 'profile') {
    if (-not $cfg.tokens) {
      throw 'No existe bloque "tokens" en .clasprc para candidate tipo profile'
    }
    $tok = $cfg.tokens.$id
    if (-not $tok) {
      throw ('Token profile no encontrado: ' + $id)
    }
    $clientId = [string]$tok.client_id
    $clientSecret = [string]$tok.client_secret
    $refreshToken = [string]$tok.refresh_token
    $accessToken = [string]$tok.access_token
    try { $expiryDate = [double]$tok.expiry_date } catch { $expiryDate = 0 }
  }
  elseif ($kind -eq 'root_v2') {
    if (-not $cfg.token -or -not $cfg.oauth2ClientSettings) {
      throw 'Formato root_v2 incompleto en .clasprc (falta token u oauth2ClientSettings)'
    }
    $clientId = [string]$cfg.oauth2ClientSettings.clientId
    $clientSecret = [string]$cfg.oauth2ClientSettings.clientSecret
    $refreshToken = [string]$cfg.token.refresh_token
    $accessToken = [string]$cfg.token.access_token
    try { $expiryDate = [double]$cfg.token.expiry_date } catch { $expiryDate = 0 }
  }
  else {
    throw ('TokenCandidate.kind no soportado: ' + $kind)
  }

  if (-not [string]::IsNullOrWhiteSpace($refreshToken)) {
    $resp = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
      client_id = $clientId
      client_secret = $clientSecret
      refresh_token = $refreshToken
      grant_type = 'refresh_token'
    }

    if (-not $resp.access_token) {
      throw ('No se pudo obtener access_token renovado para candidate: ' + $id)
    }
    return [string]$resp.access_token
  }

  if (-not [string]::IsNullOrWhiteSpace($accessToken) -and $expiryDate -gt 0) {
    $nowMs = [double]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
    if ($expiryDate -gt ($nowMs + 60000)) {
      return $accessToken
    }
  }

  throw ('No hay refresh_token valido ni access_token vigente para candidate: ' + $id)
}

function Invoke-ScriptsRun {
  param(
    [string]$Url,
    [string]$AccessToken,
    [string]$FunctionName,
    [object[]]$Parameters = @()
  )

  $headers = @{ Authorization = ('Bearer ' + $AccessToken) }
  $payload = @{
    function = $FunctionName
    parameters = $Parameters
    devMode = $true
  } | ConvertTo-Json -Depth 10

  return Invoke-RestMethod -Method Post -Uri $Url -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
}

function Get-TokenCandidates {
  param(
    [string]$Clasprc,
    [string]$Preferred
  )

  $cfg = Get-Content $Clasprc -Raw | ConvertFrom-Json
  $ordered = New-Object System.Collections.ArrayList

  if ($cfg.tokens) {
    $all = @($cfg.tokens.PSObject.Properties.Name)
    if ($Preferred -and ($all -contains $Preferred)) {
      [void]$ordered.Add([ordered]@{ id = $Preferred; kind = 'profile' })
    }
    foreach ($p in $all) {
      $exists = $false
      foreach ($it in $ordered) {
        if ($it.id -eq $p -and $it.kind -eq 'profile') { $exists = $true; break }
      }
      if (-not $exists) {
        [void]$ordered.Add([ordered]@{ id = $p; kind = 'profile' })
      }
    }
  }

  if ($cfg.token -and $cfg.oauth2ClientSettings) {
    $existsRoot = $false
    foreach ($it in $ordered) {
      if ($it.kind -eq 'root_v2') { $existsRoot = $true; break }
    }
    if (-not $existsRoot) {
      [void]$ordered.Add([ordered]@{ id = 'root_v2_default'; kind = 'root_v2' })
    }
  }

  return @($ordered)
}

function Try-RunQuarterRefreshWithOAuth {
  param(
    [object[]]$TokenCandidates,
    [string]$Clasprc,
    [string]$RunUrl,
    [System.Collections.ArrayList]$RunErrors
  )

  $runSuccess = $null
  foreach ($candidate in $TokenCandidates) {
    try {
      $token = Get-OAuthAccessToken -Clasprc $Clasprc -TokenCandidate $candidate
      $response = Invoke-ScriptsRun -Url $RunUrl -AccessToken $token -FunctionName 'runQuarterRefresh'

      if ($response.error) {
        [void]$RunErrors.Add([ordered]@{
          profile = ([string]$candidate.id + ':' + [string]$candidate.kind)
          stage = 'runQuarterRefresh'
          error = $response.error
        })
        continue
      }

      $runSuccess = [ordered]@{
        profile = ([string]$candidate.id + ':' + [string]$candidate.kind)
        function = 'runQuarterRefresh'
        response = $response.response
      }
      break
    }
    catch {
      [void]$RunErrors.Add([ordered]@{
        profile = ([string]$candidate.id + ':' + [string]$candidate.kind)
        stage = 'runQuarterRefresh'
        error = (Get-ExceptionDetails -ErrorRecord $_)
      })
    }
  }

  return $runSuccess
}

function Has-PermissionDeniedError {
  param([System.Collections.ArrayList]$RunErrors)

  foreach ($e in $RunErrors) {
    $json = ''
    try { $json = ($e | ConvertTo-Json -Depth 10) } catch {}
    if ($json -match 'PERMISSION_DENIED' -or $json -match 'does not have permission' -or $json -match 'forbidden') {
      return $true
    }
  }
  return $false
}

if (-not (Test-Path -LiteralPath $claspPath)) {
  throw ('No existe .clasp.json: ' + $claspPath)
}

$clasp = Get-Content $claspPath -Raw | ConvertFrom-Json
$scriptId = [string]$clasp.scriptId
if ([string]::IsNullOrWhiteSpace($scriptId)) {
  throw 'scriptId vacio en .clasp.json'
}

$runUrl = "https://script.googleapis.com/v1/scripts/${scriptId}:run"
$tokenCandidates = @()
if (-not $ForceFallback) {
  $tokenCandidates = Get-TokenCandidates -Clasprc $clasprcPath -Preferred $PreferredTokenProfile
}

$runErrors = New-Object System.Collections.ArrayList
$runSuccess = $null
$permissionSelfHeal = $null

if ((-not $ForceFallback) -and (-not $tokenCandidates -or $tokenCandidates.Count -eq 0)) {
  [void]$runErrors.Add([ordered]@{
    profile = ''
    stage = 'token_discovery'
    error = [ordered]@{
      message = 'No se encontraron candidatos OAuth en .clasprc'
      status = $null
      body = ''
    }
  })
}

if ((-not $ForceFallback) -and $tokenCandidates -and $tokenCandidates.Count -gt 0) {
  $runSuccess = Try-RunQuarterRefreshWithOAuth -TokenCandidates $tokenCandidates -Clasprc $clasprcPath -RunUrl $runUrl -RunErrors $runErrors
}

if ((-not $ForceFallback) -and -not $runSuccess -and (Has-PermissionDeniedError -RunErrors $runErrors)) {
  $permScript = Join-Path $PSScriptRoot 'sync_script_permissions_service_account.ps1'
  if (Test-Path -LiteralPath $permScript) {
    try {
      $permissionSelfHeal = & $permScript -SpreadsheetId $SpreadsheetId -ScriptId $scriptId -ServiceAccountKeyPath $ServiceAccountKeyPath | Out-String
      $runSuccess = Try-RunQuarterRefreshWithOAuth -TokenCandidates $tokenCandidates -Clasprc $clasprcPath -RunUrl $runUrl -RunErrors $runErrors
    }
    catch {
      [void]$runErrors.Add([ordered]@{
        profile = 'self_heal_permissions'
        stage = 'sync_script_permissions'
        error = (Get-ExceptionDetails -ErrorRecord $_)
      })
    }
  } else {
    [void]$runErrors.Add([ordered]@{
      profile = 'self_heal_permissions'
      stage = 'sync_script_permissions'
      error = [ordered]@{ message = ('No existe script de autocorreccion de permisos: ' + $permScript); status = $null; body = '' }
    })
  }
}

$fallbackApplied = $false
$fallbackResult = $null

if (-not $runSuccess) {
  $fallbackApplied = $true
  $fallbackScript = Join-Path $PSScriptRoot 'remote_decision_mode_minimal.ps1'
  if (-not (Test-Path -LiteralPath $fallbackScript)) {
    throw ('No existe fallback script: ' + $fallbackScript)
  }

  $fallbackResult = & $fallbackScript -SpreadsheetId $SpreadsheetId -ServiceAccountKeyPath $ServiceAccountKeyPath -RefreshOnly | Out-String
}

$auditOutput = ''
if (-not $SkipDeepAudit) {
  if ([string]::IsNullOrWhiteSpace($AuditOutputJson)) {
    $stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $AuditOutputJson = "audit\\reports\\remote_sheet_deep_audit_${stamp}_post_refresh_total.json"
  }

  $auditScript = Join-Path $PSScriptRoot 'audit_sheet_remote_deep.ps1'
  if (-not (Test-Path -LiteralPath $auditScript)) {
    throw ('No existe script de auditoria: ' + $auditScript)
  }

  $auditOutput = & $auditScript -SpreadsheetId $SpreadsheetId -AuthMode service_account -ServiceAccountKeyPath $ServiceAccountKeyPath -OutputJson $AuditOutputJson | Out-String
}

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  scriptId = $scriptId
  mode = if ($runSuccess) { 'scripts_run' } else { 'sheets_api_fallback' }
  scriptsRunSuccess = $runSuccess
  scriptsRunErrors = $runErrors
  fallbackApplied = $fallbackApplied
  forceFallback = [bool]$ForceFallback
  permissionSelfHeal = $permissionSelfHeal
  fallbackOutput = $fallbackResult
  deepAuditSkipped = [bool]$SkipDeepAudit
  auditOutput = $auditOutput.Trim()
  auditFile = $AuditOutputJson
  executedAt = (Get-Date).ToString('o')
}

$out | ConvertTo-Json -Depth 30
