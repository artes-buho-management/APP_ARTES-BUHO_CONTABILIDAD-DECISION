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

function Add-ColumnWidths {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$SheetId,
    [int[]]$Widths
  )

  for ($i = 0; $i -lt $Widths.Count; $i++) {
    $Requests.Add(@{
      updateDimensionProperties = @{
        range = @{
          sheetId = $SheetId
          dimension = 'COLUMNS'
          startIndex = $i
          endIndex = $i + 1
        }
        properties = @{ pixelSize = [int]$Widths[$i] }
        fields = 'pixelSize'
      }
    }) | Out-Null
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

$token = Get-AccessToken -ServiceAccountKey $ServiceAccountKeyPath

$metaFields = 'sheets(properties(sheetId,title,index,hidden,gridProperties),charts(chartId,position))'
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

if (-not $sheetMap.ContainsKey('00_GUIA_USO')) {
  $requests.Add(@{
    addSheet = @{
      properties = @{
        title = '00_GUIA_USO'
        gridProperties = @{ rowCount = 120; columnCount = 10; hideGridlines = $true }
        tabColorStyle = @{ rgbColor = @{ red = 0.70; green = 0.00; blue = 0.00 } }
      }
    }
  }) | Out-Null
}

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
      properties = @{
        sheetId = $sid
        hidden = $hidden
        gridProperties = @{ hideGridlines = $true }
      }
      fields = 'hidden,gridProperties.hideGridlines'
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('00_PANEL')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['00_PANEL'] -Widths @(165,150,150,150,160,90,165,150,150,150,110,230)
}
if ($sheetMap.ContainsKey('01_ENTRADA')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['01_ENTRADA'] -Widths @(300,420,90,180,180,130,130,180)
}
if ($sheetMap.ContainsKey('02_TRANSACCIONES')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['02_TRANSACCIONES'] -Widths @(130,140,190,190,190,320,170,150,150,170,300)
}
if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['03_ESCENARIOS'] -Widths @(160,100,170,170,170,190,120,120,120,120,120,120)
}
if ($sheetMap.ContainsKey('05_PRESUPUESTO')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['05_PRESUPUESTO'] -Widths @(120,200,160,160,170,150,150,160,150,120)
}
if ($sheetMap.ContainsKey('06_FACTURAS')) {
  Add-ColumnWidths -Requests $requests -SheetId $sheetMap['06_FACTURAS'] -Widths @(120,120,240,110,140,120,140,120,140,130,170,120,240)
}

if ($sheetMap.ContainsKey('02_TRANSACCIONES')) {
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['02_TRANSACCIONES'] -StartRow 1 -EndRow 5000 -StartCol 7 -EndCol 8
}
if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['03_ESCENARIOS'] -StartRow 1 -EndRow 5000 -StartCol 2 -EndCol 6
}
if ($sheetMap.ContainsKey('05_PRESUPUESTO')) {
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['05_PRESUPUESTO'] -StartRow 1 -EndRow 5000 -StartCol 2 -EndCol 9
}
if ($sheetMap.ContainsKey('06_FACTURAS')) {
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['06_FACTURAS'] -StartRow 1 -EndRow 5000 -StartCol 4 -EndCol 7
}
if ($sheetMap.ContainsKey('07_LINEAS_NEGOCIO')) {
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['07_LINEAS_NEGOCIO'] -StartRow 1 -EndRow 5000 -StartCol 4 -EndCol 5
}
if ($sheetMap.ContainsKey('01_ENTRADA')) {
  Add-CurrencyFormat -Requests $requests -SheetId $sheetMap['01_ENTRADA'] -StartRow 10 -EndRow 11 -StartCol 1 -EndCol 2
}

$accountRule = @{
  condition = @{
    type = 'ONE_OF_LIST'
    values = @(
      @{ userEnteredValue = 'BBVA' },
      @{ userEnteredValue = 'Caixa' },
      @{ userEnteredValue = 'Santander' },
      @{ userEnteredValue = 'Stripe' },
      @{ userEnteredValue = 'Caja' }
    )
  }
  strict = $true
  showCustomUi = $true
}

$sourceRule = @{
  condition = @{
    type = 'ONE_OF_LIST'
    values = @(
      @{ userEnteredValue = 'Banco' },
      @{ userEnteredValue = 'Tarjeta' },
      @{ userEnteredValue = 'Transferencia' },
      @{ userEnteredValue = 'Efectivo' },
      @{ userEnteredValue = 'Manual' },
      @{ userEnteredValue = 'Resumen mensual' }
    )
  }
  strict = $true
  showCustomUi = $true
}

