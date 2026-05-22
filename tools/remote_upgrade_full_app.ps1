param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$TokenProfile = 'default',
  [ValidateSet('oauth','service_account')]
  [string]$AuthMode = 'service_account',
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

    $token = & $nodeCmd $helper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
      throw 'No se pudo obtener access_token con cuenta de servicio'
    }
    return [string]$token
  }

  $rc = 'C:\Users\elrub\.clasprc.json'
  if (-not (Test-Path -LiteralPath $rc)) { throw 'No existe C:\Users\elrub\.clasprc.json' }

  $cfg = Get-Content $rc -Raw | ConvertFrom-Json
  $tok = $cfg.tokens.$Profile
  if (-not $tok) { throw ('Token profile no encontrado: ' + $Profile) }

  $resp = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
    client_id = $tok.client_id
    client_secret = $tok.client_secret
    refresh_token = $tok.refresh_token
    grant_type = 'refresh_token'
  }
  if (-not $resp.access_token) { throw 'No se pudo obtener access_token' }
  return [string]$resp.access_token
}

function Invoke-GApi {
  param(
    [ValidateSet('GET','POST','PUT','PATCH')]
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

    if ($null -eq $Body) {
      return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType 'application/json' -Body '{}'
    }

    $json = $Body | ConvertTo-Json -Depth 40
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bytes
  }
  catch {
    if ($_.Exception.Response) {
      $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
      $txt = $sr.ReadToEnd()
      $sr.Close()
      Write-Host ('API_ERROR_URI=' + $Uri)
      Write-Host ('API_ERROR_BODY=' + $txt)
      if ($null -ne $Body) {
        Write-Host ('API_ERROR_REQUEST=' + ($Body | ConvertTo-Json -Depth 40 -Compress))
      }
    }
    throw
  }
}

function Get-Meta {
  param([string]$Id,[string]$Token)
  $uri = "https://sheets.googleapis.com/v4/spreadsheets/{0}?fields=spreadsheetId,properties(title,locale,timeZone),sheets(properties(sheetId,title,index,hidden,gridProperties),charts)" -f $Id
  return Invoke-GApi -Method GET -Uri $uri -Token $Token
}

function Get-SheetMap {
  param($Meta)
  $map = @{}
  foreach($s in $Meta.sheets){
    $map[[string]$s.properties.title] = [int]$s.properties.sheetId
  }
  return $map
}

$token = Get-AccessToken -Profile $TokenProfile -Mode $AuthMode -ServiceAccountKey $ServiceAccountKeyPath
$meta = Get-Meta -Id $SpreadsheetId -Token $token
$sheetMap = Get-SheetMap -Meta $meta

$extra = @(
  @{ name='05_PRESUPUESTO'; rows=400; cols=10; tab=@{red=1.00;green=0.83;blue=0.00} },
  @{ name='06_FACTURAS'; rows=5000; cols=13; tab=@{red=0.70;green=0.00;blue=0.00} }
)

$requests = @()
foreach($s in $extra){
  if (-not $sheetMap.ContainsKey($s.name)) {
    $requests += @{
      addSheet = @{
        properties = @{
          title = $s.name
          gridProperties = @{ rowCount = $s.rows; columnCount = $s.cols }
          tabColorStyle = @{ rgbColor = $s.tab }
        }
      }
    }
  }
}

if ($requests.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null
  $meta = Get-Meta -Id $SpreadsheetId -Token $token
  $sheetMap = Get-SheetMap -Meta $meta
}

$requests = @()
foreach($s in $extra){
  $sid = [int]$sheetMap[$s.name]
  $requests += @{
    updateSheetProperties = @{
      properties = @{
        sheetId = $sid
        gridProperties = @{ rowCount = $s.rows; columnCount = $s.cols; frozenRowCount = 1; hideGridlines = $true }
        tabColorStyle = @{ rgbColor = $s.tab }
      }
      fields = 'gridProperties.rowCount,gridProperties.columnCount,gridProperties.frozenRowCount,gridProperties.hideGridlines,tabColorStyle'
    }
  }
}

