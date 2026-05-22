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
  $uri = "https://sheets.googleapis.com/v4/spreadsheets/{0}?fields=spreadsheetId,properties(title),sheets(properties(sheetId,title,index,hidden,gridProperties),charts,protectedRanges(protectedRangeId,description,warningOnly))" -f $Id
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

$requests = @()
if (-not $sheetMap.ContainsKey('07_LINEAS_NEGOCIO')) {
  $requests += @{
    addSheet = @{
      properties = @{
        title = '07_LINEAS_NEGOCIO'
        gridProperties = @{ rowCount = 220; columnCount = 8; frozenRowCount = 1 }
        tabColorStyle = @{ rgbColor = @{red=1.00;green=0.83;blue=0.00} }
      }
    }
  }
}
if (-not $sheetMap.ContainsKey('08_CATALOGO_CATEGORIAS')) {
  $requests += @{
    addSheet = @{
      properties = @{
        title = '08_CATALOGO_CATEGORIAS'
        gridProperties = @{ rowCount = 400; columnCount = 8; frozenRowCount = 1 }
        tabColorStyle = @{ rgbColor = @{red=0.95;green=0.75;blue=0.15} }
      }
    }
  }
}

if ($requests.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null
  $meta = Get-Meta -Id $SpreadsheetId -Token $token
  $sheetMap = Get-SheetMap -Meta $meta
}

$panelId = [int]$sheetMap['00_PANEL']
$inputId = [int]$sheetMap['01_ENTRADA']
$txId = [int]$sheetMap['02_TRANSACCIONES']
$auditId = [int]$sheetMap['04_AUDITORIA']
$linesId = [int]$sheetMap['07_LINEAS_NEGOCIO']
$catId = [int]$sheetMap['08_CATALOGO_CATEGORIAS']

$requests = @()
$managedChartTitles = @('Resultado por linea de negocio','Peso ingresos por linea')
foreach($sh in $meta.sheets){
  if ($sh.charts) {
    foreach($ch in $sh.charts){
      $title = [string]$ch.spec.title
      if ($managedChartTitles -contains $title) {
        $requests += @{ deleteEmbeddedObject = @{ objectId = [int]$ch.chartId } }
      }
    }
  }

  if (([string]$sh.properties.title -in @('07_LINEAS_NEGOCIO','08_CATALOGO_CATEGORIAS')) -and $sh.protectedRanges) {
    foreach($pr in $sh.protectedRanges){
      $requests += @{ deleteProtectedRange = @{ protectedRangeId = [int]$pr.protectedRangeId } }
    }
  }
}
if ($requests.Count -gt 0) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null
}

foreach($range in @(
  '07_LINEAS_NEGOCIO!A1:H220',
  '08_CATALOGO_CATEGORIAS!A1:H400',
  '00_PANEL!G13:L45',
  '00_PANEL!A94:L140',
  '01_ENTRADA!D2:E120',
  '04_AUDITORIA!A13:E15'
)){
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId, [uri]::EscapeDataString($range)) -Token $token -Body @{} | Out-Null
}

