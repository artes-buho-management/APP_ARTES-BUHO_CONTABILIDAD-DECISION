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

    $json = if ($null -eq $Body) { '{}' } else { $Body | ConvertTo-Json -Depth 60 }
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

function Add-CurrencyFormat {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$SheetId,
    [int]$StartRow,
    [int]$EndRow,
    [int]$StartCol,
    [int]$EndCol
  )

  $Requests.Add(@{
    repeatCell = @{
      range = @{
        sheetId = $SheetId
        startRowIndex = $StartRow
        endRowIndex = $EndRow
        startColumnIndex = $StartCol
        endColumnIndex = $EndCol
      }
      cell = @{
        userEnteredFormat = @{
          numberFormat = @{ type = 'NUMBER'; pattern = '#,##0.00 [$€-es-ES]' }
        }
      }
      fields = 'userEnteredFormat.numberFormat'
    }
  }) | Out-Null
}

function Add-SemaforoRule {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [hashtable]$Range,
    [string]$Text,
    [double]$R,
    [double]$G,
    [double]$B,
    [double]$TR,
    [double]$TG,
    [double]$TB
  )

  $Requests.Add(@{
    addConditionalFormatRule = @{
      rule = @{
        ranges = @($Range)
        booleanRule = @{
          condition = @{ type = 'TEXT_CONTAINS'; values = @(@{ userEnteredValue = $Text }) }
          format = @{
            backgroundColor = @{ red = $R; green = $G; blue = $B }
            textFormat = @{ bold = $true; foregroundColor = @{ red = $TR; green = $TG; blue = $TB } }
          }
        }
      }
      index = 0
    }
  }) | Out-Null
}

$token = Get-AccessToken -ServiceAccountKey $ServiceAccountKeyPath

$metaFields = 'sheets(properties(sheetId,title),conditionalFormats,protectedRanges(protectedRangeId,description,warningOnly,range))'
$metaUri = "https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}"
$meta = Invoke-GApi -Method GET -Uri $metaUri -Token $token

$sheetMap = @{}
foreach ($s in $meta.sheets) {
  $sheetMap[[string]$s.properties.title] = [int]$s.properties.sheetId
}

$requests = New-Object 'System.Collections.Generic.List[object]'

# Limpieza de reglas condicionales en panel/presupuesto para evitar duplicados.
foreach ($s in $meta.sheets) {
  $title = [string]$s.properties.title
  if ($title -eq '00_PANEL' -or $title -eq '05_PRESUPUESTO') {
    if ($s.conditionalFormats) {
      for ($i = $s.conditionalFormats.Count - 1; $i -ge 0; $i--) {
        $requests.Add(@{
          deleteConditionalFormatRule = @{
            sheetId = [int]$s.properties.sheetId
            index = [int]$i
          }
        }) | Out-Null
      }
    }
  }
}

# Limpieza de protecciones previas de esta optimizacion.
foreach ($s in $meta.sheets) {
  if ($s.protectedRanges) {
    foreach ($pr in $s.protectedRanges) {
      $desc = [string]$pr.description
      if ($desc.StartsWith('OPTIMIZACION_1H_')) {
        $requests.Add(@{ deleteProtectedRange = @{ protectedRangeId = [int]$pr.protectedRangeId } }) | Out-Null
      }
    }
  }
}

