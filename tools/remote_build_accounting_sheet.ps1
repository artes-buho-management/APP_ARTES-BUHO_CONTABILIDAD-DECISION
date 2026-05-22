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

    $json = $Body | ConvertTo-Json -Depth 30
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
        Write-Host ('API_ERROR_REQUEST=' + ($Body | ConvertTo-Json -Depth 30 -Compress))
      }
    }
    throw
  }
}

function Get-Meta {
  param([string]$SpreadsheetId,[string]$Token)
  $uri = "https://sheets.googleapis.com/v4/spreadsheets/{0}?fields=spreadsheetId,properties(title,timeZone),sheets(properties(sheetId,title,index,hidden,gridProperties),charts,protectedRanges(protectedRangeId,warningOnly,description,range)),namedRanges" -f $SpreadsheetId
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

function ToValues {
  param([Parameter(Mandatory)]$Rows)

  $vals = New-Object System.Collections.ArrayList

  if ($Rows -is [System.Array]) {
    if ($Rows.Count -eq 0) {
      Write-Output -NoEnumerate @()
      return
    }

    $first = $Rows[0]
    if ($first -is [System.Array]) {
      foreach($r in $Rows){
        [void]$vals.Add([object[]]$r)
      }
      Write-Output -NoEnumerate $vals.ToArray()
      return
    }

    [void]$vals.Add([object[]]$Rows)
    Write-Output -NoEnumerate $vals.ToArray()
    return
  }

  [void]$vals.Add([object[]]@($Rows))
  Write-Output -NoEnumerate $vals.ToArray()
}

$token = Get-AccessToken -Profile $TokenProfile -Mode $AuthMode -ServiceAccountKey $ServiceAccountKeyPath
$meta = Get-Meta -SpreadsheetId $SpreadsheetId -Token $token

# Force locale for formula parser consistency (comma separators and English function names)
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{
  requests = @(
    @{
      updateSpreadsheetProperties = @{
        properties = @{ locale = 'en_US'; timeZone = 'Europe/Madrid' }
        fields = 'locale,timeZone'
      }
    }
  )
} | Out-Null

$core = @(
  @{ name='00_PANEL'; rows=140; cols=12; tab=@{red=0.70;green=0.00;blue=0.00} },
  @{ name='01_ENTRADA'; rows=40; cols=8; tab=@{red=1.00;green=0.83;blue=0.00} },
  @{ name='02_TRANSACCIONES'; rows=5000; cols=11; tab=@{red=0.70;green=0.00;blue=0.00} },
  @{ name='03_ESCENARIOS'; rows=120; cols=12; tab=@{red=0.85;green=0.47;blue=0.10} },
  @{ name='04_AUDITORIA'; rows=3000; cols=8; tab=@{red=0.60;green=0.00;blue=0.00} },
  @{ name='98_LOG'; rows=5000; cols=8; tab=@{red=0.29;green=0.35;blue=0.41} },
  @{ name='99_CONFIG'; rows=200; cols=6; tab=@{red=0.06;green=0.09;blue=0.16} }
)

$sheetMap = Get-SheetMap -Meta $meta
$requests = @()

# If first sheet is not 00_PANEL and 00_PANEL missing, rename first existing sheet to 00_PANEL
if (-not $sheetMap.ContainsKey('00_PANEL') -and $meta.sheets.Count -gt 0) {
  $firstId = [int]$meta.sheets[0].properties.sheetId
  $requests += @{
    updateSheetProperties = @{
      properties = @{ sheetId = $firstId; title = '00_PANEL'; index = 0 }
      fields = 'title,index'
    }
  }
}

if ($requests.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null
  $meta = Get-Meta -SpreadsheetId $SpreadsheetId -Token $token

  $sheetMap = Get-SheetMap -Meta $meta
  $requests = @()
}

# Create missing sheets
foreach($s in $core){
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
  $meta = Get-Meta -SpreadsheetId $SpreadsheetId -Token $token

  $sheetMap = Get-SheetMap -Meta $meta
  $requests = @()
}

# Resize and style core sheets
foreach($s in $core){
  $sid = [int]$sheetMap[$s.name]
  $requests += @{
    updateSheetProperties = @{
      properties = @{
        sheetId = $sid
        gridProperties = @{ rowCount = $s.rows; columnCount = $s.cols; frozenRowCount = 1 }
        tabColorStyle = @{ rgbColor = $s.tab }
      }
      fields = 'gridProperties.rowCount,gridProperties.columnCount,gridProperties.frozenRowCount,tabColorStyle'
    }
  }
}

# Hide gridlines for visual sheets
foreach($name in @('00_PANEL','01_ENTRADA','03_ESCENARIOS','04_AUDITORIA')){
  $requests += @{
    updateSheetProperties = @{
      properties = @{ sheetId = [int]$sheetMap[$name]; gridProperties = @{ hideGridlines = $true } }
      fields = 'gridProperties.hideGridlines'
    }
  }
}

# Remove old charts
foreach($sh in $meta.sheets){
  if ($sh.charts) {
    foreach($ch in $sh.charts){
      $requests += @{ deleteEmbeddedObject = @{ objectId = [int]$ch.chartId } }
    }
  }
}

# Remove old managed protections to avoid duplicated/stacked locks after re-runs.
$managedProtectionSheets = @('01_ENTRADA','00_PANEL','03_ESCENARIOS','04_AUDITORIA','99_CONFIG')
foreach($sh in $meta.sheets){
  $title = [string]$sh.properties.title
  if (($managedProtectionSheets -contains $title) -and $sh.protectedRanges) {
    foreach($pr in $sh.protectedRanges){
      $requests += @{ deleteProtectedRange = @{ protectedRangeId = [int]$pr.protectedRangeId } }
    }
  }
}
if ($requests.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null
}

# Clear values of core ranges
foreach($s in $core){
  $range = "{0}!A1:ZZ{1}" -f $s.name, $s.rows
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId, [uri]::EscapeDataString($range)) -Token $token -Body @{} | Out-Null
}

