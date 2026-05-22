param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$TokenProfile = 'booking_workspace_full_bella',
  [ValidateSet('oauth','service_account')]
  [string]$AuthMode = 'oauth',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json',
  [string]$ManualPath = 'docs\MANUAL_USO_CONTABILIDAD_IA.md',
  [string]$ManualPrefix = 'MANUAL_CONTABILIDAD_ARTES_BUHO',
  [string]$ManualFolderId = '11R9oOlWyIGPM3VY2gPNk-dQIQ59WJM0s',
  [switch]$UseManualFolderOnly
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
  param(
    [string]$Profile,
    [ValidateSet('oauth','service_account')]
    [string]$Mode,
    [string]$ServiceAccountKey
  )

  if ($Mode -eq 'service_account') {
    $helper = Join-Path $PSScriptRoot 'get_service_account_access_token.js'
    if (-not (Test-Path -LiteralPath $helper)) {
      throw ('No existe helper de cuenta de servicio: ' + $helper)
    }
    if (-not (Test-Path -LiteralPath $ServiceAccountKey)) {
      throw ('No existe ServiceAccountKeyPath: ' + $ServiceAccountKey)
    }

    $nodeCmd = Get-NodeCommand
    $token = & $nodeCmd $helper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/documents'
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
      throw 'No se pudo obtener access_token con cuenta de servicio'
    }
    return [string]$token
  }

  $rc = 'C:\Users\elrub\.clasprc.json'
  if (-not (Test-Path -LiteralPath $rc)) { throw 'No existe C:\Users\elrub\.clasprc.json' }

  $cfg = Get-Content $rc -Raw | ConvertFrom-Json
  $clientId = ''
  $clientSecret = ''
  $refreshToken = ''

  if ($cfg.tokens) {
    $tok = $cfg.tokens.$Profile
    if (-not $tok) { throw ('Token profile no encontrado: ' + $Profile) }
    $clientId = [string]$tok.client_id
    $clientSecret = [string]$tok.client_secret
    $refreshToken = [string]$tok.refresh_token
  }
  elseif ($cfg.token -and $cfg.oauth2ClientSettings) {
    $clientId = [string]$cfg.oauth2ClientSettings.clientId
    $clientSecret = [string]$cfg.oauth2ClientSettings.clientSecret
    $refreshToken = [string]$cfg.token.refresh_token
  }
  else {
    throw 'Formato de .clasprc no compatible (sin tokens ni token/oauth2ClientSettings).'
  }

  if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret) -or [string]::IsNullOrWhiteSpace($refreshToken)) {
    throw 'No se encontraron clientId/clientSecret/refresh_token validos en .clasprc.'
  }

  $resp = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
    client_id = $clientId
    client_secret = $clientSecret
    refresh_token = $refreshToken
    grant_type = 'refresh_token'
  }

  if (-not $resp.access_token) { throw 'No se pudo obtener access_token' }
  return [string]$resp.access_token
}

function Get-ApiStatusCodeFromError {
  param($ErrorRecord)
  try {
    if ($ErrorRecord -and $ErrorRecord.Exception -and $ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) {
      return [int]$ErrorRecord.Exception.Response.StatusCode.value__
    }
  } catch {}
  try {
    $txt = [string]$ErrorRecord.Exception.Message
    if ($txt -match '\b429\b') { return 429 }
    if ($txt -match '\b503\b') { return 503 }
    if ($txt -match '\b500\b') { return 500 }
    if ($txt -match '\b408\b') { return 408 }
  } catch {}
  return -1
}

