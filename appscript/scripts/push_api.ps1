param(
  [string]$TokenProfile = 'default',
  [ValidateSet('auto','oauth','service_account')]
  [string]$AuthMode = 'auto',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$claspPath = Join-Path $projectRoot '.clasp.json'
$manifestPath = Join-Path $projectRoot 'appsscript.json'
$codePath = Join-Path $projectRoot 'Code.js'
$rcPath = 'C:\Users\elrub\.clasprc.json'
$tokenHelper = Join-Path (Split-Path -Parent $projectRoot) 'tools\get_service_account_access_token.js'
$tokenHelperPy = Join-Path (Split-Path -Parent $projectRoot) 'tools\get_service_account_access_token.py'

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

function Get-NpxCommand {
  $cmd = Get-Command npx -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return [string]$cmd.Source }

  $candidates = @(
    'C:\Program Files\nodejs\npx.cmd',
    (Join-Path ${env:ProgramFiles} 'nodejs\npx.cmd'),
    (Join-Path ${env:LOCALAPPDATA} 'Programs\nodejs\npx.cmd')
  )
  foreach ($candidate in $candidates) {
    if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
      return [string]$candidate
    }
  }
  throw 'npx no encontrado. Instala Node.js completo.'
}

function Get-PythonCommand {
  $cmd = Get-Command python -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
  throw 'Python no encontrado.'
}

function Get-ErrorBody {
  param($Exception)
  try {
    if ($Exception.Response) {
      $sr = New-Object IO.StreamReader($Exception.Response.GetResponseStream())
      $txt = $sr.ReadToEnd()
      $sr.Close()
      return [string]$txt
    }
  } catch {}
  return ''
}

function Get-OAuthAccessToken {
  param([pscustomobject]$Token)
  $refresh = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
    client_id = $Token.client_id
    client_secret = $Token.client_secret
    refresh_token = $Token.refresh_token
    grant_type = 'refresh_token'
  }
  if (-not $refresh.access_token) { throw 'Could not refresh access_token' }
  return [string]$refresh.access_token
}

function Get-ServiceAccountAccessToken {
  if (-not (Test-Path -LiteralPath $ServiceAccountKeyPath)) {
    throw ('Missing ServiceAccountKeyPath: ' + $ServiceAccountKeyPath)
  }
  $token = ''
  try {
    if (-not (Test-Path -LiteralPath $tokenHelper)) {
      throw ('Missing token helper: ' + $tokenHelper)
    }
    $nodeCmd = Get-NodeCommand
    $token = & $nodeCmd $tokenHelper --keyPath $ServiceAccountKeyPath --scopes 'https://www.googleapis.com/auth/script.projects,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
  } catch {
    if (-not (Test-Path -LiteralPath $tokenHelperPy)) {
      throw ('Missing token helper: ' + $tokenHelper + ' / ' + $tokenHelperPy)
    }
    $pythonCmd = Get-PythonCommand
    $token = & $pythonCmd $tokenHelperPy --keyPath $ServiceAccountKeyPath --scopes 'https://www.googleapis.com/auth/script.projects,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
  }
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw 'Could not get access_token from service account'
  }
  return [string]$token
}

function Try-UpdateScript {
  param(
    [string]$ScriptId,
    [string]$AccessToken,
    [string]$ManifestSource,
    [string]$CodeSource,
    [string]$AuthLabel
  )

  $body = @{ files = @(
    @{ name = 'appsscript'; type = 'JSON'; source = $ManifestSource },
    @{ name = 'Code'; type = 'SERVER_JS'; source = $CodeSource }
  ) } | ConvertTo-Json -Depth 10

  try {
    Invoke-RestMethod -Method Put -Uri ("https://script.googleapis.com/v1/projects/{0}/content" -f $ScriptId) -Headers @{ Authorization = ('Bearer ' + $AccessToken) } -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -ErrorAction Stop | Out-Null
    return [ordered]@{ ok = $true; auth = $AuthLabel; error = ''; body = '' }
  } catch {
    return [ordered]@{
      ok = $false
      auth = $AuthLabel
      error = [string]$_.Exception.Message
      body = (Get-ErrorBody -Exception $_.Exception)
    }
  }
}

function Try-ClaspPush {
  param([string]$ProjectRoot)

  try {
    $nodeCmd = Get-NodeCommand
    $npxCmd = Get-NpxCommand
    $nodeDir = Split-Path -Parent $nodeCmd
    if (-not [string]::IsNullOrWhiteSpace($nodeDir) -and -not (($env:PATH -split ';') -contains $nodeDir)) {
      $env:PATH = $nodeDir + ';' + $env:PATH
    }
  } catch {
    return [ordered]@{
      ok = $false
      auth = 'clasp_fallback'
      error = [string]$_.Exception.Message
      body = ''
    }
  }

  $previous = Get-Location
  try {
    Set-Location $ProjectRoot
    $out = & $npxCmd clasp push --force 2>&1
    $exitCode = $LASTEXITCODE
    $txt = [string]($out | Out-String).Trim()
    if ($exitCode -eq 0) {
      return [ordered]@{ ok = $true; auth = 'clasp_fallback'; error = ''; body = $txt }
    }
    return [ordered]@{ ok = $false; auth = 'clasp_fallback'; error = 'clasp push fallo'; body = $txt }
  } catch {
    return [ordered]@{
      ok = $false
      auth = 'clasp_fallback'
      error = [string]$_.Exception.Message
      body = ''
    }
  } finally {
    Set-Location $previous
  }
}

