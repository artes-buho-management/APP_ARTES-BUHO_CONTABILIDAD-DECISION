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

function Add-RowHeight {
  param(
    [System.Collections.Generic.List[object]]$Requests,
    [int]$SheetId,
    [int]$Start,
    [int]$End,
    [int]$Size
  )

  $Requests.Add(@{
    updateDimensionProperties = @{
      range = @{ sheetId = $SheetId; dimension = 'ROWS'; startIndex = $Start; endIndex = $End }
      properties = @{ pixelSize = [int]$Size }
      fields = 'pixelSize'
    }
  }) | Out-Null
}

$token = Get-AccessToken -ServiceAccountKey $ServiceAccountKeyPath
$metaFields = 'sheets(properties(sheetId,title,hidden,gridProperties),charts(chartId,position))'
$metaUri = "https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}"
$meta = Invoke-GApi -Method GET -Uri $metaUri -Token $token

$sheetMap = @{}
foreach ($s in $meta.sheets) {
  $sheetMap[[string]$s.properties.title] = [int]$s.properties.sheetId
}

$req = New-Object 'System.Collections.Generic.List[object]'

$req.Add(@{
  updateSpreadsheetProperties = @{
    properties = @{ locale = 'es_ES'; timeZone = 'Europe/Madrid' }
    fields = 'locale,timeZone'
  }
}) | Out-Null

$visible = @('00_PANEL','00_GUIA_USO','01_ENTRADA','02_TRANSACCIONES','03_ESCENARIOS','05_PRESUPUESTO','06_FACTURAS')
$hidden = @('04_AUDITORIA','98_LOG','99_CONFIG','Auditoria_1h','07_LINEAS_NEGOCIO','08_CATALOGO_CATEGORIAS')