function Invoke-DriveApi {
  param(
    [ValidateSet('GET','POST','PATCH','DELETE')]
    [string]$Method,
    [string]$Uri,
    [string]$Token,
    [string]$ContentType = 'application/json; charset=utf-8',
    $Body = $null
  )

  $headers = @{ Authorization = ('Bearer ' + $Token) }
  $maxRetries = 6
  $baseDelayMs = 650

  for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
    try {
      if ($Method -eq 'GET') {
        return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers -ErrorAction Stop
      }

      if ($Method -eq 'DELETE') {
        Invoke-RestMethod -Method Delete -Uri $Uri -Headers $headers -ErrorAction Stop | Out-Null
        return
      }

      if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ErrorAction Stop
      }

      if ($Body -is [byte[]]) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType $ContentType -Body $Body -ErrorAction Stop
      }

      if ($Body -is [string]) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Body)
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType $ContentType -Body $bytes -ErrorAction Stop
      }

      $json = $Body | ConvertTo-Json -Depth 40
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
      return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType $ContentType -Body $bytes -ErrorAction Stop
    }
    catch {
      $statusCode = Get-ApiStatusCodeFromError -ErrorRecord $_
      $isTransient = @(-1,408,429,500,502,503,504) -contains $statusCode
      if ($isTransient -and $attempt -lt $maxRetries) {
        $waitMs = [int]([Math]::Round($baseDelayMs * [Math]::Pow(2, $attempt))) + (Get-Random -Minimum 120 -Maximum 520)
        Start-Sleep -Milliseconds $waitMs
        continue
      }
      if ($_.Exception.Response) {
        $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
        $txt = $sr.ReadToEnd()
        $sr.Close()
        throw ('API_ERROR: ' + $Method + ' ' + $Uri + ' -> status=' + $statusCode + ' body=' + $txt)
      }
      throw
    }
  }
}

function Convert-MarkdownToDocModel {
  param([string]$Markdown)

  $builder = New-Object System.Text.StringBuilder
  $titleRanges = @()
  $headingRanges = @()
  $metaRanges = @()
  $cursor = 1

  $lines = ($Markdown -replace "`r`n", "`n") -split "`n"
  foreach ($raw in $lines) {
    $line = [string]$raw
    $kind = 'body'

    if ($line -match '^\s*#\s+(.+)$') {
      $line = $Matches[1].Trim()
      $kind = 'title'
    }
    elseif ($line -match '^\s*##\s+(.+)$') {
      $line = $Matches[1].Trim()
      $kind = 'heading'
    }
    elseif ($line -match '^\s*-\s+(.+)$') {
      $line = [string]([char]0x2022) + ' ' + $Matches[1].Trim()
    }

    [void]$builder.Append($line)
    [void]$builder.Append("`n")

    $start = $cursor
    $end = $cursor + $line.Length

    if ($line.Length -gt 0) {
      if ($kind -eq 'title') { $titleRanges += @{ start = $start; end = $end } }
      if ($kind -eq 'heading') { $headingRanges += @{ start = $start; end = $end } }
      if ($line -match '^(Version|Fecha|Empresa|Colores corporativos)\s*:') {
        $metaRanges += @{ start = $start; end = $end }
      }
    }

    $cursor = $end + 1
  }

  $text = $builder.ToString()
  if ([string]::IsNullOrWhiteSpace($text)) { $text = "Manual de uso`n" }

  return [ordered]@{
    text = $text
    titleRanges = $titleRanges
    headingRanges = $headingRanges
    metaRanges = $metaRanges
  }
}

function Add-TextStyleRequest {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$Start,
    [int]$End,
    [hashtable]$TextStyle,
    [string]$Fields
  )

  if ($End -le $Start) { return }
  $Requests.Add(@{
    updateTextStyle = @{
      range = @{ startIndex = $Start; endIndex = $End }
      textStyle = $TextStyle
      fields = $Fields
    }
  }) | Out-Null
}

function Add-ParagraphStyleRequest {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$Start,
    [int]$End,
    [hashtable]$ParagraphStyle,
    [string]$Fields
  )

  if ($End -le $Start) { return }
  $Requests.Add(@{
    updateParagraphStyle = @{
      range = @{ startIndex = $Start; endIndex = $End }
      paragraphStyle = $ParagraphStyle
      fields = $Fields
    }
  }) | Out-Null
}

