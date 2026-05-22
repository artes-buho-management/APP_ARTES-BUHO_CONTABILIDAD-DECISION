param([string]$TokenProfile = 'default')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$claspPath = Join-Path $projectRoot '.clasp.json'
$rcPath = 'C:\Users\elrub\.clasprc.json'

if (-not (Test-Path $claspPath)) { throw 'Missing .clasp.json' }
if (-not (Test-Path $rcPath)) { throw 'Missing C:\Users\elrub\.clasprc.json' }

$clasp = Get-Content $claspPath -Raw | ConvertFrom-Json
$scriptId = $clasp.scriptId
if (-not $scriptId) { throw 'scriptId missing in .clasp.json' }

$cfg = Get-Content $rcPath -Raw | ConvertFrom-Json
if (-not $cfg.tokens) { throw 'No tokens block in C:\Users\elrub\.clasprc.json' }

$orderedProfiles = New-Object System.Collections.ArrayList
if ($cfg.tokens.$TokenProfile) { [void]$orderedProfiles.Add($TokenProfile) }
foreach ($name in $cfg.tokens.PSObject.Properties.Name) {
  if (-not ($orderedProfiles -contains $name)) { [void]$orderedProfiles.Add($name) }
}

$attempts = New-Object System.Collections.ArrayList

foreach ($profile in $orderedProfiles) {
  try {
    $tok = $cfg.tokens.$profile
    $refresh = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
      client_id = $tok.client_id
      client_secret = $tok.client_secret
      refresh_token = $tok.refresh_token
      grant_type = 'refresh_token'
    }
    if (-not $refresh.access_token) { throw 'Could not refresh access_token' }

    $headers = @{ Authorization = ('Bearer ' + $refresh.access_token) }
    $content = Invoke-RestMethod -Method Get -Uri ("https://script.googleapis.com/v1/projects/{0}/content" -f $scriptId) -Headers $headers

    foreach ($f in $content.files) {
      if ($f.name -eq 'appsscript' -and $f.type -eq 'JSON') {
        [System.IO.File]::WriteAllText((Join-Path $projectRoot 'appsscript.json'), $f.source, [System.Text.UTF8Encoding]::new($false))
        continue
      }

      if ($f.type -eq 'SERVER_JS') {
        [System.IO.File]::WriteAllText((Join-Path $projectRoot ($f.name + '.js')), $f.source, [System.Text.UTF8Encoding]::new($false))
        continue
      }

      if ($f.type -eq 'HTML') {
        [System.IO.File]::WriteAllText((Join-Path $projectRoot ($f.name + '.html')), $f.source, [System.Text.UTF8Encoding]::new($false))
      }
    }

    Write-Output ('PULL_OK scriptId=' + $scriptId)
    Write-Output ('AUTH_MODE=oauth:' + $profile)
    Write-Output ('FILES=' + (($content.files | Select-Object -ExpandProperty name) -join ','))
    return
  } catch {
    $attempts.Add([ordered]@{
      auth = 'oauth:' + $profile
      error = [string]$_.Exception.Message
    }) | Out-Null
  }
}

throw ('PULL_FAILED_OAUTH=' + ($attempts | ConvertTo-Json -Depth 6 -Compress))