# Delete only charts managed by this upgrade script.
$managedChartTitles = @('Presupuesto vs Real (Global)')
foreach($sh in $meta.sheets){
  if ($sh.charts) {
    foreach($ch in $sh.charts){
      $title = [string]$ch.spec.title
      if ($managedChartTitles -contains $title) {
        $requests += @{ deleteEmbeddedObject = @{ objectId = [int]$ch.chartId } }
      }
    }
  }
}

if ($requests.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null
}

foreach($range in @('05_PRESUPUESTO!A1:Z400','06_FACTURAS!A1:Z5000','00_PANEL!A73:H82')){
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId, [uri]::EscapeDataString($range)) -Token $token -Body @{} | Out-Null
}

$data = @(
  @{ range='05_PRESUPUESTO!A1:J1'; values=@(@('Mes','Linea de negocio','Ingresos presupuesto','Gastos presupuesto','Resultado presupuesto','Ingresos reales','Gastos reales','Resultado real','Desviacion','Alerta')) },
  @{ range='05_PRESUPUESTO!A2'; values=@(@('=ARRAYFORMULA(DATE(YEAR(TODAY()),SEQUENCE(12),1))')) },
  @{ range='05_PRESUPUESTO!B2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="","","GLOBAL"))')) },
  @{ range='05_PRESUPUESTO!C2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="","",12000))')) },
  @{ range='05_PRESUPUESTO!D2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="","",-7000))')) },
  @{ range='05_PRESUPUESTO!E2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="",,C2:C13+D2:D13))')) },
  @{ range='05_PRESUPUESTO!F2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="",,SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!B:B,"ingreso",TEXT(''02_TRANSACCIONES''!A:A,"yyyy-mm"),TEXT(A2:A13,"yyyy-mm"))))')) },
  @{ range='05_PRESUPUESTO!G2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="",,SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!B:B,"gasto",TEXT(''02_TRANSACCIONES''!A:A,"yyyy-mm"),TEXT(A2:A13,"yyyy-mm"))))')) },
  @{ range='05_PRESUPUESTO!H2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="",,F2:F13+G2:G13))')) },
  @{ range='05_PRESUPUESTO!I2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="",,H2:H13-E2:E13))')) },
  @{ range='05_PRESUPUESTO!J2'; values=@(@('=ARRAYFORMULA(IF(A2:A13="",,IF(I2:I13<-5000,"ALTA",IF(I2:I13<0,"MEDIA","CONTROLADA"))))')) },

  @{ range='06_FACTURAS!A1:M1'; values=@(@('ID','Fecha emision','Cliente/Proveedor','Tipo','Base imponible','IVA','Total','Vencimiento','Estado','Fecha cobro/pago','Linea de negocio','Cuenta','Nota')) },
  @{ range='06_FACTURAS!A2:M5'; values=@(
    @('F-0001','=TODAY()-7','Cliente Escuela Norte','emitida',1200,252,1452,'=TODAY()+7','pendiente','','Escuela','BBVA','Factura pendiente de cobro'),
    @('F-0002','=TODAY()-20','Proveedor Sonido Pro','recibida',900,189,1089,'=TODAY()-2','vencida','','Eventos','CAIXA','Pago vencido prioritario'),
    @('F-0003','=TODAY()-15','Cliente Bodas Premium','emitida',2200,462,2662,'=TODAY()+10','cobrada','=TODAY()-1','Eventos','BBVA','Cobro confirmado'),
    @('F-0004','=TODAY()-3','Proveedor Marketing','recibida',400,84,484,'=TODAY()+20','pagada','=TODAY()','Escuela','CAIXA','Pagada en plazo')
  ) },

  @{ range='00_PANEL!A73:H73'; values=@(@('CONTROL OPERATIVO AMPLIADO','','','','','','','')) },
  @{ range='00_PANEL!A74:A78'; values=@(
    @('FACTURAS ABIERTAS'),
    @('FACTURAS VENCIDAS'),
    @('SALDO FACTURAS ABIERTAS'),
    @('DESVIACION PRESUPUESTO (YTD)'),
    @('RIESGO LIQUIDEZ 30D')
  ) },
  @{ range='00_PANEL!B74:B78'; values=@(
    @('=COUNTIFS(''06_FACTURAS''!I:I,"pendiente")+COUNTIFS(''06_FACTURAS''!I:I,"vencida")'),
    @('=COUNTIFS(''06_FACTURAS''!I:I,"vencida")'),
    @('=SUMIFS(''06_FACTURAS''!G:G,''06_FACTURAS''!I:I,"pendiente")+SUMIFS(''06_FACTURAS''!G:G,''06_FACTURAS''!I:I,"vencida")'),
    @('=SUM(''05_PRESUPUESTO''!I2:I13)'),
    @('=IF(B76>ABS(B4)*1.2,"ALTO",IF(B76>ABS(B4)*0.8,"MEDIO","CONTROLADO"))')
  ) },
  @{ range='00_PANEL!D74:G78'; values=@(
    @('PRESUPUESTO','REAL','DESVIACION','ALERTA'),
    @('=SUM(''05_PRESUPUESTO''!E2:E13)','=SUM(''05_PRESUPUESTO''!H2:H13)','=E75-D75','=IF(F75<-5000,"ALTA",IF(F75<0,"MEDIA","CONTROLADA"))'),
    @('','','',''),
    @('','','',''),
    @('','','','')
  ) }
)