function Apply-DocCorporateStyle {
  param(
    [string]$DocId,
    [string]$Token,
    [string]$MarkdownText
  )

  $model = Convert-MarkdownToDocModel -Markdown $MarkdownText
  $docRead = Invoke-DriveApi -Method GET -Uri ("https://docs.googleapis.com/v1/documents/{0}" -f $DocId) -Token $Token

  $existingEnd = 2
  if ($docRead.body -and $docRead.body.content -and $docRead.body.content.Count -gt 0) {
    $last = $docRead.body.content[$docRead.body.content.Count - 1]
    try { $existingEnd = [int]$last.endIndex } catch { $existingEnd = 2 }
  }
  if ($existingEnd -lt 2) { $existingEnd = 2 }

  $requests = New-Object System.Collections.Generic.List[object]
  $requests.Add(@{
    deleteContentRange = @{
      range = @{ startIndex = 1; endIndex = $existingEnd - 1 }
    }
  }) | Out-Null
  $requests.Add(@{
    insertText = @{
      location = @{ index = 1 }
      text = $model.text
    }
  }) | Out-Null

  $textEnd = 1 + $model.text.Length

  Add-TextStyleRequest -Requests $requests -Start 1 -End $textEnd -TextStyle @{
    weightedFontFamily = @{ fontFamily = 'Arial' }
    fontSize = @{ magnitude = 11; unit = 'PT' }
    foregroundColor = @{ color = @{ rgbColor = @{ red = 0.09; green = 0.11; blue = 0.14 } } }
  } -Fields 'weightedFontFamily,fontSize,foregroundColor'

  Add-ParagraphStyleRequest -Requests $requests -Start 1 -End $textEnd -ParagraphStyle @{
    lineSpacing = 125
    spaceBelow = @{ magnitude = 6; unit = 'PT' }
  } -Fields 'lineSpacing,spaceBelow'

  foreach ($r in $model.titleRanges) {
    Add-TextStyleRequest -Requests $requests -Start ([int]$r.start) -End ([int]$r.end) -TextStyle @{
      bold = $true
      weightedFontFamily = @{ fontFamily = 'Arial' }
      fontSize = @{ magnitude = 24; unit = 'PT' }
      foregroundColor = @{ color = @{ rgbColor = @{ red = 0.78; green = 0.07; blue = 0.13 } } }
    } -Fields 'bold,weightedFontFamily,fontSize,foregroundColor'

    Add-ParagraphStyleRequest -Requests $requests -Start ([int]$r.start) -End ([int]$r.end) -ParagraphStyle @{
      namedStyleType = 'TITLE'
      alignment = 'START'
      spaceBelow = @{ magnitude = 10; unit = 'PT' }
    } -Fields 'namedStyleType,alignment,spaceBelow'
  }

  foreach ($r in $model.headingRanges) {
    Add-TextStyleRequest -Requests $requests -Start ([int]$r.start) -End ([int]$r.end) -TextStyle @{
      bold = $true
      weightedFontFamily = @{ fontFamily = 'Arial' }
      fontSize = @{ magnitude = 14; unit = 'PT' }
      foregroundColor = @{ color = @{ rgbColor = @{ red = 0.78; green = 0.07; blue = 0.13 } } }
    } -Fields 'bold,weightedFontFamily,fontSize,foregroundColor'
  }

  foreach ($r in $model.metaRanges) {
    Add-TextStyleRequest -Requests $requests -Start ([int]$r.start) -End ([int]$r.end) -TextStyle @{
      bold = $true
      backgroundColor = @{ color = @{ rgbColor = @{ red = 0.99; green = 0.88; blue = 0.22 } } }
      foregroundColor = @{ color = @{ rgbColor = @{ red = 0.13; green = 0.14; blue = 0.16 } } }
    } -Fields 'bold,backgroundColor,foregroundColor'
  }

  Invoke-DriveApi -Method POST -Uri ("https://docs.googleapis.com/v1/documents/{0}:batchUpdate" -f $DocId) -Token $Token -Body @{ requests = $requests } | Out-Null
}

