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

function Add-ColumnWidths {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$SheetId,
    [int[]]$Widths
  )

  for ($i = 0; $i -lt $Widths.Count; $i++) {
    $Requests.Add(@{
      updateDimensionProperties = @{
        range = @{ sheetId = $SheetId; dimension = 'COLUMNS'; startIndex = $i; endIndex = $i + 1 }
        properties = @{ pixelSize = [int]$Widths[$i] }
        fields = 'pixelSize'
      }
    }) | Out-Null
  }
}

function Add-RowHeightBlock {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$SheetId,
    [int]$StartIndex,
    [int]$EndIndex,
    [int]$PixelSize
  )

  $Requests.Add(@{
    updateDimensionProperties = @{
      range = @{ sheetId = $SheetId; dimension = 'ROWS'; startIndex = $StartIndex; endIndex = $EndIndex }
      properties = @{ pixelSize = [int]$PixelSize }
      fields = 'pixelSize'
    }
  }) | Out-Null
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
      range = @{ sheetId = $SheetId; startRowIndex = $StartRow; endRowIndex = $EndRow; startColumnIndex = $StartCol; endColumnIndex = $EndCol }
      cell = @{ userEnteredFormat = @{ numberFormat = @{ type = 'NUMBER'; pattern = '#,##0.00 [$€-es-ES]' } } }
      fields = 'userEnteredFormat.numberFormat'
    }
  }) | Out-Null
}

function Add-FrozenRows {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$SheetId,
    [int]$FrozenRows
  )

  $Requests.Add(@{
    updateSheetProperties = @{
      properties = @{ sheetId = $SheetId; gridProperties = @{ frozenRowCount = $FrozenRows } }
      fields = 'gridProperties.frozenRowCount'
    }
  }) | Out-Null
}

$token = Get-AccessToken -ServiceAccountKey $ServiceAccountKeyPath
$metaFields = 'sheets(properties(sheetId,title,hidden),charts(chartId,position))'
$metaUri = "https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}"
$meta = Invoke-GApi -Method GET -Uri $metaUri -Token $token

$sheetMap = @{}
foreach ($s in $meta.sheets) {
  $sheetMap[[string]$s.properties.title] = [int]$s.properties.sheetId
}

$requests = New-Object 'System.Collections.Generic.List[object]'

$requests.Add(@{
  updateSpreadsheetProperties = @{
    properties = @{ locale = 'es_ES'; timeZone = 'Europe/Madrid' }
    fields = 'locale,timeZone'
  }
}) | Out-Null

$coreVisible = @('00_PANEL','00_GUIA_USO','01_ENTRADA','02_TRANSACCIONES','03_ESCENARIOS','05_PRESUPUESTO','06_FACTURAS')
$technicalHidden = @('04_AUDITORIA','98_LOG','99_CONFIG','Auditoria_1h','07_LINEAS_NEGOCIO','08_CATALOGO_CATEGORIAS')