$data = @(
  @{ range='07_LINEAS_NEGOCIO!A1:H1'; values=@(@('linea_negocio','clasificacion','foco','prioridad','objetivo_mensual','responsable','estado','nota')) },
  @{ range='07_LINEAS_NEGOCIO!A2:H6'; values=@(
    @('Escuela','Formacion musical','Ensenanza de instrumentos','ALTA',12000,'Direccion Escuela','activa','Escuela de ensenanza musical'),
    @('Management','Servicios a artistas','Desarrollo de bandas','ALTA',9000,'Direccion Management','activa','Gestion integral para bandas'),
    @('Ticket Buo','Ticketing','Venta de entradas','ALTA',14000,'Operacion Ticketing','activa','Ticketera propia'),
    @('Sala Bella Bestia','Exhibicion musical','Conciertos y eventos','ALTA',11000,'Produccion Sala','activa','Sala de conciertos propia'),
    @('Discografica','Produccion musical','Lanzamientos y catalogo','MEDIA',5000,'Direccion Artistica','activa','Discografica en desarrollo')
  ) },

  @{ range='08_CATALOGO_CATEGORIAS!A1:D1'; values=@(@('linea_negocio','categoria','subcategoria','estado')) },
  @{ range='08_CATALOGO_CATEGORIAS!A2:D34'; values=@(
    @('Escuela','Formacion','Matricula','activa'),
    @('Escuela','Formacion','Mensualidad','activa'),
    @('Escuela','Formacion','Bono intensivo','activa'),
    @('Escuela','Operacion','Material didactico','activa'),
    @('Escuela','Personal','Profesorado','activa'),
    @('Escuela','Marketing','Captacion alumnos','activa'),

    @('Management','Servicios','Comision management','activa'),
    @('Management','Servicios','Booking artistas','activa'),
    @('Management','Servicios','Produccion de gira','activa'),
    @('Management','Operacion','Viajes y dietas','activa'),
    @('Management','Marketing','Promocion artistas','activa'),
    @('Management','Legal','Contratos','activa'),

    @('Ticket Buo','Entradas','Venta online','activa'),
    @('Ticket Buo','Entradas','Fee de servicio','activa'),
    @('Ticket Buo','Entradas','Abonos','activa'),
    @('Ticket Buo','Operacion','Pasarela de pago','activa'),
    @('Ticket Buo','Operacion','Soporte ticketing','activa'),
    @('Ticket Buo','Marketing','Campanas de conversion','activa'),

    @('Sala Bella Bestia','Taquilla','Venta en puerta','activa'),
    @('Sala Bella Bestia','Barra','Consumiciones','activa'),
    @('Sala Bella Bestia','Alquiler','Alquiler de sala','activa'),
    @('Sala Bella Bestia','Personal','Tecnica y sala','activa'),
    @('Sala Bella Bestia','Operacion','Sonido e iluminacion','activa'),
    @('Sala Bella Bestia','Operacion','Seguridad y limpieza','activa'),

    @('Discografica','Distribucion','Ingresos plataformas','activa'),
    @('Discografica','Derechos','Royalties','activa'),
    @('Discografica','Produccion','Grabacion','activa'),
    @('Discografica','Produccion','Mezcla y mastering','activa'),
    @('Discografica','Marketing','Lanzamiento','activa'),
    @('Discografica','Operacion','Fabricacion y merch','activa'),

    @('General','Finanzas','Comisiones bancarias','activa'),
    @('General','Fiscal','Impuestos','activa'),
    @('General','Operacion','Software','activa')
  ) },
  @{ range='08_CATALOGO_CATEGORIAS!F1:G1'; values=@(@('categorias_globales','subcategorias_globales')) },
  @{ range='08_CATALOGO_CATEGORIAS!F2'; values=@(@('=SORT(UNIQUE(FILTER(B2:B,D2:D="activa")))')) },
  @{ range='08_CATALOGO_CATEGORIAS!G2'; values=@(@('=SORT(UNIQUE(FILTER(C2:C,D2:D="activa")))')) },

  @{ range='01_ENTRADA!D2'; values=@(@('=SORT(UNIQUE(FILTER(''08_CATALOGO_CATEGORIAS''!B:B,''08_CATALOGO_CATEGORIAS''!A:A=B6,''08_CATALOGO_CATEGORIAS''!D:D="activa")))')) },
  @{ range='01_ENTRADA!E2'; values=@(@('=SORT(UNIQUE(FILTER(''08_CATALOGO_CATEGORIAS''!C:C,''08_CATALOGO_CATEGORIAS''!A:A=B6,''08_CATALOGO_CATEGORIAS''!B:B=B7,''08_CATALOGO_CATEGORIAS''!D:D="activa")))')) },

  @{ range='00_PANEL!A94:L94'; values=@(@('RADAR Y KPI POR LINEAS DE NEGOCIO','','','','','','','','','','','')) },
  @{ range='00_PANEL!A95:F95'; values=@(@('Linea de negocio','Clasificacion','Ingresos','Gastos','Resultado','N mov.')) },
  @{ range='00_PANEL!A96'; values=@(@('=IFERROR(SORT(UNIQUE(FILTER(''02_TRANSACCIONES''!C2:C,''02_TRANSACCIONES''!C2:C<>""))),"")')) },
  @{ range='00_PANEL!B96'; values=@(@('=ARRAYFORMULA(IF(A96:A127="","",IFERROR(VLOOKUP(A96:A127,''07_LINEAS_NEGOCIO''!A:B,2,false),"Sin clasificar")))')) },
  @{ range='00_PANEL!C96'; values=@(@('=ARRAYFORMULA(IF(A96:A127="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!C:C,A96:A127,''02_TRANSACCIONES''!B:B,"ingreso")))')) },
  @{ range='00_PANEL!D96'; values=@(@('=ARRAYFORMULA(IF(A96:A127="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!C:C,A96:A127,''02_TRANSACCIONES''!B:B,"gasto")))')) },
  @{ range='00_PANEL!E96'; values=@(@('=ARRAYFORMULA(IF(A96:A127="","",C96:C127+D96:D127))')) },
  @{ range='00_PANEL!F96'; values=@(@('=ARRAYFORMULA(IF(A96:A127="","",COUNTIFS(''02_TRANSACCIONES''!C:C,A96:A127)))')) },

  @{ range='00_PANEL!G95:L95'; values=@(@('Linea','Objetivo mes','Ingresos mes','Desvio','Pendiente','Margen %')) },
  @{ range='00_PANEL!G96'; values=@(@('=ARRAYFORMULA(A96:A127)')) },
  @{ range='00_PANEL!H96'; values=@(@('=ARRAYFORMULA(IF(G96:G127="","",IFERROR(VLOOKUP(G96:G127,''07_LINEAS_NEGOCIO''!A:E,5,false),0)))')) },
  @{ range='00_PANEL!I96'; values=@(@('=ARRAYFORMULA(IF(G96:G127="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!C:C,G96:G127,''02_TRANSACCIONES''!B:B,"ingreso",TEXT(''02_TRANSACCIONES''!A:A,"yyyy-mm"),TEXT(TODAY(),"yyyy-mm"))))')) },
  @{ range='00_PANEL!J96'; values=@(@('=ARRAYFORMULA(IF(G96:G127="","",I96:I127-H96:H127))')) },
  @{ range='00_PANEL!K96'; values=@(@('=ARRAYFORMULA(IF(G96:G127="","",SUMIFS(''02_TRANSACCIONES''!H:H,''02_TRANSACCIONES''!C:C,G96:G127,''02_TRANSACCIONES''!I:I,"pendiente")))')) },
  @{ range='00_PANEL!L96'; values=@(@('=ARRAYFORMULA(IF(G96:G127="","",IF(C96:C127=0,0,E96:E127/C96:C127)))')) },
  @{ range='00_PANEL!A132:L132'; values=@(@('IA SEMANAL POR LINEA - RECOMENDACIONES','','','','','','','','','','','')) },
  @{ range='00_PANEL!A133:L133'; values=@(@('Bloque IA de bajo consumo API: recomendaciones por formula y prompt listo para Gemini','','','','','','','','','','','')) },
  @{ range='00_PANEL!A134:F134'; values=@(@('Linea','Resultado','Pendiente','Margen','Riesgo IA','Recomendacion semanal')) },
  @{ range='00_PANEL!H134'; values=@(@('Prompt Gemini por linea')) },
  @{ range='00_PANEL!A135'; values=@(@('=ARRAY_CONSTRAIN(SORT(FILTER({$G$96:$G$127,$K$96:$K$127},$G$96:$G$127<>""),2,true),4,1)')) },
  @{ range='00_PANEL!B135'; values=@(@('=ARRAYFORMULA(IF(A135:A138="","",IFERROR(VLOOKUP(A135:A138,A96:E127,5,false),0)))')) },
  @{ range='00_PANEL!C135'; values=@(@('=ARRAYFORMULA(IF(A135:A138="","",IFERROR(VLOOKUP(A135:A138,G96:K127,5,false),0)))')) },
  @{ range='00_PANEL!D135'; values=@(@('=ARRAYFORMULA(IF(A135:A138="","",IFERROR(VLOOKUP(A135:A138,G96:L127,6,false),0)))')) },
  @{ range='00_PANEL!E135'; values=@(@('=ARRAYFORMULA(IF(A135:A138="","",IF((C135:C138<-5000)+(D135:D138<0.15)+(B135:B138<0)>1,"ALTO",IF((C135:C138<-2000)+(D135:D138<0.25)+(B135:B138<0)>0,"MEDIO","CONTROLADO"))))')) },
  @{ range='00_PANEL!F135'; values=@(@('=ARRAYFORMULA(IF(A135:A138="","",IF(E135:E138="ALTO","Accion 7 dias: priorizar cobros, recortar gasto variable y frenar pagos no criticos.",IF(E135:E138="MEDIO","Accion 7 dias: revisar pricing y acelerar ventas de mejor margen.","Accion 7 dias: mantener plan y escalar captacion."))))')) },
  @{ range='00_PANEL!H135'; values=@(@('=ARRAYFORMULA(IF(A135:A138="","","Analiza la linea "&A135:A138&". Resultado="&TEXT(B135:B138,"#,##0.00")&", Pendiente="&TEXT(C135:C138,"#,##0.00")&", Margen="&TEXT(D135:D138,"0.00%")&". Dame 3 acciones semanales concretas."))')) },

  @{ range='04_AUDITORIA!A13:E15'; values=@(
    @('=NOW()','ALTA','linea_no_catalogada','Lineas sin clasificacion en catalogo','=SUMPRODUCT(--(''02_TRANSACCIONES''!C2:C5000<>""),--ISNA(MATCH(''02_TRANSACCIONES''!C2:C5000,''07_LINEAS_NEGOCIO''!A2:A200,0)))'),
    @('=NOW()','ALTA','categoria_no_valida','Categoria no valida para su linea','=SUMPRODUCT(--(''02_TRANSACCIONES''!C2:C5000<>""),--(''02_TRANSACCIONES''!D2:D5000<>""),--ISNA(MATCH(''02_TRANSACCIONES''!C2:C5000&"|"&''02_TRANSACCIONES''!D2:D5000,FILTER(''08_CATALOGO_CATEGORIAS''!A2:A400&"|"&''08_CATALOGO_CATEGORIAS''!B2:B400,''08_CATALOGO_CATEGORIAS''!D2:D400="activa"),0)))'),
    @('=NOW()','ALTA','subcategoria_no_valida','Subcategoria no valida para su linea/categoria','=SUMPRODUCT(--(''02_TRANSACCIONES''!C2:C5000<>""),--(''02_TRANSACCIONES''!D2:D5000<>""),--(''02_TRANSACCIONES''!E2:E5000<>""),--ISNA(MATCH(''02_TRANSACCIONES''!C2:C5000&"|"&''02_TRANSACCIONES''!D2:D5000&"|"&''02_TRANSACCIONES''!E2:E5000,FILTER(''08_CATALOGO_CATEGORIAS''!A2:A400&"|"&''08_CATALOGO_CATEGORIAS''!B2:B400&"|"&''08_CATALOGO_CATEGORIAS''!C2:C400,''08_CATALOGO_CATEGORIAS''!D2:D400="activa"),0)))')
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

$requests = @(
  @{ repeatCell = @{ range=@{ sheetId=$linesId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$linesId; startRowIndex=1; endRowIndex=220; startColumnIndex=4; endColumnIndex=5 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$catId; startRowIndex=0; endRowIndex=1; startColumnIndex=0; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },

  @{ setDataValidation = @{ range=@{ sheetId=$inputId; startRowIndex=5; endRowIndex=6; startColumnIndex=1; endColumnIndex=2 }; rule=@{ condition=@{ type='ONE_OF_RANGE'; values=@(@{userEnteredValue='=07_LINEAS_NEGOCIO!$A$2:$A$200'}) }; strict=$true; showCustomUi=$true } } },
  @{ setDataValidation = @{ range=@{ sheetId=$inputId; startRowIndex=6; endRowIndex=7; startColumnIndex=1; endColumnIndex=2 }; rule=@{ condition=@{ type='ONE_OF_RANGE'; values=@(@{userEnteredValue='=01_ENTRADA!$D$2:$D$120'}) }; strict=$true; showCustomUi=$true } } },
  @{ setDataValidation = @{ range=@{ sheetId=$inputId; startRowIndex=7; endRowIndex=8; startColumnIndex=1; endColumnIndex=2 }; rule=@{ condition=@{ type='ONE_OF_RANGE'; values=@(@{userEnteredValue='=01_ENTRADA!$E$2:$E$120'}) }; strict=$true; showCustomUi=$true } } },

  @{ setDataValidation = @{ range=@{ sheetId=$txId; startRowIndex=1; endRowIndex=5000; startColumnIndex=2; endColumnIndex=3 }; rule=@{ condition=@{ type='ONE_OF_RANGE'; values=@(@{userEnteredValue='=07_LINEAS_NEGOCIO!$A$2:$A$200'}) }; strict=$true; showCustomUi=$true } } },
  @{ setDataValidation = @{ range=@{ sheetId=$txId; startRowIndex=1; endRowIndex=5000; startColumnIndex=3; endColumnIndex=4 }; rule=@{ condition=@{ type='ONE_OF_RANGE'; values=@(@{userEnteredValue='=08_CATALOGO_CATEGORIAS!$F$2:$F$400'}) }; strict=$true; showCustomUi=$true } } },
  @{ setDataValidation = @{ range=@{ sheetId=$txId; startRowIndex=1; endRowIndex=5000; startColumnIndex=4; endColumnIndex=5 }; rule=@{ condition=@{ type='ONE_OF_RANGE'; values=@(@{userEnteredValue='=08_CATALOGO_CATEGORIAS!$G$2:$G$400'}) }; strict=$true; showCustomUi=$true } } },

  @{ addProtectedRange = @{ protectedRange=@{ range=@{ sheetId=$linesId; startRowIndex=0; endRowIndex=220; startColumnIndex=0; endColumnIndex=8 }; description='LINEAS_NEGOCIO_EDITABLE_CON_AVISO'; warningOnly=$true } } },
  @{ addProtectedRange = @{ protectedRange=@{ range=@{ sheetId=$catId; startRowIndex=0; endRowIndex=400; startColumnIndex=0; endColumnIndex=8 }; description='CATALOGO_CATEGORIAS_EDITABLE_CON_AVISO'; warningOnly=$true } } },

  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=93; endRowIndex=94; startColumnIndex=0; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true; fontSize=13 }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=94; endRowIndex=95; startColumnIndex=0; endColumnIndex=6 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.83;blue=0.00} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=94; endRowIndex=95; startColumnIndex=6; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.83;blue=0.00} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=95; endRowIndex=128; startColumnIndex=2; endColumnIndex=5 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=95; endRowIndex=128; startColumnIndex=7; endColumnIndex=11 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=95; endRowIndex=128; startColumnIndex=11; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='PERCENT'; pattern='0.00%' } } }; fields='userEnteredFormat.numberFormat' } },

  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=131; endRowIndex=132; startColumnIndex=0; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.70;green=0.00;blue=0.00} }; textFormat=@{ foregroundColorStyle=@{ rgbColor=@{red=1;green=1;blue=1} }; bold=$true; fontSize=13 }; horizontalAlignment='CENTER' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,horizontalAlignment)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=132; endRowIndex=133; startColumnIndex=0; endColumnIndex=12 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.83;blue=0.00} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=133; endRowIndex=134; startColumnIndex=0; endColumnIndex=6 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=0.96;green=0.90;blue=0.90} }; textFormat=@{ bold=$true } } }; fields='userEnteredFormat(backgroundColorStyle,textFormat)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=133; endRowIndex=138; startColumnIndex=7; endColumnIndex=8 }; cell=@{ userEnteredFormat=@{ backgroundColorStyle=@{ rgbColor=@{red=1.00;green=0.95;blue=0.75} }; textFormat=@{ bold=$true }; wrapStrategy='WRAP' } }; fields='userEnteredFormat(backgroundColorStyle,textFormat,wrapStrategy)' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=134; endRowIndex=138; startColumnIndex=1; endColumnIndex=3 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='NUMBER'; pattern='#,##0.00' } } }; fields='userEnteredFormat.numberFormat' } },
  @{ repeatCell = @{ range=@{ sheetId=$panelId; startRowIndex=134; endRowIndex=138; startColumnIndex=3; endColumnIndex=4 }; cell=@{ userEnteredFormat=@{ numberFormat=@{ type='PERCENT'; pattern='0.00%' } } }; fields='userEnteredFormat.numberFormat' } },

  @{ addChart = @{ chart=@{ spec=@{ title='Resultado por linea de negocio'; basicChart=@{ chartType='COLUMN'; legendPosition='BOTTOM_LEGEND'; headerCount=1; domains=@(@{ domain=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=94; endRowIndex=128; startColumnIndex=0; endColumnIndex=1 }) } } }); series=@(@{ series=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=94; endRowIndex=128; startColumnIndex=4; endColumnIndex=5 }) } } }) } }; position=@{ overlayPosition=@{ anchorCell=@{ sheetId=$panelId; rowIndex=2; columnIndex=8 }; offsetXPixels=10; offsetYPixels=10; widthPixels=320; heightPixels=300 } } } } },
  @{ addChart = @{ chart=@{ spec=@{ title='Peso ingresos por linea'; pieChart=@{ legendPosition='RIGHT_LEGEND'; domain=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=94; endRowIndex=128; startColumnIndex=0; endColumnIndex=1 }) } }; series=@{ sourceRange=@{ sources=@(@{ sheetId=$panelId; startRowIndex=94; endRowIndex=128; startColumnIndex=2; endColumnIndex=3 }) } } } }; position=@{ overlayPosition=@{ anchorCell=@{ sheetId=$panelId; rowIndex=38; columnIndex=2 }; offsetXPixels=10; offsetYPixels=10; widthPixels=520; heightPixels=320 } } } } }
)

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $requests } | Out-Null

$resizeReq = @()
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$linesId; dimension='COLUMNS'; startIndex=0; endIndex=8 }; properties=@{ pixelSize=180 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$catId; dimension='COLUMNS'; startIndex=0; endIndex=8 }; properties=@{ pixelSize=170 }; fields='pixelSize' } }
$resizeReq += @{ updateDimensionProperties=@{ range=@{ sheetId=$panelId; dimension='ROWS'; startIndex=131; endIndex=138 }; properties=@{ pixelSize=34 }; fields='pixelSize' } }
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{ requests = $resizeReq } | Out-Null

$out = [ordered]@{
  ok = $true
  spreadsheetId = $SpreadsheetId
  updatedBlocks = @(
    '07_LINEAS_NEGOCIO catalogo',
    '08_CATALOGO_CATEGORIAS',
    '00_PANEL radar+kpi+ia semanal',
    'validaciones desplegable linea/categoria/subcategoria',
    'auditoria linea/categoria/subcategoria no valida'
  )
  timestamp = (Get-Date).ToString('o')
}
$out | ConvertTo-Json -Depth 8