# Seed values and formulas
$data = @(
  @{ range='99_CONFIG!A1:C1'; values=@(@('key','value','description')) },
  @{ range='99_CONFIG!A2:C13'; values=@(
    @('app_name','Artes Buho Contabilidad IA Visual','Nombre del sistema'),
    @('app_version','1.0','Version actual'),
    @('currency','EUR','Moneda'),
    @('access_mode','TEAM_OPEN','TEAM_OPEN o STRICT_LOCKED'),
    @('ai_provider','gemini','Proveedor IA'),
    @('scenario_growth_optimistic',0.15,'Crecimiento optimista mensual'),
    @('scenario_growth_base',0.00,'Crecimiento base mensual'),
    @('scenario_growth_pessimistic',-0.12,'Crecimiento pesimista mensual'),
    @('avg_ingresos_confirmados','=IFERROR(AVERAGE(FILTER(''02_TRANSACCIONES''!H2:H,''02_TRANSACCIONES''!B2:B="ingreso",''02_TRANSACCIONES''!I2:I="confirmado")),0)','Media ingresos confirmados'),
    @('avg_gastos_confirmados_abs','=ABS(IFERROR(AVERAGE(FILTER(''02_TRANSACCIONES''!H2:H,''02_TRANSACCIONES''!B2:B="gasto",''02_TRANSACCIONES''!I2:I="confirmado")),0))','Media gastos absolutos'),
    @('caja_base_inicial','=SUM(FILTER(''02_TRANSACCIONES''!H2:H,''02_TRANSACCIONES''!I2:I="confirmado"))','Caja inicial desde confirmados'),
    @('updated_at','=NOW()','Marca temporal')
  ) },

  @{ range='01_ENTRADA!A1:H1'; values=@(@('FORMULARIO CONTABLE ARTES BUHO','','','','','','','')) },
  @{ range='01_ENTRADA!A2:H2'; values=@(@('Rellena solo celdas amarillas -> luego copia registro a 02_TRANSACCIONES','','','','','','','')) },
  @{ range='01_ENTRADA!A4:A14'; values=@(
    @('Fecha'),@('Tipo (ingreso/gasto)'),@('Linea negocio'),@('Categoria'),@('Subcategoria'),@('Concepto'),@('Cuenta'),@('Importe'),@('Estado (pendiente/confirmado/cancelado)'),@('Origen'),@('Nota')
  ) },
  @{ range='01_ENTRADA!B4:B14'; values=@(
    @('=TODAY()'),@('ingreso'),@('Escuela'),@('Operacion'),@('General'),@('Concepto'),@('BBVA'),@(0),@('pendiente'),@('manual'),@('')
  ) },

  @{ range='02_TRANSACCIONES!A1:K1'; values=@(@('fecha','tipo','linea_negocio','categoria','subcategoria','concepto','cuenta','importe','estado','origen','nota')) },
  @{ range='02_TRANSACCIONES!A2:K5'; values=@(
    @('=TODAY()','ingreso','Escuela','Formacion','Matricula','Cobro mensual','BBVA',9800,'confirmado','seed','dato inicial'),
    @('=TODAY()','gasto','Escuela','Personal','Nomina','Nomina mensual','BBVA',-6200,'confirmado','seed','dato inicial'),
    @('=TODAY()','ingreso','Eventos','Bodas','Cierre','Evento privado','CAIXA',5200,'confirmado','seed','dato inicial'),
    @('=TODAY()','gasto','Eventos','Produccion','Tecnica','Sonido','CAIXA',-1400,'pendiente','seed','dato inicial')
  ) },

  @{ range='03_ESCENARIOS!A1:F1'; values=@(@('escenario','mes','ingresos','gastos','resultado','caja_acumulada')) },
  @{ range='03_ESCENARIOS!A2'; values=@(@('=ARRAYFORMULA(IF(ROW(A2:A37)-1<=12,"optimista",IF(ROW(A2:A37)-1<=24,"base","pesimista")))')) },
  @{ range='03_ESCENARIOS!B2'; values=@(@('=ARRAYFORMULA(MOD(ROW(B2:B37)-2,12)+1)')) },
  @{ range='03_ESCENARIOS!C2'; values=@(@('=ARRAYFORMULA(IF(A2:A37="",,ROUND(VLOOKUP("avg_ingresos_confirmados",''99_CONFIG''!A:B,2,false)*POWER(1+IF(A2:A37="optimista",VLOOKUP("scenario_growth_optimistic",''99_CONFIG''!A:B,2,false),IF(A2:A37="base",VLOOKUP("scenario_growth_base",''99_CONFIG''!A:B,2,false),VLOOKUP("scenario_growth_pessimistic",''99_CONFIG''!A:B,2,false))),B2:B37),2)))')) },
  @{ range='03_ESCENARIOS!D2'; values=@(@('=ARRAYFORMULA(IF(A2:A37="",,-ROUND(VLOOKUP("avg_gastos_confirmados_abs",''99_CONFIG''!A:B,2,false)*(1+IF(A2:A37="optimista",VLOOKUP("scenario_growth_optimistic",''99_CONFIG''!A:B,2,false),IF(A2:A37="base",VLOOKUP("scenario_growth_base",''99_CONFIG''!A:B,2,false),VLOOKUP("scenario_growth_pessimistic",''99_CONFIG''!A:B,2,false)))*0.5),2)))')) },
  @{ range='03_ESCENARIOS!E2'; values=@(@('=ARRAYFORMULA(IF(A2:A37="",,C2:C37+D2:D37))')) },
  @{ range='03_ESCENARIOS!F2'; values=@(@('=ARRAYFORMULA(IF(A2:A37="",,VLOOKUP("caja_base_inicial",''99_CONFIG''!A:B,2,false)+SCAN(0,E2:E37,LAMBDA(ac,x,ac+x))))')) },

  @{ range='00_PANEL!A1:L1'; values=@(@('PANEL CORPORATIVO ARTES BUHO - CONTABILIDAD IA','','','','','','','','','','','')) },
  @{ range='00_PANEL!A2:L2'; values=@(@('Actualizado en:','=NOW()','','','','','','','','','','')) },
  @{ range='00_PANEL!A4:A10'; values=@(
    @('INGRESOS CONFIRMADOS'),@('GASTOS CONFIRMADOS'),@('RESULTADO NETO'),@('PENDIENTE VALIDAR'),@('TOTAL MOVIMIENTOS'),@('LINEAS DE NEGOCIO'),@('% CONFIRMADAS')
  ) },
  @{ range='00_PANEL!B4:B10'; values=@(
    @('=SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!B:B,"ingreso",''02_TRANSACCIONES''!I:I,"confirmado")'),
    @('=SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!B:B,"gasto",''02_TRANSACCIONES''!I:I,"confirmado")'),
    @('=B4+B5'),
    @('=SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!I:I,"pendiente")'),
    @('=COUNTA(''02_TRANSACCIONES''!A2:A)'),
    @('=COUNTA(UNIQUE(FILTER(''02_TRANSACCIONES''!C2:C,''02_TRANSACCIONES''!C2:C<>"")))'),
    @('=IF(B8=0,0,COUNTIF(''02_TRANSACCIONES''!I2:I,"confirmado")/B8)')
  ) },
  @{ range='00_PANEL!A13:E13'; values=@(@('Mes','Ingresos','Gastos','Resultado','Caja acumulada')) },
  @{ range='00_PANEL!A14'; values=@(@('=SORT(UNIQUE(FILTER(TEXT(''02_TRANSACCIONES''!A2:A,"yyyy-mm"),''02_TRANSACCIONES''!A2:A<>"")))')) },
  @{ range='00_PANEL!B14'; values=@(@('=ARRAYFORMULA(IF(A14:A45="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!B:B,"ingreso",TEXT(''02_TRANSACCIONES''!A:A,"yyyy-mm"),A14:A45)))')) },
  @{ range='00_PANEL!C14'; values=@(@('=ARRAYFORMULA(IF(A14:A45="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!B:B,"gasto",TEXT(''02_TRANSACCIONES''!A:A,"yyyy-mm"),A14:A45)))')) },
  @{ range='00_PANEL!D14'; values=@(@('=ARRAYFORMULA(IF(A14:A45="","",B14:B45+C14:C45))')) },
  @{ range='00_PANEL!E14'; values=@(@('=ARRAYFORMULA(IF(A14:A45="","",SCAN(0,D14:D45,LAMBDA(ac,x,ac+x))))')) },
  @{ range='00_PANEL!G13:K13'; values=@(@('Linea negocio','Ingresos','Gastos','Resultado','N mov.')) },
  @{ range='00_PANEL!G14'; values=@(@('=SORT(UNIQUE(FILTER(''02_TRANSACCIONES''!C2:C,''02_TRANSACCIONES''!C2:C<>"")))')) },
  @{ range='00_PANEL!H14'; values=@(@('=ARRAYFORMULA(IF(G14:G45="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!C:C,G14:G45,''02_TRANSACCIONES''!B:B,"ingreso")))')) },
  @{ range='00_PANEL!I14'; values=@(@('=ARRAYFORMULA(IF(G14:G45="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!C:C,G14:G45,''02_TRANSACCIONES''!B:B,"gasto")))')) },
  @{ range='00_PANEL!J14'; values=@(@('=ARRAYFORMULA(IF(G14:G45="","",H14:H45+I14:I45))')) },
  @{ range='00_PANEL!K14'; values=@(@('=ARRAYFORMULA(IF(G14:G45="","",COUNTIFS(''02_TRANSACCIONES''!C:C,G14:G45)))')) },

  @{ range='00_PANEL!A62:L62'; values=@(@('BLOQUE IA RECOMENDACIONES CONTABLES - ARTES BUHO','','','','','','','','','','','')) },
  @{ range='00_PANEL!A63'; values=@(@('IA ACTIVA: recomendaciones automaticas por caja, riesgo y escenarios. Para resumen Gemini usa el menu IA de App Script.')) },
  @{ range='00_PANEL!A64:H64'; values=@(@('BLOQUE','RECOMENDACION IA','','','','','INDICADOR IA','VALOR')) },
  @{ range='00_PANEL!A65:A72'; values=@(
    @('DIAGNOSTICO IA'),@('RIESGO PRINCIPAL'),@('OPORTUNIDAD CLAVE'),@('ACCION 1 (48H)'),@('ACCION 2 (72H)'),@('ACCION 3 (7 DIAS)'),@('ACCION 4 (7 DIAS)'),@('ALERTA IA')
  ) },
  @{ range='00_PANEL!B65:B72'; values=@(
    @('=IF(B6>=0,"Negocio en positivo: mantener disciplina y proteger margen.","Negocio en tension: activar plan de caja inmediato.")'),
    @('=IF(B7<-15000,"Pendientes altos: riesgo de tension de tesoreria.","Riesgo moderado: mantener control diario de pendientes.")'),
    @('=IF(B10>=0.75,"Alta trazabilidad operativa: acelerar crecimiento rentable.","Mejorar calidad operativa para escalar sin friccion.")'),
    @('=IF(B7<0,"Prioriza cobros pendientes > 7 dias y confirma estado hoy.","Mantener disciplina de cierre diario de movimientos.")'),
    @('=IF(B5<-ABS(B4)*0.7,"Reducir gastos variables 8-12% en linea menos rentable.","Sostener gasto actual y reinvertir en linea con mejor margen.")'),
    @('=IF(H67<0,"Activar modo defensivo: congelar gasto no critico 7 dias.","Escenario pesimista estable: ejecutar crecimiento selectivo.")'),
    @('=IF(H65>H66,"Escenario optimista supera base: acelerar captacion comercial.","Refinar pricing y mix de servicios para elevar ticket medio.")'),
    @('=IF(H72>=70,"ALERTA ALTA: foco en caja y control de gasto.","ALERTA CONTROLADA: continuar plan con seguimiento semanal.")')
  ) },
  @{ range='00_PANEL!G65:G72'; values=@(
    @('CAJA 12M OPTIMISTA'),@('CAJA 12M BASE'),@('CAJA 12M PESIMISTA'),@('RESULTADO NETO'),@('PENDIENTE VALIDAR'),@('RATIO CONFIRMADAS'),@('MARGEN NETO'),@('RIESGO SCORE IA')
  ) },
  @{ range='00_PANEL!H65:H72'; values=@(
    @('=IFERROR(INDEX(FILTER(''03_ESCENARIOS''!F:F,''03_ESCENARIOS''!A:A="optimista",''03_ESCENARIOS''!B:B=12),1),0)'),
    @('=IFERROR(INDEX(FILTER(''03_ESCENARIOS''!F:F,''03_ESCENARIOS''!A:A="base",''03_ESCENARIOS''!B:B=12),1),0)'),
    @('=IFERROR(INDEX(FILTER(''03_ESCENARIOS''!F:F,''03_ESCENARIOS''!A:A="pesimista",''03_ESCENARIOS''!B:B=12),1),0)'),
    @('=B6'),@('=B7'),@('=B10'),@('=IF(B4=0,0,B6/B4)'),@('=MAX(0,MIN(100,ROUND(IF(H67<0,85,35)+IF(B7<-10000,15,0)+IF(B10<0.6,10,0),0)))')
  ) },
  @{ range='04_AUDITORIA!A1:E1'; values=@(@('timestamp','severidad','regla','detalle','valor')) },
  @{ range='04_AUDITORIA!A2:E12'; values=@(
    @('=NOW()','ALTA','signo_gasto','Gastos con importe positivo','=COUNTIFS(''02_TRANSACCIONES''!B:B,"gasto",''02_TRANSACCIONES''!H:H,">0")'),
    @('=NOW()','ALTA','signo_ingreso','Ingresos con importe negativo','=COUNTIFS(''02_TRANSACCIONES''!B:B,"ingreso",''02_TRANSACCIONES''!H:H,"<0")'),
    @('=NOW()','MEDIA','sin_linea','Transacciones sin linea de negocio','=COUNTIFS(''02_TRANSACCIONES''!A2:A,"<>",''02_TRANSACCIONES''!C2:C,"")'),
    @('=NOW()','MEDIA','sin_categoria','Transacciones sin categoria','=COUNTIFS(''02_TRANSACCIONES''!A2:A,"<>",''02_TRANSACCIONES''!D2:D,"")'),
    @('=NOW()','MEDIA','sin_concepto','Transacciones sin concepto','=COUNTIFS(''02_TRANSACCIONES''!A2:A,"<>",''02_TRANSACCIONES''!F2:F,"")'),
    @('=NOW()','MEDIA','sin_estado','Transacciones sin estado','=COUNTIFS(''02_TRANSACCIONES''!A2:A,"<>",''02_TRANSACCIONES''!I2:I,"")'),
    @('=NOW()','MEDIA','pendientes_altos','Pendientes > 20k EUR','=COUNTIFS(''02_TRANSACCIONES''!I:I,"pendiente",''02_TRANSACCIONES''!H:H,">20000")'),
    @('=NOW()','MEDIA','sin_fecha','Transacciones sin fecha','=COUNTIFS(''02_TRANSACCIONES''!B2:B,"<>",''02_TRANSACCIONES''!A2:A,"")'),
    @('=NOW()','INFO','tx_totales','Total transacciones','=COUNTA(''02_TRANSACCIONES''!A2:A)'),
    @('=NOW()','INFO','lineas_activas','Lineas negocio activas','=COUNTA(UNIQUE(FILTER(''02_TRANSACCIONES''!C2:C,''02_TRANSACCIONES''!C2:C<>"")))'),
    @('=NOW()','INFO','actualizado','Ultimo recalculo','=NOW()')
  ) },

  @{ range='98_LOG!A1:D1'; values=@(@('timestamp','nivel','mensaje','meta')) },
  @{ range='98_LOG!A2:D2'; values=@(@('=NOW()','INFO','Inicializacion sistema contable IA','build remoto')) }
)