foreach ($s in $meta.sheets) {
  $title = [string]$s.properties.title
  $sid = [int]$s.properties.sheetId

  $h = $false
  if ($hidden -contains $title) { $h = $true }
  if ($visible -contains $title) { $h = $false }

  $req.Add(@{
    updateSheetProperties = @{
      properties = @{ sheetId = $sid; hidden = $h; gridProperties = @{ hideGridlines = $true } }
      fields = 'hidden,gridProperties.hideGridlines'
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('00_PANEL')) {
  $sid = $sheetMap['00_PANEL']
  Add-ColumnWidths -Requests $req -SheetId $sid -Widths @(132,132,132,132,132,132,132,132,132,132,132,168)
  Add-RowHeight -Requests $req -SheetId $sid -Start 0 -End 1 -Size 46
  Add-RowHeight -Requests $req -SheetId $sid -Start 1 -End 2 -Size 32
  Add-RowHeight -Requests $req -SheetId $sid -Start 2 -End 70 -Size 24
  Add-RowHeight -Requests $req -SheetId $sid -Start 70 -End 100 -Size 22
  Add-RowHeight -Requests $req -SheetId $sid -Start 10 -End 11 -Size 30

  $req.Add(@{
    updateSheetProperties = @{
      properties = @{ sheetId = $sid; gridProperties = @{ frozenRowCount = 2; rowCount = 100; columnCount = 12 } }
      fields = 'gridProperties.frozenRowCount,gridProperties.rowCount,gridProperties.columnCount'
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('01_ENTRADA')) {
  $sid = $sheetMap['01_ENTRADA']
  Add-ColumnWidths -Requests $req -SheetId $sid -Widths @(260,320,26,170,170,170,170,170)
  Add-RowHeight -Requests $req -SheetId $sid -Start 0 -End 1 -Size 46
  Add-RowHeight -Requests $req -SheetId $sid -Start 1 -End 2 -Size 34
  Add-RowHeight -Requests $req -SheetId $sid -Start 3 -End 20 -Size 32
  $req.Add(@{
    updateSheetProperties = @{
      properties = @{ sheetId = $sid; gridProperties = @{ frozenRowCount = 2; rowCount = 60; columnCount = 8 } }
      fields = 'gridProperties.frozenRowCount,gridProperties.rowCount,gridProperties.columnCount'
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  $sid = $sheetMap['03_ESCENARIOS']
  Add-ColumnWidths -Requests $req -SheetId $sid -Widths @(120,170,86,132,132,132,150,120,140,140,140,170)
  Add-RowHeight -Requests $req -SheetId $sid -Start 0 -End 2 -Size 30
  Add-RowHeight -Requests $req -SheetId $sid -Start 3 -End 200 -Size 24
  $req.Add(@{
    updateSheetProperties = @{
      properties = @{ sheetId = $sid; gridProperties = @{ frozenRowCount = 4; rowCount = 220; columnCount = 16 } }
      fields = 'gridProperties.frozenRowCount,gridProperties.rowCount,gridProperties.columnCount'
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('00_GUIA_USO')) {
  $sid = $sheetMap['00_GUIA_USO']
  Add-ColumnWidths -Requests $req -SheetId $sid -Widths @(90,170,220,200,100,170)
  Add-RowHeight -Requests $req -SheetId $sid -Start 0 -End 1 -Size 44
  Add-RowHeight -Requests $req -SheetId $sid -Start 1 -End 2 -Size 34
  Add-RowHeight -Requests $req -SheetId $sid -Start 3 -End 16 -Size 30
  $req.Add(@{
    updateSheetProperties = @{
      properties = @{ sheetId = $sid; gridProperties = @{ frozenRowCount = 2; rowCount = 70; columnCount = 12 } }
      fields = 'gridProperties.frozenRowCount,gridProperties.rowCount,gridProperties.columnCount'
    }
  }) | Out-Null
}

if ($sheetMap.ContainsKey('00_PANEL')) {
  $panelSheet = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sheetMap['00_PANEL'] } | Select-Object -First 1
  if ($panelSheet -and $panelSheet.charts) {
    $targets = @(
      @{ row = 18; col = 0 },
      @{ row = 18; col = 6 },
      @{ row = 30; col = 6 }
    )
    for ($i = 0; $i -lt $panelSheet.charts.Count; $i++) {
      $t = $targets[[Math]::Min($i, $targets.Count - 1)]
      $req.Add(@{
        updateEmbeddedObjectPosition = @{
          objectId = [int]$panelSheet.charts[$i].chartId
          newPosition = @{ overlayPosition = @{ anchorCell = @{ sheetId = $sheetMap['00_PANEL']; rowIndex = [int]$t.row; columnIndex = [int]$t.col }; offsetXPixels = 0; offsetYPixels = 0 } }
          fields = '*'
        }
      }) | Out-Null
    }
  }
}

if ($sheetMap.ContainsKey('03_ESCENARIOS')) {
  $scSheet = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sheetMap['03_ESCENARIOS'] } | Select-Object -First 1
  if ($scSheet -and $scSheet.charts) {
    $targets = @(
      @{ row = 9; col = 11 },
      @{ row = 24; col = 11 }
    )
    for ($i = 0; $i -lt $scSheet.charts.Count; $i++) {
      $t = $targets[[Math]::Min($i, $targets.Count - 1)]
      $req.Add(@{
        updateEmbeddedObjectPosition = @{
          objectId = [int]$scSheet.charts[$i].chartId
          newPosition = @{ overlayPosition = @{ anchorCell = @{ sheetId = $sheetMap['03_ESCENARIOS']; rowIndex = [int]$t.row; columnIndex = [int]$t.col }; offsetXPixels = 0; offsetYPixels = 0 } }
          fields = '*'
        }
      }) | Out-Null
    }
  }
}

if ($sheetMap.ContainsKey('00_GUIA_USO')) {
  $sid = $sheetMap['00_GUIA_USO']
  $req.Add(@{ unmergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 0; endRowIndex = 40; startColumnIndex = 0; endColumnIndex = 12 } } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 0; endRowIndex = 1; startColumnIndex = 0; endColumnIndex = 12 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 1; endRowIndex = 2; startColumnIndex = 0; endColumnIndex = 12 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 3; endRowIndex = 4; startColumnIndex = 0; endColumnIndex = 4 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 3; endRowIndex = 4; startColumnIndex = 4; endColumnIndex = 8 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 3; endRowIndex = 4; startColumnIndex = 8; endColumnIndex = 12 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 9; endRowIndex = 10; startColumnIndex = 0; endColumnIndex = 12 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 15; endRowIndex = 16; startColumnIndex = 0; endColumnIndex = 12 }; mergeType = 'MERGE_ALL' } }) | Out-Null
}

if ($sheetMap.ContainsKey('01_ENTRADA')) {
  $sid = $sheetMap['01_ENTRADA']
  $req.Add(@{ unmergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 0; endRowIndex = 40; startColumnIndex = 0; endColumnIndex = 8 } } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 0; endRowIndex = 1; startColumnIndex = 0; endColumnIndex = 8 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 1; endRowIndex = 2; startColumnIndex = 0; endColumnIndex = 8 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 2; endRowIndex = 3; startColumnIndex = 0; endColumnIndex = 8 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 3; endRowIndex = 4; startColumnIndex = 3; endColumnIndex = 8 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 7; endRowIndex = 8; startColumnIndex = 3; endColumnIndex = 8 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ mergeCells = @{ range = @{ sheetId = $sid; startRowIndex = 12; endRowIndex = 13; startColumnIndex = 0; endColumnIndex = 8 }; mergeType = 'MERGE_ALL' } }) | Out-Null
  $req.Add(@{ repeatCell = @{ range = @{ sheetId = $sid; startRowIndex = 0; endRowIndex = 80; startColumnIndex = 0; endColumnIndex = 8 }; cell = @{}; fields = 'dataValidation,note' } }) | Out-Null

  $req.Add(@{
    setDataValidation = @{
      range = @{ sheetId = $sid; startRowIndex = 4; endRowIndex = 5; startColumnIndex = 1; endColumnIndex = 2 }
      rule = @{
        condition = @{ type = 'ONE_OF_RANGE'; values = @(@{ userEnteredValue = '=07_LINEAS_NEGOCIO!$A$2:$A$200' }) }
        strict = $true
        showCustomUi = $true
      }
    }
  }) | Out-Null
  $req.Add(@{
    setDataValidation = @{
      range = @{ sheetId = $sid; startRowIndex = 7; endRowIndex = 8; startColumnIndex = 1; endColumnIndex = 2 }
      rule = @{
        condition = @{ type = 'ONE_OF_LIST'; values = @(@{ userEnteredValue = 'pendiente' }, @{ userEnteredValue = 'confirmado' }, @{ userEnteredValue = 'cancelado' }) }
        strict = $true
        showCustomUi = $true
      }
    }
  }) | Out-Null
  $req.Add(@{
    setDataValidation = @{
      range = @{ sheetId = $sid; startRowIndex = 8; endRowIndex = 9; startColumnIndex = 1; endColumnIndex = 2 }
      rule = @{
        condition = @{ type = 'ONE_OF_LIST'; values = @(@{ userEnteredValue = 'BBVA' }, @{ userEnteredValue = 'Caixa' }, @{ userEnteredValue = 'Santander' }, @{ userEnteredValue = 'Stripe' }, @{ userEnteredValue = 'Caja' }) }
        strict = $true
        showCustomUi = $true
      }
    }
  }) | Out-Null
  $req.Add(@{
    setDataValidation = @{
      range = @{ sheetId = $sid; startRowIndex = 10; endRowIndex = 11; startColumnIndex = 1; endColumnIndex = 2 }
      rule = @{
        condition = @{ type = 'ONE_OF_LIST'; values = @(@{ userEnteredValue = 'Banco' }, @{ userEnteredValue = 'Tarjeta' }, @{ userEnteredValue = 'Transferencia' }, @{ userEnteredValue = 'Efectivo' }, @{ userEnteredValue = 'Manual' }, @{ userEnteredValue = 'Resumen mensual' }) }
        strict = $true
        showCustomUi = $true
      }
    }
  }) | Out-Null
}

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $req } | Out-Null

# Clear and write values for Guide + Input side panels.
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId, [uri]::EscapeDataString('00_GUIA_USO!A1:L40')) -Token $token -Body @{} | Out-Null
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId, [uri]::EscapeDataString('01_ENTRADA!A1:H40')) -Token $token -Body @{} | Out-Null
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId, [uri]::EscapeDataString('00_PANEL!A98:L100')) -Token $token -Body @{} | Out-Null

