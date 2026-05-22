param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
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

  $token = & $nodeCmd $helper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
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

    $json = if ($null -eq $Body) { '{}' } else { $Body | ConvertTo-Json -Depth 80 }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Method Post -Uri $Uri -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bytes -ErrorAction Stop
  }
  catch {
    if ($_.Exception.Response) {
      $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
      $txt = $sr.ReadToEnd()
      $sr.Close()
      throw ('API_ERROR: ' + $Uri + ' -> ' + $txt)
    }
    throw
  }
}

function Add-ProtectedRangeRequest {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$SheetId,
    [string]$Description,
    [int]$StartRow,
    [int]$EndRow,
    [int]$StartCol,
    [int]$EndCol,
    [bool]$WarningOnly,
    [string[]]$Editors,
    $UnprotectedRanges = $null
  )

  $rangeBody = $null
  if ($UnprotectedRanges) {
    $rangeBody = @{ sheetId = $SheetId }
  } else {
    $rangeBody = @{
      sheetId = $SheetId
      startRowIndex = $StartRow
      endRowIndex = $EndRow
      startColumnIndex = $StartCol
      endColumnIndex = $EndCol
    }
  }

  $payload = @{
    addProtectedRange = @{
      protectedRange = @{
        description = $Description
        warningOnly = $WarningOnly
        range = $rangeBody
      }
    }
  }

  if ((-not $WarningOnly) -and $Editors -and $Editors.Count -gt 0) {
    $payload.addProtectedRange.protectedRange.editors = @{ users = $Editors }
  }

  if ($UnprotectedRanges) {
    $payload.addProtectedRange.protectedRange.unprotectedRanges = $UnprotectedRanges
  }

  $Requests.Add($payload) | Out-Null
}

$token = Get-AccessToken -ServiceAccountKey $ServiceAccountKeyPath

$keyJson = Get-Content -LiteralPath $ServiceAccountKeyPath -Raw | ConvertFrom-Json
$serviceAccountEmail = [string]$keyJson.client_email

$metaFields = 'sheets(properties(sheetId,title,hidden),protectedRanges(protectedRangeId,description,warningOnly,editors(users,groups)))'
$metaUri = "https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}"
$meta = Invoke-GApi -Method GET -Uri $metaUri -Token $token

$sheetMap = @{}
$allEditors = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($s in $meta.sheets) {
  $sheetMap[[string]$s.properties.title] = [int]$s.properties.sheetId

  if ($s.protectedRanges) {
    foreach ($pr in $s.protectedRanges) {
      if ($pr.editors -and $pr.editors.users) {
        foreach ($u in $pr.editors.users) {
          if (-not [string]::IsNullOrWhiteSpace([string]$u)) {
            [void]$allEditors.Add([string]$u)
          }
        }
      }
    }
  }
}

if (-not [string]::IsNullOrWhiteSpace($serviceAccountEmail)) {
  [void]$allEditors.Add($serviceAccountEmail)
}

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
foreach ($e in $seedEditors) { [void]$allEditors.Add($e) }

$editors = @($allEditors)

$requests = New-Object 'System.Collections.Generic.List[object]'

# Limpiar protecciones anteriores para dejar un modelo unico y robusto.
$replaceDescriptions = @(
  'PANEL_BLOQUEADO_SOLO_VISUALIZACION',
  'ENTRADA_USUARIO_EDITABLE_CON_AVISO',
  'ESCENARIOS_BLOQUEADO_SOLO_VISUALIZACION',
  'AUDITORIA_BLOQUEADA_SOLO_VISUALIZACION',
  'CONFIG_BLOQUEADA_SOLO_VISUALIZACION',
  'LINEAS_NEGOCIO_EDITABLE_CON_AVISO',
  'CATALOGO_CATEGORIAS_EDITABLE_CON_AVISO',
  'OPTIMIZACION_1H_PRESUPUESTO_AVISO',
  'OPTIMIZACION_1H_FACTURAS_AVISO'
)

foreach ($s in $meta.sheets) {
  if ($s.protectedRanges) {
    foreach ($pr in $s.protectedRanges) {
      $desc = [string]$pr.description
      if (($replaceDescriptions -contains $desc) -or $desc.StartsWith('LOCKDOWN_SIGUIENTE_PASO_')) {
        $requests.Add(@{ deleteProtectedRange = @{ protectedRangeId = [int]$pr.protectedRangeId } }) | Out-Null
      }
    }
  }
}