$dataPrepared = @()
foreach($d in $data){
  $rows = $d.values
  $vals2d = New-Object System.Collections.ArrayList

  if ($rows -is [System.Array] -and $rows.Count -gt 0 -and ($rows[0] -is [System.Array])) {
    foreach($r in $rows){
      [void]$vals2d.Add([object[]]$r)
    }
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

$valueBody = @{
  valueInputOption = 'USER_ENTERED'
  data = $dataPrepared
}
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values:batchUpdate" -f $SpreadsheetId) -Token $token -Body $valueBody | Out-Null

# Visual formatting + validation + protections + charts
$panelId = [int]$sheetMap['00_PANEL']
$inputId = [int]$sheetMap['01_ENTRADA']
$txId = [int]$sheetMap['02_TRANSACCIONES']
$scenarioId = [int]$sheetMap['03_ESCENARIOS']
$auditId = [int]$sheetMap['04_AUDITORIA']
$configId = [int]$sheetMap['99_CONFIG']
$logId = [int]$sheetMap['98_LOG']

$requests = @(
  @{ mergeCells = @{ range = @{ sheetId=$inputId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=8 }; mergeType='MERGE_ALL' } },
  @{ mergeCells = @{ range = @{ sheetId=$inputId; startRowIndex=1; endRowIndex=2; startColumnIndex=0; endColumnIndex=8 }; mergeType='MERGE_ALL' } },
  @{ mergeCells = @{ range = @{ sheetId=$panelId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=12 }; mergeType='MERGE_ALL' } },

  @{ repeatCell = @{ range=@{ sheetId=$inputId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true; fontSize=16 }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } },
  @{ repeatCell = @{ range=@{ sheetId=$inputId; startRowIndex=1; endRowIndex=2; startColumnIndex=0; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.83;blue=0.00} }; textFormat=@{ bold=$true }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } },
  @{ repeatCell = @{ range=@{ sheetId=$inputId; startRowIndex=3; endRowIndex=14; startColumnIndex=0; endColumnIndex=1 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.996;green=0.886;blue=0.886} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$inputId; startRowIndex=3; endRowIndex=14; startColumnIndex=1; endColumnIndex=2 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.95;blue=0.75} } } }; fields='userEnteredFormat(backgroundColorStyle)' } },

  @{ repeatCell = @{ range=@{ sheetId=$txId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=11 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },

  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true; fontSize=18 }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=1; endRowIndex=2; startColumnIndex=0; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.83;blue=0.00} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=3; endRowIndex=10; startColumnIndex=0; endColumnIndex=1 }; cell=@{ userEnteredFormat=@{ textFormat=@{ bold=$true }; backgroundColorStyle=@{ rgbColor=@{red=0.95;green=0.95;blue=0.95} } } }; fields='userEnteredFormat(textFormat,backgroundColorStyle)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=3; endRowIndex=10; startColumnIndex=1; endColumnIndex=2 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=9; endRowIndex=10; startColumnIndex=1; endColumnIndex=2 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='PERCENT'; pattern='0.00%' } } }; fields='userEnteredFormat.numberFormat' } },

  @{ repeatCell = @{ range=@{ sheetId=$scenarioId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=6 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$scenarioId; startRowIndex=1; endRowIndex=38; startColumnIndex=2; endColumnIndex=6 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },

  @{ repeatCell = @{ range=@{ sheetId=$auditId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=5 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },

  @{ repeatCell = @{ range=@{ sheetId=$configId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=3 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$logId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=4 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },

  @{ setDataValidation = @{ range=@{ sheetId=$inputId; startRowIndex=4; endRowIndex=5; startColumnIndex=1; endColumnIndex=2 }; rule=@{ condition=@{ type='ONE_OF_LIST'; values=@(@{userEnteredValue='ingreso'},@{userEnteredValue='gasto'}) }; strict=$true; showCustomUi=$true } } },
  @{ setDataValidation = @{ range=@{ sheetId=$inputId; startRowIndex=11; endRowIndex=12; startColumnIndex=1; endColumnIndex=2 }; rule=@{ condition=@{ type='ONE_OF_LIST'; values=@(@{userEnteredValue='pendiente'},@{userEnteredValue='confirmado'},@{userEnteredValue='cancelado'}) }; strict=$true; showCustomUi=$true } } },

  @{ setDataValidation = @{ range=@{ sheetId=$txId; startRowIndex=1; endRowIndex=5000; startColumnIndex=1; endColumnIndex=2 }; rule=@{ condition=@{ type='ONE_OF_LIST'; values=@(@{userEnteredValue='ingreso'},@{userEnteredValue='gasto'}) }; strict=$true; showCustomUi=$true } } },
  @{ setDataValidation = @{ range=@{ sheetId=$txId; startRowIndex=1; endRowIndex=5000; startColumnIndex=8; endColumnIndex=9 }; rule=@{ condition=@{ type='ONE_OF_LIST'; values=@(@{userEnteredValue='pendiente'},@{userEnteredValue='confirmado'},@{userEnteredValue='cancelado'}) }; strict=$true; showCustomUi=$true } } },

  @{ addProtectedRange = @{ protectedRange=@{ range=@{ sheetId=$inputId; startRowIndex=0; endRowIndex=40; startColumnIndex=0; endColumnIndex=8 }; description='ENTRADA_USUARIO_EDITABLE_CON_AVISO'; warningOnly=$true } } },
  @{ addProtectedRange = @{ protectedRange=@{ range=@{ sheetId=$panelId; startRowIndex=0; endRowIndex=140; startColumnIndex=0; endColumnIndex=12 }; description='PANEL_BLOQUEADO_SOLO_VISUALIZACION'; warningOnly=$false } } },
  @{ addProtectedRange = @{ protectedRange=@{ range=@{ sheetId=$scenarioId; startRowIndex=0; endRowIndex=120; startColumnIndex=0; endColumnIndex=12 }; description='ESCENARIOS_BLOQUEADO_SOLO_VISUALIZACION'; warningOnly=$false } } },
  @{ addProtectedRange = @{ protectedRange=@{ range=@{ sheetId=$auditId; startRowIndex=0; endRowIndex=3000; startColumnIndex=0; endColumnIndex=8 }; description='AUDITORIA_BLOQUEADA_SOLO_VISUALIZACION'; warningOnly=$false } } },
  @{ addProtectedRange = @{ protectedRange=@{ range=@{ sheetId=$configId; startRowIndex=0; endRowIndex=200; startColumnIndex=0; endColumnIndex=6 }; description='CONFIG_BLOQUEADA_SOLO_VISUALIZACION'; warningOnly=$false } } },

  @{ addConditionalFormatRule = @{ index=0; rule=@{ ranges=@(@{ sheetId=$txId; startRowIndex=1; endRowIndex=5000; startColumnIndex=0; endColumnIndex=11 }); booleanRule=@{ condition=@{ type='CUSTOM_FORMULA'; values=@(@{userEnteredValue='=$B2="ingreso"'}) }; format=@{ backgroundColorStyle=@{ rgbColor=@{red=0.93;green=0.98;blue=0.94} } } } } } },
  @{ addConditionalFormatRule = @{ index=0; rule=@{ ranges=@(@{ sheetId=$txId; startRowIndex=1; endRowIndex=5000; startColumnIndex=0; endColumnIndex=11 }); booleanRule=@{ condition=@{ type='CUSTOM_FORMULA'; values=@(@{userEnteredValue='=$B2="gasto"'}) }; format=@{ backgroundColorStyle=@{ rgbColor=@{red=0.996;green=0.91;blue=0.91} } } } } } },

  @{ addChart = @{ chart=@{ spec=@{ title='Evolucion mensual ingresos/gastos/resultado'; basicChart=@{ chartType='LINE'; legendPosition='BOTTOM_LEGEND'; headerCount=1; domains=@(@{ domain=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=0; endColumnIndex=1 }) } } }); series=@(@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=1; endColumnIndex=2 }) } } },@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=2; endColumnIndex=3 }) } } },@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=3; endColumnIndex=4 }) } } }) } }; position=@{ overlayPosition=@{ anchorCell=@{ sheetId=$panelId; rowIndex=2; columnIndex=2 }; offsetXPixels=10; offsetYPixels=10; widthPixels=530; heightPixels=300 } } } } },
  @{ addChart = @{ chart=@{ spec=@{ title='Resultado por linea de negocio'; basicChart=@{ chartType='COLUMN'; legendPosition='BOTTOM_LEGEND'; headerCount=1; domains=@(@{ domain=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=6; endColumnIndex=7 }) } } }); series=@(@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=9; endColumnIndex=10 }) } } }) } }; position=@{ overlayPosition=@{ anchorCell=@{ sheetId=$panelId; rowIndex=2; columnIndex=8 }; offsetXPixels=10; offsetYPixels=10; widthPixels=320; heightPixels=300 } } } } },
  @{ addChart = @{ chart=@{ spec=@{ title='Peso ingresos por linea'; pieChart=@{ legendPosition='RIGHT_LEGEND'; domain=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=6; endColumnIndex=7 }) } }; series=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=12; endRowIndex=60; startColumnIndex=7; endColumnIndex=8 }) } } } }; position=@{ overlayPosition=@{ anchorCell=@{ sheetId=$panelId; rowIndex=38; columnIndex=2 }; offsetXPixels=10; offsetYPixels=10; widthPixels=520; heightPixels=320 } } } } },
  @{ addChart = @{ chart=@{ spec=@{ title='Escenarios de caja (12 meses)'; basicChart=@{ chartType='LINE'; legendPosition='BOTTOM_LEGEND'; headerCount=1; domains=@(@{ domain=@{ sourceRange=@{ sources=@(@{ sheetId=$scenarioId; startRowIndex=1; endRowIndex=37; startColumnIndex=1; endColumnIndex=2 }) } } }); series=@(@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$scenarioId; startRowIndex=1; endRowIndex=13; startColumnIndex=5; endColumnIndex=6 }) } } },@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$scenarioId; startRowIndex=13; endRowIndex=25; startColumnIndex=5; endColumnIndex=6 }) } } },@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$scenarioId; startRowIndex=25; endRowIndex=37; startColumnIndex=5; endColumnIndex=6 }) } } }) } }; position=@{ overlayPosition=@{ anchorCell=@{ sheetId=$scenarioId; rowIndex=1; columnIndex=7 }; offsetXPixels=10; offsetYPixels=10; widthPixels=420; heightPixels=300 } } } } }
)