foreach ($s in $meta.sheets) {
  $title = [string]$s.properties.title
  $sid = [int]$s.properties.sheetId

  $hidden = $false
  if ($technicalHidden -contains $title) { $hidden = $true }
  if ($coreVisible -contains $title) { $hidden = $false }

  $requests.Add(@{
    updateSheetProperties = @{
      properties = @{ sheetId = $sid; hidden = $hidden; gridProperties = @{ hideGridlines = $true } }
      fields = 'hidden,gridProperties.hideGridlines'
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('00_PANEL')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['00_PANEL'] -Widths @(150,150,150,150,150,150,150,150,150,150,150,180)
  Add-RowHeightBlock -Requests $requests -SheetId $sheetMap['00_PANEL'] -StartIndex 2 -EndIndex 90 -PixelSize 28
  Add-RowHeightBlock -Requests $requests -SheetId $sheetMap['00_PANEL'] -StartIndex 90 -EndIndex 170 -PixelSize 24
  Add-FrozenRows -Requests $requests -SheetId $sheetMap['00_PANEL'] -FrozenRows 2
}
if ($sheetMap.ContainsKey('01_ENTRADA')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['01_ENTRADA'] -Widths @(320,380,90,170,170,140,140,180)
  Add-RowHeightBlock -Requests $requests -SheetId $sheetMap['01_ENTRADA'] -StartIndex 3 -EndIndex 16 -PixelSize 34
  Add-FrozenRows -Requests $requests -SheetId $sheetMap['01_ENTRADA'] -FrozenRows 2
}
if ($sheetMap.ContainsKey('02_TRANSACCIONES')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['02_TRANSACCIONES'] -Widths @(130,140,190,190,190,320,170,150,150,170,300)
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['02_TRANSACCIONES'] -StartRow 1 -EndRow 5000 -StartCol 7 -EndCol 8
  Add-FrozenRows -Requests $requests -SheetId $sheetMap['02_TRANSACCIONES'] -FrozenRows 1
}
if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['03_ESCENARIOS'] -Widths @(140,180,90,150,150,150,160,150,150,150,170,170)
  Add-RowHeightBlock -Requests $requests -SheetId $sheetMap['03_ESCENARIOS'] -StartIndex 1 -EndIndex 220 -PixelSize 26
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['03_ESCENARIOS'] -StartRow 1 -EndRow 5000 -StartCol 3 -EndCol 9
  Add-FrozenRows -Requests $requests -SheetId $sheetMap['03_ESCENARIOS'] -FrozenRows 1
}
if ($sheetMap.ContainsKey('05_PRESUPUESTO')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['05_PRESUPUESTO'] -Widths @(120,200,160,160,170,150,150,160,150,120)
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['05_PRESUPUESTO'] -StartRow 1 -EndRow 5000 -StartCol 2 -EndCol 9
  Add-FrozenRows -Requests $requests -SheetId $sheetMap['05_PRESUPUESTO'] -FrozenRows 1
}
if ($sheetMap.ContainsKey('06_FACTURAS')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['06_FACTURAS'] -Widths @(120,120,240,110,140,120,140,120,140,130,170,120,240)
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['06_FACTURAS'] -StartRow 1 -EndRow 5000 -StartCol 4 -EndCol 7
  Add-FrozenRows -Requests $requests -SheetId $sheetMap['06_FACTURAS'] -FrozenRows 1
}

$requests.Add(@{ findReplace = @{ find = 'Ticket Buo'; replacement = 'Ticket Buho'; allSheets = $true; matchCase = $false } }) | Out-Null
$requests.Add(@{ findReplace = @{ find = 'Tickets Buo'; replacement = 'Ticket Buho'; allSheets = $true; matchCase = $false } }) | Out-Null
$requests.Add(@{ findReplace = @{ find = 'Tickets Buho'; replacement = 'Ticket Buho'; allSheets = $true; matchCase = $false } }) | Out-Null
$requests.Add(@{ findReplace = @{ find = 'CAIXA'; replacement = 'Caixa'; allSheets = $true; matchCase = $true } }) | Out-Null

if ($sheetMap.ContainsKey('00_PANEL')) {
  $sidPanel = $sheetMap['00_PANEL']
  $panelSheet = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sidPanel } | Select-Object -First 1
  if ($panelSheet -and $panelSheet.charts) {
    $targets = @(
      @{ row = 30; col = 0 },
      @{ row = 30; col = 6 },
      @{ row = 46; col = 6 }
    )
    for ($i = 0; $i -lt $panelSheet.charts.Count; $i++) {
      $t = $targets[[Math]::Min($i, $targets.Count - 1)]
      $requests.Add(@{
        updateEmbeddedObjectPosition = @{
          objectId = [int]$panelSheet.charts[$i].chartId
          newPosition = @{ overlayPosition = @{ anchorCell = @{ sheetId = $sidPanel; rowIndex = [int]$t.row; columnIndex = [int]$t.col }; offsetXPixels = 0; offsetYPixels = 0 } }
          fields = '*'
        }
      }) | Out-Null
    }
  }
}

if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  $sidScenario = $sheetMap['03_ESCENARIOS']
  $scenarioSheet = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sidScenario } | Select-Object -First 1
  if ($scenarioSheet -and $scenarioSheet.charts) {
    $targets = @(
      @{ row = 2; col = 9 },
      @{ row = 24; col = 9 },
      @{ row = 45; col = 9 }
    )
    for ($i = 0; $i -lt $scenarioSheet.charts.Count; $i++) {
      $t = $targets[[Math]::Min($i, $targets.Count - 1)]
      $requests.Add(@{
        updateEmbeddedObjectPosition = @{
          objectId = [int]$scenarioSheet.charts[$i].chartId
          newPosition = @{ overlayPosition = @{ anchorCell = @{ sheetId = $sidScenario; rowIndex = [int]$t.row; columnIndex = [int]$t.col }; offsetXPixels = 0; offsetYPixels = 0 } }
          fields = '*'
        }
      }) | Out-Null
    }
  }
}

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null

$valueData = @(
  @{ range = '03_ESCENARIOS!A1:J1'; values = @(,@('Escenario','Linea de negocio','Mes','Ingresos (€)','Gastos (€)','Resultado (€)','Caja acumulada (€)','Punto de equilibrio (€)','Brecha (€)','Riesgo')) }
)

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{
  valueInputOption = 'USER_ENTERED'
  data = $valueData
} | Out-Null

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  appliedRequests = $requests.Count
  updatedRanges = $valueData.Count
  updatedAt = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 6