# Bloqueos por hoja (solo entradas editables donde toca).
if ($sheetMap.ContainsKey('00_PANEL')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['00_PANEL'] -Description 'LOCKDOWN_SIGUIENTE_PASO_PANEL' -StartRow 0 -EndRow 2000 -StartCol 0 -EndCol 30 -WarningOnly $true -Editors $editors
}

if ($sheetMap.ContainsKey('00_GUIA_USO')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['00_GUIA_USO'] -Description 'LOCKDOWN_SIGUIENTE_PASO_GUIA' -StartRow 0 -EndRow 2000 -StartCol 0 -EndCol 30 -WarningOnly $true -Editors $editors
}

if ($sheetMap.ContainsKey('01_ENTRADA')) {
  $unprotected = @(
    @{ sheetId = $sheetMap['01_ENTRADA']; startRowIndex = 3; endRowIndex = 11; startColumnIndex = 1; endColumnIndex = 2 }
  )
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['01_ENTRADA'] -Description 'LOCKDOWN_SIGUIENTE_PASO_ENTRADA' -StartRow 0 -EndRow 500 -StartCol 0 -EndCol 8 -WarningOnly $true -Editors $editors -UnprotectedRanges $unprotected
}

if ($sheetMap.ContainsKey('02_TRANSACCIONES')) {
  $unprotected = @(
    @{ sheetId = $sheetMap['02_TRANSACCIONES']; startRowIndex = 1; endRowIndex = 5000; startColumnIndex = 0; endColumnIndex = 11 }
  )
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['02_TRANSACCIONES'] -Description 'LOCKDOWN_SIGUIENTE_PASO_TRANSACCIONES' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 11 -WarningOnly $true -Editors $editors -UnprotectedRanges $unprotected
}

if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['03_ESCENARIOS'] -Description 'LOCKDOWN_SIGUIENTE_PASO_ESCENARIOS' -StartRow 0 -EndRow 2000 -StartCol 0 -EndCol 30 -WarningOnly $true -Editors $editors
}

if ($sheetMap.ContainsKey('05_PRESUPUESTO')) {
  $unprotected = @(
    @{ sheetId = $sheetMap['05_PRESUPUESTO']; startRowIndex = 1; endRowIndex = 5000; startColumnIndex = 1; endColumnIndex = 4 }
  )
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['05_PRESUPUESTO'] -Description 'LOCKDOWN_SIGUIENTE_PASO_PRESUPUESTO' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors -UnprotectedRanges $unprotected
}

if ($sheetMap.ContainsKey('06_FACTURAS')) {
  $unprotected = @(
    @{ sheetId = $sheetMap['06_FACTURAS']; startRowIndex = 1; endRowIndex = 5000; startColumnIndex = 0; endColumnIndex = 13 }
  )
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['06_FACTURAS'] -Description 'LOCKDOWN_SIGUIENTE_PASO_FACTURAS' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors -UnprotectedRanges $unprotected
}

if ($sheetMap.ContainsKey('04_AUDITORIA')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['04_AUDITORIA'] -Description 'LOCKDOWN_SIGUIENTE_PASO_AUDITORIA' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors
}
if ($sheetMap.ContainsKey('98_LOG')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['98_LOG'] -Description 'LOCKDOWN_SIGUIENTE_PASO_LOG' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors
}
if ($sheetMap.ContainsKey('99_CONFIG')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['99_CONFIG'] -Description 'LOCKDOWN_SIGUIENTE_PASO_CONFIG' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors
}
if ($sheetMap.ContainsKey('07_LINEAS_NEGOCIO')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['07_LINEAS_NEGOCIO'] -Description 'LOCKDOWN_SIGUIENTE_PASO_LINEAS' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors
}
if ($sheetMap.ContainsKey('08_CATALOGO_CATEGORIAS')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['08_CATALOGO_CATEGORIAS'] -Description 'LOCKDOWN_SIGUIENTE_PASO_CATALOGO' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors
}
if ($sheetMap.ContainsKey('Auditoria_1h')) {
  Add-ProtectedRangeRequest -Requests $requests -SheetId $sheetMap['Auditoria_1h'] -Description 'LOCKDOWN_SIGUIENTE_PASO_AUDITORIA_1H' -StartRow 0 -EndRow 5000 -StartCol 0 -EndCol 20 -WarningOnly $true -Editors $editors
}

if ($requests.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null
}

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  appliedRequests = $requests.Count
  editors = $editors
  lockedAt = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 6