$valueData = @(
  @{ range = '00_GUIA_USO!A1'; values = @(,@('MANUAL RAPIDO ARTES BUHO - CONTABILIDAD DE DECISION')) },
  @{ range = '00_GUIA_USO!A2'; values = @(,@('Objetivo: introducir pocos datos y tomar decisiones claras por linea de negocio. Solo editar celdas amarillas de 01_ENTRADA.')) },
  @{ range = '00_GUIA_USO!A4'; values = @(,@('FLUJO EN 3 PASOS','','','')) },
  @{ range = '00_GUIA_USO!E4'; values = @(,@('SEMAFORO','','','')) },
  @{ range = '00_GUIA_USO!I4'; values = @(,@('QUE REVISO CADA SEMANA','','','')) },
  @{ range = '00_GUIA_USO!A5:D8'; values = @(
    @('1','01_ENTRADA','Rellena fecha, linea, ingresos y gastos','Guardar dato rapido'),
    @('2','00_PANEL','Revisa KPI, semaforo y escenarios','Detectar riesgo y oportunidades'),
    @('3','03_ESCENARIOS','Compara base/optimista/pesimista','Definir accion de la semana'),
    @('4','06_FACTURAS','Revisar vencidas y pendientes','Proteger liquidez')
  ) },
  @{ range = '00_GUIA_USO!E5:H8'; values = @(
    @('VERDE','Resultado positivo','Sin tension de caja','Escalar linea rentable'),
    @('AMARILLO','Margen ajustado','Pendientes altos','Control diario + seguimiento'),
    @('ROJO','Perdida o desviacion fuerte','Riesgo de liquidez','Plan de choque 7 dias'),
    @('UMBRAL','Ingresos necesarios','Punto de equilibrio','Priorizar ventas/cobros')
  ) },
  @{ range = '00_GUIA_USO!I5:L8'; values = @(
    @('Linea en perdida','Ajustar gasto variable 8-12%','',''),
    @('Linea mas rentable','Escalar captacion y capacidad','',''),
    @('Escenario pesimista','Asegurar caja minima de 3 meses','',''),
    @('Facturas vencidas','Cobro/pago prioritario 48h','','')
  ) },
  @{ range = '00_GUIA_USO!A10'; values = @(,@('MENU CONTABILIDAD ARTES BUHO')) },
  @{ range = '00_GUIA_USO!A11:L14'; values = @(
    @('1) Preparar entorno','Inicializa y ordena toda la aplicacion','6) Recomendaciones semanales','Genera resumen IA en panel','11) Activar refresco 15 min','Actualiza panel automaticamente','','','','','',''),
    @('2) Guardar dato rapido','Inserta ingreso/gasto del periodo','7) Abrir guia de uso','Abre este manual','12) Pausar refresco 15 min','Detiene refresco automatico','','','','','',''),
    @('3) Actualizar panel','Recalcula KPIs y graficos','8) Estado general','Resumen rapido tecnico','13) Sincronizar accesos','Evita bloqueos por permisos','','','','','',''),
    @('4) Recalcular escenarios','Actualiza escenarios por linea','9-10) Automatizacion semanal','Activa/Pausa ciclo semanal','','','','','','','','')
  ) },
  @{ range = '00_GUIA_USO!A16'; values = @(,@('REGLA DE ORO: si algo no se entiende, se simplifica en 01_ENTRADA y se decide desde 00_PANEL.')) },

  @{ range = '01_ENTRADA!A1'; values = @(,@('ENTRADA RAPIDA - ARTES BUHO')) },
  @{ range = '01_ENTRADA!A2'; values = @(,@('Completa solo celdas amarillas y usa "Guardar dato rapido". El panel y los escenarios se recalculan solos.')) },
  @{ range = '01_ENTRADA!A3'; values = @(,@('EDITA SOLO B4:B11 | TODO LO DEMAS ES AUTOMATICO')) },
  @{ range = '01_ENTRADA!A4:A11'; values = @(
    @('Fecha'),
    @('Linea de negocio'),
    @('Ingresos del periodo (EUR)'),
    @('Gastos del periodo (EUR)'),
    @('Estado'),
    @('Cuenta bancaria'),
    @('Nota'),
    @('Origen del dato')
  ) },
  @{ range = '01_ENTRADA!B4:B11'; values = @(
    @('=TODAY()'),
    @('Escuela'),
    @(0),
    @(0),
    @('confirmado'),
    @('BBVA'),
    @(''),
    @('Banco')
  ) },
  @{ range = '01_ENTRADA!D4'; values = @(,@('IMPACTO EN TIEMPO REAL','','','','')) },
  @{ range = '01_ENTRADA!D5:H5'; values = @(,@('Ingresos confirmados','Gastos confirmados','Resultado neto','Pendiente validar','Semaforo')) },
  @{ range = '01_ENTRADA!D6:H6'; values = @(,@(
    '=SUMIFS(''02_TRANSACCIONES''!H:H;''02_TRANSACCIONES''!B:B;"ingreso";''02_TRANSACCIONES''!I:I;"confirmado")',
    '=SUMIFS(''02_TRANSACCIONES''!H:H;''02_TRANSACCIONES''!B:B;"gasto";''02_TRANSACCIONES''!I:I;"confirmado")',
    '=D6+E6',
    '=SUMIFS(''02_TRANSACCIONES''!H:H;''02_TRANSACCIONES''!I:I;"pendiente")',
    '=IF(F6>=0;"VERDE";IF(F6>-2000;"AMARILLO";"ROJO"))'
  )) },
  @{ range = '01_ENTRADA!D8'; values = @(,@('ULTIMOS MOVIMIENTOS (SOLO LECTURA)')) },
  @{ range = '01_ENTRADA!D9:H9'; values = @(,@('Fecha','Linea','Concepto','Importe','Estado')) },
  @{ range = '01_ENTRADA!D10'; values = @(,@('=IFERROR(QUERY(''02_TRANSACCIONES''!A1:I;"select A,C,F,H,I where A is not null order by A desc limit 6";1);"Sin movimientos recientes")')) },
  @{ range = '01_ENTRADA!A13'; values = @(,@('NOTAS: usa 02_TRANSACCIONES para detalle, 03_ESCENARIOS para planificar y 00_PANEL para decidir.')) }
)

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{
  valueInputOption = 'USER_ENTERED'
  data = $valueData
} | Out-Null