$dataPrepared = @()
foreach($d in $data){
  $rows = $d.values
  $vals2d = New-Object System.Collections.ArrayList

  if ($rows -is [System.Array] -and $rows.Count -gt 0 -and ($rows[0] -is [System.Array])) {
    foreach($r in $rows){ [void]$vals2d.Add([object[]]$r) }
  } elseif ($rows -is [System.Array]) {
    [void]$vals2d.Add([object[]]$rows)
  } else {
    [void]$vals2d.Add([object[]]@($rows))
  }

  $dataPrepared += @{
    range = [string]$d.range
    majorDimension = 'ROWS'
    values = $vals2d
  }
}

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ valueInputOption='USER_ENTERED'; data=$dataPrepared } | Out-Null

$panelId = [int]$sheetMap['00_PANEL']
$budgetId = [int]$sheetMap['05_PRESUPUESTO']
$invoiceId = [int]$sheetMap['06_FACTURAS']

$requests = @(
  @{ mergeCells = @{ range = @{ sheetId=$panelId; startRowIndex=72; endRowIndex=73; startColumnIndex=0; endColumnIndex=8 }; mergeType='MERGE_ALL' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=72; endRowIndex=73; startColumnIndex=0; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true; fontSize=13 }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=73; endRowIndex=78; startColumnIndex=0; endColumnIndex=1 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.996;green=0.886;blue=0.886} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=73; endRowIndex=78; startColumnIndex=1; endColumnIndex=2 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.95;blue=0.75} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=73; endRowIndex=78; startColumnIndex=1; endColumnIndex=2 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },

  @{ repeatCell = @{ range=@{ sheetId=$budgetId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=10 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$budgetId; startRowIndex=1; endRowIndex=13; startColumnIndex=2; endColumnIndex=9 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$budgetId; startRowIndex=1; endRowIndex=13; startColumnIndex=0; endColumnIndex=1 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='DATE'; pattern='yyyy-mm' } } }; fields='userEnteredFormat.numberFormat' } },

  @{ repeatCell = @{ range=@{ sheetId=$invoiceId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=13 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$invoiceId; startRowIndex=1; endRowIndex=5000; startColumnIndex=4; endColumnIndex=7 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$invoiceId; startRowIndex=1; endRowIndex=5000; startColumnIndex=1; endColumnIndex=2 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='DATE'; pattern='yyyy-mm-dd' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$invoiceId; startRowIndex=1; endRowIndex=5000; startColumnIndex=7; endColumnIndex=10 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='DATE'; pattern='yyyy-mm-dd' } } }; fields='userEnteredFormat.numberFormat' } },

  @{ setDataValidation = @{ range=@{ sheetId=$invoiceId; startRowIndex=1; endRowIndex=5000; startColumnIndex=3; endColumnIndex=4 }; rule=@{ condition=@{ type='ONE_OF_LIST'; values=@(@{userEnteredValue='emitida'},@{userEnteredValue='recibida'}) }; strict=$true; showCustomUi=$true } } },
  @{ setDataValidation = @{ range=@{ sheetId=$invoiceId; startRowIndex=1; endRowIndex=5000; startColumnIndex=8; endColumnIndex=9 }; rule=@{ condition=@{ type='ONE_OF_LIST'; values=@(@{userEnteredValue='pendiente'},@{userEnteredValue='vencida'},@{userEnteredValue='cobrada'},@{userEnteredValue='pagada'},@{userEnteredValue='cancelada'}) }; strict=$true; showCustomUi=$true } } },

  @{ addConditionalFormatRule = @{ index=0; rule=@{ ranges=@(@{ sheetId=$invoiceId; startRowIndex=1; endRowIndex=5000; startColumnIndex=0; endColumnIndex=13 }); booleanRule=@{ condition=@{ type='CUSTOM_FORMULA'; values=@(@{userEnteredValue='=$I2="vencida"'}) }; format=@{ backgroundColorStyle=@{ rgbColor=@{red=0.996;green=0.91;blue=0.91} } } } } } },
  @{ addConditionalFormatRule = @{ index=0; rule=@{ ranges=@(@{ sheetId=$invoiceId; startRowIndex=1; endRowIndex=5000; startColumnIndex=0; endColumnIndex=13 }); booleanRule=@{ condition=@{ type='CUSTOM_FORMULA'; values=@(@{userEnteredValue='=$I2="pendiente"'}) }; format=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.95;blue=0.75} } } } } } },

  @{ addChart = @{ chart=@{ spec=@{ title='Presupuesto vs Real (Global)'; basicChart=@{ chartType='LINE'; legendPosition='BOTTOM_LEGEND'; headerCount=1; domains=@(@{ domain=@{ sourceRange=@{ sources=@(@{ sheetId=$budgetId; startRowIndex=0; endRowIndex=13; startColumnIndex=0; endColumnIndex=1 }) } } }); series=@(@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$budgetId; startRowIndex=0; endRowIndex=13; startColumnIndex=4; endColumnIndex=5 }) } } },@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$budgetId; startRowIndex=0; endRowIndex=13; startColumnIndex=7; endColumnIndex=8 }) } } },@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$budgetId; startRowIndex=0; endRowIndex=13; startColumnIndex=8; endColumnIndex=9 }) } } }) } }; position=@{ overlayPosition=@{ anchorCell=@{ sheetId=$panelId; rowIndex=81; columnIndex=0 }; offsetXPixels=10; offsetYPixels=10; widthPixels=760; heightPixels=280 } } } } }
)

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null

$resizeReq = @()
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$budgetId; dimension='COLUMNS'; startIndex=0; endIndex=10 }; properties=@{ pixelSize=150 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$invoiceId; dimension='COLUMNS'; startIndex=0; endIndex=13 }; properties=@{ pixelSize=140 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$panelId; dimension='ROWS'; startIndex=72; endIndex=82 }; properties=@{ pixelSize=34 }; fields='pixelSize' } }
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $resizeReq } | Out-Null

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  upgradedSheets = @('05_PRESUPUESTO','06_FACTURAS')
  timestamp = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 6