# AI recommendation block layout (rows 62-72)
$requests += @{ mergeCells = @{ range = @{ sheetId=$panelId; startRowIndex=61; endRowIndex=62; startColumnIndex=0; endColumnIndex=12 }; mergeType='MERGE_ALL' } }
$requests += @{ mergeCells = @{ range = @{ sheetId=$panelId; startRowIndex=62; endRowIndex=63; startColumnIndex=0; endColumnIndex=12 }; mergeType='MERGE_ALL' } }
$requests += @{ mergeCells = @{ range = @{ sheetId=$panelId; startRowIndex=63; endRowIndex=64; startColumnIndex=1; endColumnIndex=6 }; mergeType='MERGE_ALL' } }
for($r=64; $r -le 71; $r++){
  $requests += @{ mergeCells = @{ range = @{ sheetId=$panelId; startRowIndex=$r; endRowIndex=($r+1); startColumnIndex=1; endColumnIndex=6 }; mergeType='MERGE_ALL' } }
}

$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=61; endRowIndex=62; startColumnIndex=0; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true; fontSize=13 }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=62; endRowIndex=63; startColumnIndex=0; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.83;blue=0.00} }; textFormat=@{ bold=$true }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=63; endRowIndex=64; startColumnIndex=0; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.96;green=0.90;blue=0.90} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=64; endRowIndex=72; startColumnIndex=0; endColumnIndex=1 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.996;green=0.886;blue=0.886} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=64; endRowIndex=72; startColumnIndex=1; endColumnIndex=6 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; wrapStrategy='WRAP'; verticalAlignment='TOP' } }; fields='userEnteredFormat(backgroundColorStyle,wrapStrategy,verticalAlignment)' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=64; endRowIndex=72; startColumnIndex=6; endColumnIndex=7 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.95;blue=0.75} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=64; endRowIndex=69; startColumnIndex=7; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=69; endRowIndex=71; startColumnIndex=7; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='PERCENT'; pattern='0.00%' } } }; fields='userEnteredFormat.numberFormat' } }
$requests += @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=71; endRowIndex=72; startColumnIndex=7; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='0' }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(numberFormat,textFormat)' } }
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null

# Column widths for readability
$resizeReq = @()
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$inputId; dimension='COLUMNS'; startIndex=0; endIndex=1 }; properties=@{ pixelSize=330 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$inputId; dimension='COLUMNS'; startIndex=1; endIndex=2 }; properties=@{ pixelSize=320 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$panelId; dimension='COLUMNS'; startIndex=0; endIndex=12 }; properties=@{ pixelSize=130 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$txId; dimension='COLUMNS'; startIndex=0; endIndex=11 }; properties=@{ pixelSize=140 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$panelId; dimension='ROWS'; startIndex=61; endIndex=64 }; properties=@{ pixelSize=32 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$panelId; dimension='ROWS'; startIndex=64; endIndex=72 }; properties=@{ pixelSize=42 }; fields='pixelSize' } }
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $resizeReq } | Out-Null

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  spreadsheetTitle = $meta.properties.title
  coreSheets = $core.name
  timestamp = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 8