# Cosmetic formats for guide/input blocks.
$fmt = New-Object 'System.Collections.Generic.List[object]'
if ($sheetMap.ContainsKey('00_GUIA_USO')) {
  $sid = $sheetMap['00_GUIA_USO']
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=12 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 0.70; green = 0.00; blue = 0.00 }; textFormat = @{ bold = $true; foregroundColor = @{ red = 1; green = 1; blue = 1 }; fontFamily = 'Montserrat'; fontSize = 16 }; horizontalAlignment = 'CENTER' } }; fields = 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=1; endRowIndex=2; startColumnIndex=0; endColumnIndex=12 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 1.00; green = 0.83; blue = 0.00 }; textFormat = @{ bold = $true; fontFamily = 'Montserrat' }; horizontalAlignment = 'CENTER' } }; fields = 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=3; endRowIndex=16; startColumnIndex=0; endColumnIndex=12 }; cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat' }; wrapStrategy = 'WRAP'; verticalAlignment = 'MIDDLE' } }; fields = 'userEnteredFormat(textFormat,wrapStrategy,verticalAlignment)' } }) | Out-Null
}
if ($sheetMap.ContainsKey('01_ENTRADA')) {
  $sid = $sheetMap['01_ENTRADA']
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=8 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 0.70; green = 0.00; blue = 0.00 }; textFormat = @{ bold = $true; foregroundColor = @{ red = 1; green = 1; blue = 1 }; fontFamily = 'Montserrat'; fontSize = 16 }; horizontalAlignment = 'CENTER' } }; fields = 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=1; endRowIndex=2; startColumnIndex=0; endColumnIndex=8 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 1.00; green = 0.83; blue = 0.00 }; textFormat = @{ bold = $true; fontFamily = 'Montserrat' }; horizontalAlignment = 'CENTER' } }; fields = 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=2; endRowIndex=3; startColumnIndex=0; endColumnIndex=8 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 0.99; green = 0.89; blue = 0.89 }; textFormat = @{ bold = $true; fontFamily = 'Montserrat' }; horizontalAlignment = 'CENTER' } }; fields = 'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=3; endRowIndex=11; startColumnIndex=0; endColumnIndex=1 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 0.99; green = 0.89; blue = 0.89 }; textFormat = @{ bold = $true; fontFamily = 'Montserrat' } } }; fields = 'userEnteredFormat(backgroundColor,textFormat)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=3; endRowIndex=11; startColumnIndex=1; endColumnIndex=2 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 1.00; green = 0.97; blue = 0.80 }; textFormat = @{ fontFamily = 'Montserrat' } } }; fields = 'userEnteredFormat(backgroundColor,textFormat)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=4; endRowIndex=6; startColumnIndex=3; endColumnIndex=8 }; cell = @{ userEnteredFormat = @{ backgroundColor = @{ red = 0.98; green = 0.89; blue = 0.89 }; textFormat = @{ bold = $true; fontFamily = 'Montserrat' } } }; fields = 'userEnteredFormat(backgroundColor,textFormat)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=5; endRowIndex=20; startColumnIndex=3; endColumnIndex=8 }; cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat' }; wrapStrategy = 'WRAP' } }; fields = 'userEnteredFormat(textFormat,wrapStrategy)' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=3; endRowIndex=4; startColumnIndex=1; endColumnIndex=2 }; cell = @{ userEnteredFormat = @{ numberFormat = @{ type = 'DATE'; pattern = 'yyyy-mm-dd' } } }; fields = 'userEnteredFormat.numberFormat' } }) | Out-Null
  $fmt.Add(@{ repeatCell = @{ range = @{ sheetId=$sid; startRowIndex=5; endRowIndex=7; startColumnIndex=1; endColumnIndex=2 }; cell = @{ userEnteredFormat = @{ numberFormat = @{ type = 'NUMBER'; pattern = '#,##0.00 [$€-es-ES]' } } }; fields = 'userEnteredFormat.numberFormat' } }) | Out-Null
}

if ($fmt.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $fmt } | Out-Null
}

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  appliedRequests = ($req.Count + $fmt.Count)
  updatedRanges = $valueData.Count
  updatedAt = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 6