if ($sheetMap.ContainsKey('01_ENTRADA')) {
  $sid = $sheetMap['01_ENTRADA']
  $requests.Add(@{ setDataValidation = @{ range = @{ sheetId = $sid; startRowIndex = 9; endRowIndex = 10; startColumnIndex = 1; endColumnIndex = 2 }; rule = $accountRule } }) | Out-Null
  $requests.Add(@{ setDataValidation = @{ range = @{ sheetId = $sid; startRowIndex = 12; endRowIndex = 13; startColumnIndex = 1; endColumnIndex = 2 }; rule = $sourceRule } }) | Out-Null
}
if ($sheetMap.ContainsKey('02_TRANSACCIONES')) {
  $sid = $sheetMap['02_TRANSACCIONES']
  $requests.Add(@{ setDataValidation = @{ range = @{ sheetId = $sid; startRowIndex = 1; endRowIndex = 5000; startColumnIndex = 6; endColumnIndex = 7 }; rule = $accountRule } }) | Out-Null
  $requests.Add(@{ setDataValidation = @{ range = @{ sheetId = $sid; startRowIndex = 1; endRowIndex = 5000; startColumnIndex = 9; endColumnIndex = 10 }; rule = $sourceRule } }) | Out-Null
}

$requests.Add(@{ findReplace = @{ find = 'Ticket Buo'; replacement = 'Tickets Buho'; allSheets = $true; matchCase = $false } }) | Out-Null
$requests.Add(@{ findReplace = @{ find = 'Ticket Buho'; replacement = 'Tickets Buho'; allSheets = $true; matchCase = $false } }) | Out-Null
$requests.Add(@{ findReplace = @{ find = 'CAIXA'; replacement = 'Caixa'; allSheets = $true; matchCase = $true } }) | Out-Null

if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  $sidScenario = $sheetMap['03_ESCENARIOS']
  $scenarioSheet = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sidScenario } | Select-Object -First 1
  if ($scenarioSheet -and $scenarioSheet.charts) {
    foreach ($ch in $scenarioSheet.charts) {
      $requests.Add(@{
        updateEmbeddedObjectPosition = @{
          objectId = [int]$ch.chartId
          newPosition = @{
            overlayPosition = @{
              anchorCell = @{
                sheetId = $sidScenario
                rowIndex = 39
                columnIndex = 0
              }
              offsetXPixels = 0
              offsetYPixels = 0
            }
          }
          fields = '*'
        }
      }) | Out-Null
    }
  }
}

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null

$valueData = @(
  @{ range = '02_TRANSACCIONES!A1:K1'; values = @(,@('Fecha','Tipo','Linea de negocio','Categoria','Subcategoria','Concepto','Cuenta','Importe (€)','Estado','Origen','Nota')) },
  @{ range = '03_ESCENARIOS!A1:J1'; values = @(,@('Escenario','Linea de negocio','Mes','Ingresos (€)','Gastos (€)','Resultado (€)','Caja acumulada (€)','Punto de equilibrio (€)','Brecha (€)','Riesgo')) },
  @{ range = '04_AUDITORIA!A1:E1'; values = @(,@('Fecha','Nivel','Indicador','Descripcion','Valor')) },
  @{ range = '07_LINEAS_NEGOCIO!A1:H1'; values = @(,@('Linea de negocio','Clasificacion','Foco','Prioridad','Objetivo mensual (€)','Responsable','Estado','Nota')) },
  @{ range = '08_CATALOGO_CATEGORIAS!A1:D1'; values = @(,@('Linea de negocio','Categoria','Subcategoria','Estado')) },
  @{ range = '98_LOG!A1:D1'; values = @(,@('Fecha','Nivel','Mensaje','Meta')) },
  @{ range = '99_CONFIG!A1:C1'; values = @(,@('Parametro','Valor','Descripcion')) },
  @{ range = '00_GUIA_USO!A1:F7'; values = @(
    @('GUIA RAPIDA - ARTES BUHO CONTABILIDAD','','','','',''),
    @('Usa solo celdas amarillas en 01_ENTRADA','','','','',''),
    @('','','','','',''),
    @('Paso','Que hacer','Resultado esperado','','Semaforo','Significado'),
    @('1','Ir a 01_ENTRADA','Rellenar campos y guardar','','VERDE','Todo bajo control'),
    @('2','Revisar 00_PANEL','Ver KPIs y recomendaciones IA','','AMARILLO','Requiere seguimiento'),
    @('3','Revisar 05_PRESUPUESTO y 06_FACTURAS','Control mensual de caja','','ROJO','Accion inmediata')
  ) }
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