function New-GoogleDocFromText_ {
  param(
    [string]$Name,
    [string]$FolderId,
    [string]$Text,
    [string]$Token
  )

  $boundary = 'manual' + [guid]::NewGuid().ToString('N')
  $meta = @{
    name = $Name
    mimeType = 'application/vnd.google-apps.document'
    parents = @($FolderId)
  } | ConvertTo-Json -Compress

  $multipartBody = @(
    "--$boundary",
    'Content-Type: application/json; charset=UTF-8',
    '',
    $meta,
    "--$boundary",
    'Content-Type: text/plain; charset=UTF-8',
    '',
    [string]$Text,
    "--$boundary--",
    ''
  ) -join "`r`n"

  return Invoke-DriveApi -Method POST -Uri 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,mimeType,webViewLink' -Token $Token -ContentType ("multipart/related; boundary=$boundary") -Body $multipartBody
}

function Escape-Html_ {
  param([string]$Text)
  $t = [string]$Text
  $t = $t.Replace('&', '&amp;')
  $t = $t.Replace('<', '&lt;')
  $t = $t.Replace('>', '&gt;')
  return $t
}

function Encode-NonAsciiHtml_ {
  param([string]$Text)
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in ([string]$Text).ToCharArray()) {
    $code = [int][char]$ch
    if ($code -gt 127) {
      [void]$sb.Append('&#')
      [void]$sb.Append($code)
      [void]$sb.Append(';')
    }
    else {
      [void]$sb.Append($ch)
    }
  }
  return $sb.ToString()
}

function Convert-InlineMdToHtml_ {
  param([string]$Text)
  $safe = Encode-NonAsciiHtml_ -Text (Escape-Html_ -Text $Text)
  $safe = [regex]::Replace($safe, '`([^`]+)`', '<code>$1</code>')
  return $safe
}