if ($sheetMap.ContainsKey('00_PANEL')) {
  $panelId = [int]$sheetMap['00_PANEL']

  Add-CurrencyFormat -Requests $requests -SheetId $panelId -StartRow 3 -EndRow 10 -StartCol 1 -EndCol 2
  Add-CurrencyFormat -Requests $requests -SheetId $panelId -StartRow 13 -EndRow 45 -StartCol 1 -EndCol 5
  Add-CurrencyFormat -Requests $requests -SheetId $panelId -StartRow 64 -EndRow 72 -StartCol 7 -EndCol 8
  Add-CurrencyFormat -Requests $requests -SheetId $panelId -StartRow 73 -EndRow 78 -StartCol 1 -EndCol 2
  Add-CurrencyFormat -Requests $requests -SheetId $panelId -StartRow 74 -EndRow 75 -StartCol 3 -EndCol 6

  $rangeAlertaPanel = @{ sheetId = $panelId; startRowIndex = 73; endRowIndex = 78; startColumnIndex = 6; endColumnIndex = 7 }
  $rangeRiesgoPanel = @{ sheetId = $panelId; startRowIndex = 73; endRowIndex = 78; startColumnIndex = 1; endColumnIndex = 2 }

  Add-SemaforoRule -Requests $requests -Range $rangeAlertaPanel -Text 'ALTA' -R 0.89 -G 0.27 -B 0.24 -TR 1 -TG 1 -TB 1
  Add-SemaforoRule -Requests $requests -Range $rangeAlertaPanel -Text 'MEDIA' -R 0.99 -G 0.91 -B 0.55 -TR 0.20 -TG 0.20 -TB 0.20
  Add-SemaforoRule -Requests $requests -Range $rangeAlertaPanel -Text 'CONTROLADA' -R 0.56 -G 0.84 -B 0.63 -TR 0.09 -TG 0.29 -TB 0.14

  Add-SemaforoRule -Requests $requests -Range $rangeRiesgoPanel -Text 'ALTO' -R 0.89 -G 0.27 -B 0.24 -TR 1 -TG 1 -TB 1
  Add-SemaforoRule -Requests $requests -Range $rangeRiesgoPanel -Text 'MEDIO' -R 0.99 -G 0.91 -B 0.55 -TR 0.20 -TG 0.20 -TB 0.20
  Add-SemaforoRule -Requests $requests -Range $rangeRiesgoPanel -Text 'CONTROLADO' -R 0.56 -G 0.84 -B 0.63 -TR 0.09 -TG 0.29 -TB 0.14
}

if ($sheetMap.ContainsKey('05_PRESUPUESTO')) {
  $budgetId = [int]$sheetMap['05_PRESUPUESTO']
  $rangeBudgetAlert = @{ sheetId = $budgetId; startRowIndex = 1; endRowIndex = 5000; startColumnIndex = 9; endColumnIndex = 10 }

  Add-SemaforoRule -Requests $requests -Range $rangeBudgetAlert -Text 'ALTA' -R 0.89 -G 0.27 -B 0.24 -TR 1 -TG 1 -TB 1
  Add-SemaforoRule -Requests $requests -Range $rangeBudgetAlert -Text 'MEDIA' -R 0.99 -G 0.91 -B 0.55 -TR 0.20 -TG 0.20 -TB 0.20
  Add-SemaforoRule -Requests $requests -Range $rangeBudgetAlert -Text 'CONTROLADA' -R 0.56 -G 0.84 -B 0.63 -TR 0.09 -TG 0.29 -TB 0.14

  $requests.Add(@{
    addProtectedRange = @{
      protectedRange = @{
        description = 'OPTIMIZACION_1H_PRESUPUESTO_AVISO'
        warningOnly = $true
        range = @{ sheetId = $budgetId; startRowIndex = 0; endRowIndex = 5000; startColumnIndex = 0; endColumnIndex = 20 }
      }
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('06_FACTURAS')) {
  $invoiceId = [int]$sheetMap['06_FACTURAS']
  $requests.Add(@{
    addProtectedRange = @{
      protectedRange = @{
        description = 'OPTIMIZACION_1H_FACTURAS_AVISO'
        warningOnly = $true
        range = @{ sheetId = $invoiceId; startRowIndex = 0; endRowIndex = 5000; startColumnIndex = 0; endColumnIndex = 30 }
      }
    }
  }) | Out-Null
}

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  appliedRequests = $requests.Count
  optimizedAt = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 6


