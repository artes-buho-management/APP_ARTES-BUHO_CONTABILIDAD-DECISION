param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$ScriptId = 'REPLACE_WITH_ID',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json'
)

$ErrorActionPreference = 'Stop'

function Get-NodeCommand {
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return [string]$cmd.Source }

  $candidates = @(
    'C:\Program Files\nodejs\node.exe',
    (Join-Path ${env:ProgramFiles} 'nodejs\node.exe'),
    (Join-Path ${env:LOCALAPPDATA} 'Programs\nodejs\node.exe')
  )
  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
      return [string]$candidate
    }
  }
  throw 'Node.js no encontrado. Instala Node o anade C:\Program Files\nodejs al PATH.'
}

function Get-AccessToken {
  param([string]$ServiceAccountKey)

  $helper = Join-Path $PSScriptRoot 'get_service_account_access_token.js'
  if (-not (Test-Path -LiteralPath $helper)) {
    throw ('No existe helper de cuenta de servicio: ' + $helper)
  }
  if (-not (Test-Path -LiteralPath $ServiceAccountKey)) {
    throw ('No existe ServiceAccountKeyPath: ' + $ServiceAccountKey)
  }

  $nodeCmd = Get-NodeCommand
  $token = & $nodeCmd $helper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/spreadsheets'
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw 'No se pudo obtener access_token con cuenta de servicio'
  }
  return [string]$token
}

function Invoke-GApi {
  param(
    [ValidateSet('GET','POST')]
    [string]$Method,
    [string]$Uri,
    [string]$Token,
    $Body = $null
  )

  $headers = @{ Authorization = ('Bearer ' + $Token) }
  try {
    if ($Method -eq 'GET') {
      return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers -ErrorAction Stop
    }

    $json = if ($null -eq $Body) { '{}' } else { $Body | ConvertTo-Json -Depth 20 }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Method Post -Uri $Uri -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bytes -ErrorAction Stop
  }
  catch {
    if ($_.Exception.Response) {
      $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
      $txt = $sr.ReadToEnd()
      $sr.Close()
      throw ('API_ERROR: ' + $Method + ' ' + $Uri + ' -> ' + $txt)
    }
    throw
  }
}

$token = Get-AccessToken -ServiceAccountKey $ServiceAccountKeyPath

$sheetPermUri = "https://www.googleapis.com/drive/v3/files/{0}/permissions?fields=permissions(id,type,role,emailAddress,domain)" -f $SpreadsheetId
$scriptPermUri = "https://www.googleapis.com/drive/v3/files/{0}/permissions?fields=permissions(id,type,role,emailAddress,domain)" -f $ScriptId

$sheetPerms = Invoke-GApi -Method GET -Uri $sheetPermUri -Token $token
$scriptPerms = Invoke-GApi -Method GET -Uri $scriptPermUri -Token $token

$seedEditors = @(
  'booking@artesbuhomanagement.com',
  'REPLACE_WITH_OWNER_EMAIL',
  'artesbuho.oficial@gmail.com',
  'danielgomezartesbuho@gmail.com',
  'manupinomartinez@gmail.com',
  'samuelsocasinfo@gmail.com',
  'lydiaarandafdez@gmail.com',
  'miridb.93@gmail.com'
)

$target = New-Object 'System.Collections.Generic.HashSet[string]'
$current = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($p in $sheetPerms.permissions) {
  if ($p.type -eq 'user' -and -not [string]::IsNullOrWhiteSpace([string]$p.emailAddress)) {
    [void]$target.Add(([string]$p.emailAddress).ToLowerInvariant())
  }
}
foreach ($e in $seedEditors) {
  if (-not [string]::IsNullOrWhiteSpace([string]$e)) {
    [void]$target.Add(([string]$e).ToLowerInvariant())
  }
}

foreach ($p in $scriptPerms.permissions) {
  if ($p.type -eq 'user' -and -not [string]::IsNullOrWhiteSpace([string]$p.emailAddress)) {
    [void]$current.Add(([string]$p.emailAddress).ToLowerInvariant())
  }
}

$added = New-Object System.Collections.ArrayList
$skipped = New-Object System.Collections.ArrayList
$errors = New-Object System.Collections.ArrayList

foreach ($email in $target) {
  if ($current.Contains($email)) {
    [void]$skipped.Add($email)
    continue
  }

  try {
    $createUri = "https://www.googleapis.com/drive/v3/files/{0}/permissions?sendNotificationEmail=false" -f $ScriptId
    Invoke-GApi -Method POST -Uri $createUri -Token $token -Body @{
      role = 'writer'
      type = 'user'
      emailAddress = $email
    } | Out-Null
    [void]$added.Add($email)
  }
  catch {
    [void]$errors.Add([ordered]@{
      email = $email
      error = [string]$_.Exception.Message
    })
  }
}

$out = [ordered]@{
  ok = ($errors.Count -eq 0)
  spreadsheetId = $SpreadsheetId
  scriptId = $ScriptId
  targetUsers = $target.Count
  alreadyHadAccess = $skipped.Count
  added = $added
  errors = $errors
  updatedAt = (Get-Date).ToString('o')
}

$out | ConvertTo-Json -Depth 8