function Convert-MarkdownToCorporateHtml_ {
  param([string]$Markdown)

  $lines = ($Markdown -replace "`r`n", "`n") -split "`n"
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<!doctype html><html><head><meta charset="utf-8">')
  [void]$sb.AppendLine('<style>')
  [void]$sb.AppendLine('@page{size:A4;margin:18mm 16mm 18mm 16mm;}')
  [void]$sb.AppendLine('body{font-family:Arial,sans-serif;color:#17202A;line-height:1.55;margin:0;padding:0;}')
  [void]$sb.AppendLine('.topbar{background:#B30000;color:#FFFFFF;font-weight:700;font-size:12pt;letter-spacing:0.3px;padding:10px 12px;border-bottom:6px solid #FFD400;margin-bottom:14px;}')
  [void]$sb.AppendLine('.card{background:#FFFFFF;border:1px solid #E5E7EB;border-radius:8px;padding:12px 14px;margin:8px 0 12px 0;}')
  [void]$sb.AppendLine('.page-break{page-break-before:always;break-before:page;}')
  [void]$sb.AppendLine('h1{color:#B30000;font-size:26px;margin:0 0 12px 0;border-bottom:4px solid #FFD400;padding-bottom:8px;}')
  [void]$sb.AppendLine('h2{color:#B30000;font-size:16px;margin:16px 0 8px 0;background:#FFF3BF;padding:7px 9px;border-left:6px solid #B30000;border-radius:2px;}')
  [void]$sb.AppendLine('p{margin:6px 0;}')
  [void]$sb.AppendLine('p.meta{font-weight:bold;background:#FFD400;padding:6px 9px;display:inline-block;margin:4px 6px 4px 0;border-radius:3px;}')
  [void]$sb.AppendLine('hr{border:none;border-top:2px solid #F3F4F6;margin:14px 0;}')
  [void]$sb.AppendLine('ul{margin:6px 0 10px 22px;} li{margin:3px 0;}')
  [void]$sb.AppendLine('code{background:#F3F4F6;border:1px solid #E5E7EB;padding:1px 4px;border-radius:3px;font-family:Consolas,monospace;}')
  [void]$sb.AppendLine('</style></head><body>')
  [void]$sb.AppendLine('<div class="topbar">ARTES B&#218;HO - MANUAL CONTABILIDAD DE DECISION</div>')
  [void]$sb.AppendLine('<div class="card">')

  $inList = $false
  $headingCount = 0
  foreach ($raw in $lines) {
    $line = [string]$raw
    if ([string]::IsNullOrWhiteSpace($line)) {
      if ($inList) { [void]$sb.AppendLine('</ul>'); $inList = $false }
      continue
    }

    if ($line -match '^\s*#\s+(.+)$') {
      if ($inList) { [void]$sb.AppendLine('</ul>'); $inList = $false }
      [void]$sb.AppendLine('<h1>' + (Convert-InlineMdToHtml_ -Text $Matches[1].Trim()) + '</h1>')
      continue
    }

    if ($line -match '^\s*##\s+(.+)$') {
      if ($inList) { [void]$sb.AppendLine('</ul>'); $inList = $false }
      $heading = $Matches[1].Trim()
      if ($headingCount -gt 0 -and $heading -match '^(PAGINA|PORTADA)\b') {
        [void]$sb.AppendLine('</div><div class="page-break"></div><div class="topbar">ARTES B&#218;HO - MANUAL CONTABILIDAD DE DECISION</div><div class="card">')
      }
      [void]$sb.AppendLine('<h2>' + (Convert-InlineMdToHtml_ -Text $heading) + '</h2>')
      $headingCount++
      continue
    }

    if ($line -match '^\s*-\s+(.+)$') {
      if (-not $inList) { [void]$sb.AppendLine('<ul>'); $inList = $true }
      [void]$sb.AppendLine('<li>' + (Convert-InlineMdToHtml_ -Text $Matches[1].Trim()) + '</li>')
      continue
    }

    if ($line -match '^(Version|Fecha|Empresa|Colores corporativos)\s*:') {
      if ($inList) { [void]$sb.AppendLine('</ul>'); $inList = $false }
      [void]$sb.AppendLine('<p class="meta">' + (Convert-InlineMdToHtml_ -Text $line.Trim()) + '</p>')
      continue
    }

    if ($line -match '^\s*\d+\.\s+(.+)$') {
      if ($inList) { [void]$sb.AppendLine('</ul>'); $inList = $false }
      [void]$sb.AppendLine('<p><strong>' + (Convert-InlineMdToHtml_ -Text $line.Trim()) + '</strong></p>')
      continue
    }

    if ($inList) { [void]$sb.AppendLine('</ul>'); $inList = $false }
    [void]$sb.AppendLine('<p>' + (Convert-InlineMdToHtml_ -Text $line.Trim()) + '</p>')
  }
  if ($inList) { [void]$sb.AppendLine('</ul>') }

  [void]$sb.AppendLine('</div>')
  [void]$sb.AppendLine('</body></html>')
  return $sb.ToString()
}