if (-not (Test-Path $claspPath)) { throw 'Missing .clasp.json' }
if (-not (Test-Path $manifestPath)) { throw 'Missing appsscript.json' }
if (-not (Test-Path $codePath)) { throw 'Missing Code.js' }

$clasp = Get-Content $claspPath -Raw | ConvertFrom-Json
$scriptId = $clasp.scriptId
if (-not $scriptId) { throw 'scriptId missing in .clasp.json' }

$manifestSource = [System.IO.File]::ReadAllText($manifestPath)
$codeSource = [System.IO.File]::ReadAllText($codePath)
$attempts = New-Object System.Collections.Generic.List[object]

if ($AuthMode -eq 'oauth' -or $AuthMode -eq 'auto') {
  $canRunOauth = $true
  $cfg = $null

  if (-not (Test-Path $rcPath)) {
    $canRunOauth = $false
    $attempts.Add([ordered]@{
      ok = $false
      auth = 'oauth'
      error = 'Missing C:\Users\elrub\.clasprc.json'
      body = ''
    }) | Out-Null
    if ($AuthMode -eq 'oauth') { throw 'Missing C:\Users\elrub\.clasprc.json' }
  }

  if ($canRunOauth) {
    try {
      $cfg = Get-Content $rcPath -Raw | ConvertFrom-Json
      if (-not $cfg.tokens) {
        $canRunOauth = $false
        $attempts.Add([ordered]@{
          ok = $false
          auth = 'oauth'
          error = 'No tokens block in C:\Users\elrub\.clasprc.json'
          body = ''
        }) | Out-Null
        if ($AuthMode -eq 'oauth') { throw 'No tokens block in C:\Users\elrub\.clasprc.json' }
      }
    } catch {
      if ($AuthMode -eq 'oauth') { throw }
      $canRunOauth = $false
      $attempts.Add([ordered]@{
        ok = $false
        auth = 'oauth'
        error = [string]$_.Exception.Message
        body = ''
      }) | Out-Null
    }
  }

  if ($canRunOauth) {
    $orderedProfiles = New-Object System.Collections.ArrayList
    if ($cfg.tokens.$TokenProfile) { [void]$orderedProfiles.Add($TokenProfile) }
    foreach ($name in $cfg.tokens.PSObject.Properties.Name) {
      if (-not ($orderedProfiles -contains $name)) { [void]$orderedProfiles.Add($name) }
    }

    foreach ($profile in $orderedProfiles) {
      try {
        $token = Get-OAuthAccessToken -Token $cfg.tokens.$profile
        $res = Try-UpdateScript -ScriptId $scriptId -AccessToken $token -ManifestSource $manifestSource -CodeSource $codeSource -AuthLabel ('oauth:' + $profile)
        if ($res.ok) {
          Write-Output ('PUSH_OK scriptId=' + $scriptId)
          Write-Output ('AUTH_MODE=' + $res.auth)
          Write-Output ('EDITOR_URL=https://script.google.com/d/' + $scriptId + '/edit')
          return
        }
        $attempts.Add($res) | Out-Null
      } catch {
        $attempts.Add([ordered]@{
          ok = $false
          auth = 'oauth:' + $profile
          error = [string]$_.Exception.Message
          body = ''
        }) | Out-Null
      }
    }
  }

  if ($AuthMode -eq 'oauth') {
    throw ('PUSH_FAILED_OAUTH=' + ($attempts | ConvertTo-Json -Depth 6 -Compress))
  }
}

if ($AuthMode -eq 'service_account' -or $AuthMode -eq 'auto') {
  try {
    $saToken = Get-ServiceAccountAccessToken
    $res = Try-UpdateScript -ScriptId $scriptId -AccessToken $saToken -ManifestSource $manifestSource -CodeSource $codeSource -AuthLabel 'service_account'
    if ($res.ok) {
      Write-Output ('PUSH_OK scriptId=' + $scriptId)
      Write-Output ('AUTH_MODE=' + $res.auth)
      Write-Output ('EDITOR_URL=https://script.google.com/d/' + $scriptId + '/edit')
      return
    }
    $attempts.Add($res) | Out-Null
  } catch {
    $attempts.Add([ordered]@{
      ok = $false
      auth = 'service_account'
      error = [string]$_.Exception.Message
      body = ''
    }) | Out-Null
  }
}

if ($AuthMode -eq 'auto') {
  $claspRes = Try-ClaspPush -ProjectRoot $projectRoot
  if ($claspRes.ok) {
    Write-Output ('PUSH_OK scriptId=' + $scriptId)
    Write-Output ('AUTH_MODE=' + $claspRes.auth)
    Write-Output ('EDITOR_URL=https://script.google.com/d/' + $scriptId + '/edit')
    if (-not [string]::IsNullOrWhiteSpace([string]$claspRes.body)) {
      Write-Output ('DETAIL=' + [string]$claspRes.body)
    }
    return
  }
  $attempts.Add($claspRes) | Out-Null
}

throw ('PUSH_FAILED_ALL=' + ($attempts | ConvertTo-Json -Depth 8 -Compress))