function New-GoogleDocFromHtml_ {
  param(
    [string]$Name,
    [string]$FolderId,
    [string]$Html,
    [string]$Token
  )

  $boundary = 'manual' + [guid]::NewGuid().ToString('N')
  $meta = @{
    name = $Name
    mimeType = 'application/vnd.google-apps.document'
    parents = @($FolderId)
  } | ConvertTo-Json -Compress

  $multipartBody = @(
    "--$boundary",
    'Content-Type: application/json; charset=UTF-8',
    '',
    $meta,
    "--$boundary",
    'Content-Type: text/html; charset=UTF-8',
    '',
    [string]$Html,
    "--$boundary--",
    ''
  ) -join "`r`n"

  return Invoke-DriveApi -Method POST -Uri 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,mimeType,webViewLink' -Token $Token -ContentType ("multipart/related; boundary=$boundary") -Body $multipartBody
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$manualAbs = if ([System.IO.Path]::IsPathRooted($ManualPath)) { $ManualPath } else { Join-Path $repoRoot $ManualPath }
if (-not (Test-Path -LiteralPath $manualAbs)) { throw ('No existe manual local: ' + $manualAbs) }

$codePath = Join-Path $repoRoot 'appscript\Code.js'
$version = '0.0.0'
if (Test-Path -LiteralPath $codePath) {
  $code = Get-Content -Raw $codePath
  $m = [regex]::Match($code, "version:\s*'([^']+)'")
  if ($m.Success) { $version = $m.Groups[1].Value }
}

$today = Get-Date -Format 'yyyy-MM-dd'
$baseName = ('{0}_v{1}_{2}' -f $ManualPrefix, $version, $today)
$docName = $baseName
$pdfName = $baseName + '.pdf'

$effectiveAuthMode = $AuthMode
$token = $null
$modesToTry = @($AuthMode)
if ($AuthMode -eq 'oauth') {
  $modesToTry += 'service_account'
}
else {
  $modesToTry += 'oauth'
}

$lastAuthError = $null
foreach ($modeTry in ($modesToTry | Select-Object -Unique)) {
  try {
    $token = Get-AccessToken -Profile $TokenProfile -Mode $modeTry -ServiceAccountKey $ServiceAccountKeyPath
    $effectiveAuthMode = if ($modeTry -eq $AuthMode) { $modeTry } else { ($modeTry + '_fallback') }
    break
  }
  catch {
    $lastAuthError = $_
  }
}
if ([string]::IsNullOrWhiteSpace([string]$token)) {
  if ($lastAuthError) { throw $lastAuthError }
  throw 'No se pudo obtener token valido (oauth/service_account).'
}

$fileMetaUri = "https://www.googleapis.com/drive/v3/files/{0}?fields=id,name,parents,webViewLink&supportsAllDrives=true" -f $SpreadsheetId
$fileMeta = Invoke-DriveApi -Method GET -Uri $fileMetaUri -Token $token
$folderId = $null
if ($UseManualFolderOnly -and -not [string]::IsNullOrWhiteSpace($ManualFolderId)) {
  $folderId = [string]$ManualFolderId
}
elseif ($fileMeta.parents -and $fileMeta.parents.Count -ge 1) {
  $folderId = [string]$fileMeta.parents[0]
}
elseif (-not [string]::IsNullOrWhiteSpace($ManualFolderId)) {
  $folderId = [string]$ManualFolderId
}
if ([string]::IsNullOrWhiteSpace($folderId)) { throw 'No se detecto carpeta padre del spreadsheet ni ManualFolderId de respaldo.' }

$listUri = "https://www.googleapis.com/drive/v3/files?q={0}&fields=files(id,name,mimeType,webViewLink)" -f [uri]::EscapeDataString("'$folderId' in parents and trashed=false and name contains '$ManualPrefix'")
$existing = Invoke-DriveApi -Method GET -Uri $listUri -Token $token
$deleted = @()
$deleteSkipped = @()
if ($existing.files) {
  foreach ($f in $existing.files) {
    try {
      Invoke-DriveApi -Method DELETE -Uri ("https://www.googleapis.com/drive/v3/files/{0}" -f $f.id) -Token $token
      $deleted += [string]$f.name
    }
    catch {
      $deleteSkipped += [string]$f.name
    }
  }
}

$manualText = [System.IO.File]::ReadAllText($manualAbs, [System.Text.Encoding]::UTF8)
$docStyleMode = 'corporate_html'
$docStyleWarning = ''
$doc = $null

# Prioridad: HTML corporativo con entidades Unicode para evitar simbolos rotos (Búho -> B�ho).
try {
  $html = Convert-MarkdownToCorporateHtml_ -Markdown $manualText
  $doc = New-GoogleDocFromHtml_ -Name $docName -FolderId $folderId -Html $html -Token $token
}
catch {
  $docStyleMode = 'fallback_docs_api'
  $docStyleWarning = [string]$_.Exception.Message
  try {
    $doc = Invoke-DriveApi -Method POST -Uri 'https://www.googleapis.com/drive/v3/files?fields=id,name,mimeType,webViewLink' -Token $token -Body @{
      name = $docName
      mimeType = 'application/vnd.google-apps.document'
      parents = @($folderId)
    }
    Apply-DocCorporateStyle -DocId ([string]$doc.id) -Token $token -MarkdownText $manualText
  }
  catch {
    $docStyleMode = 'fallback_plain_text'
    $docStyleWarning = $docStyleWarning + ' | docs_api_fallback_error=' + [string]$_.Exception.Message
    if ($doc -and $doc.id) {
      try {
        Invoke-DriveApi -Method DELETE -Uri ("https://www.googleapis.com/drive/v3/files/{0}" -f $doc.id) -Token $token
      } catch {}
    }
    $doc = New-GoogleDocFromText_ -Name $docName -FolderId $folderId -Text $manualText -Token $token
  }
}

$tempPdf = Join-Path ([System.IO.Path]::GetTempPath()) ('manual_artes_buho_' + [guid]::NewGuid().ToString('N') + '.pdf')
try {
  $exportUri = "https://www.googleapis.com/drive/v3/files/{0}/export?mimeType=application/pdf" -f $doc.id
  Invoke-WebRequest -Method Get -Uri $exportUri -Headers @{ Authorization = ('Bearer ' + $token) } -OutFile $tempPdf -ErrorAction Stop | Out-Null
  $pdfBytes = [System.IO.File]::ReadAllBytes($tempPdf)
}
finally {
  if (Test-Path -LiteralPath $tempPdf) {
    Remove-Item -LiteralPath $tempPdf -Force -ErrorAction SilentlyContinue
  }
}

$pdfMeta = Invoke-DriveApi -Method POST -Uri 'https://www.googleapis.com/drive/v3/files?fields=id,name,mimeType,webViewLink' -Token $token -Body @{
  name = $pdfName
  parents = @($folderId)
  mimeType = 'application/pdf'
}
Invoke-DriveApi -Method PATCH -Uri ("https://www.googleapis.com/upload/drive/v3/files/{0}?uploadType=media" -f $pdfMeta.id) -Token $token -ContentType 'application/pdf' -Body $pdfBytes | Out-Null
$pdfFinal = Invoke-DriveApi -Method GET -Uri ("https://www.googleapis.com/drive/v3/files/{0}?fields=id,name,mimeType,webViewLink" -f $pdfMeta.id) -Token $token

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  folderId = $folderId
  authMode = $effectiveAuthMode
  version = $version
  docStyleMode = $docStyleMode
  docStyleWarning = $docStyleWarning
  deletedObsolete = $deleted
  deleteSkippedByPermissions = $deleteSkipped
  doc = @{ id = $doc.id; name = $doc.name; link = $doc.webViewLink }
  pdf = @{ id = $pdfFinal.id; name = $pdfFinal.name; link = $pdfFinal.webViewLink }
  generatedAt = (Get-Date).ToString('o')
}

$reportDir = Join-Path $repoRoot 'audit\reports'
if (-not (Test-Path -LiteralPath $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$reportPath = Join-Path $reportDir ('manual_publish_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.json')
$out | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8
$out | ConvertTo-Json -Depth 8
