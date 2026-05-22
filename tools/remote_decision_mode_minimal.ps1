param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json',
  [switch]$RefreshOnly
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

function Get-PythonCommand {
  $cmd = Get-Command python -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
  throw 'Python no encontrado.'
}

function Get-AccessToken {
  param([string]$ServiceAccountKey)
  $helper = Join-Path $PSScriptRoot 'get_service_account_access_token.js'
  if (-not (Test-Path -LiteralPath $ServiceAccountKey)) { throw ('No existe key: ' + $ServiceAccountKey) }
  $token = ''
  try {
    if (-not (Test-Path -LiteralPath $helper)) { throw ('No existe helper: ' + $helper) }
    $nodeCmd = Get-NodeCommand
    $token = & $nodeCmd $helper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
  } catch {
    $pyHelper = Join-Path $PSScriptRoot 'get_service_account_access_token.py'
    if (-not (Test-Path -LiteralPath $pyHelper)) { throw }
    $pythonCmd = Get-PythonCommand
    $token = & $pythonCmd $pyHelper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
  }
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) { throw 'No se pudo obtener token' }
  return [string]$token
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

function Invoke-GApi {
  param([ValidateSet('GET','POST')][string]$Method,[string]$Uri,[string]$Token,$Body=$null)
  $headers = @{ Authorization = ('Bearer ' + $Token) }
  $maxRetries = 6
  $baseDelayMs = 650

  for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
    try {
      if ($Method -eq 'GET') { return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers -ErrorAction Stop }
      $json = if ($null -eq $Body) { '{}' } else { $Body | ConvertTo-Json -Depth 80 }
      return Invoke-RestMethod -Method Post -Uri $Uri -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -ErrorAction Stop
    } catch {
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
        throw ('API_ERROR: ' + $Uri + ' -> status=' + $statusCode + ' body=' + $txt)
      }
      throw
    }
  }
}

function Get-Values {
  param([string]$Range,[string]$Token)
  $uri = ('https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}?valueRenderOption=FORMATTED_VALUE' -f $SpreadsheetId, [uri]::EscapeDataString($Range))
  $res = Invoke-GApi -Method GET -Uri $uri -Token $Token
  if ($res.values) { return @($res.values) }
  return @()
}

function ToNum { param($v)
  if ($null -eq $v) { return 0.0 }
  if ($v -is [double] -or $v -is [int] -or $v -is [decimal] -or $v -is [long]) { return [double]$v }
  $t = ([string]$v).Trim(); if ([string]::IsNullOrWhiteSpace($t)) { return 0.0 }
  $t = $t -replace '[^0-9,\.\-]',''
  if ($t.Contains(',') -and $t.Contains('.')) {
    if ($t.LastIndexOf(',') -gt $t.LastIndexOf('.')) { $t = $t.Replace('.','').Replace(',','.') } else { $t = $t.Replace(',','') }
  } elseif ($t.Contains(',')) { $t = $t.Replace('.','').Replace(',','.') }
  try { return [double]::Parse($t,[Globalization.CultureInfo]::InvariantCulture) } catch { return 0.0 }
}

function ToMonth { param($v)
  if ($null -eq $v) { return '' }
  if ($v -is [DateTime]) { return ([DateTime]$v).ToString('yyyy-MM') }
  if ($v -is [double] -or $v -is [int] -or $v -is [long]) {
    $n=[double]$v; if ($n -gt 25000 -and $n -lt 70000) { try { return ([DateTime]::FromOADate($n)).ToString('yyyy-MM') } catch {} }
  }
  $t=([string]$v).Trim(); if ($t -match '^\d{4}-\d{2}$') { return $t }
  if ($t -match '^\d{4}-\d{2}-\d{2}$') { return $t.Substring(0,7) }
  if ($t -match '^\d{2}/\d{2}/\d{4}$') { try { return ([DateTime]::ParseExact($t,'dd/MM/yyyy',[Globalization.CultureInfo]::InvariantCulture)).ToString('yyyy-MM') } catch {} }
  try { return ([DateTime]::Parse($t,[Globalization.CultureInfo]::GetCultureInfo('es-ES'))).ToString('yyyy-MM') } catch { return '' }
}

function Norm { param([string]$s)
  $x = ([string]$s).ToLowerInvariant()
  if ($x -match 'escuela') { return 'Escuela' }
  if ($x -match 'management') { return 'Management' }
  if ($x -match 'ticket|tiquet|buho|buo') { return 'Ticket Buho' }
  if ($x -match 'bella|sala') { return 'Sala Bella Bestia' }
  if ($x -match 'discog') { return 'Discografica' }
  if ($x -match 'event|booking') { return 'Eventos' }
  return ((Get-Culture).TextInfo.ToTitleCase($x.Trim()))
}

function Goal { param([string]$line)
  switch ($line) {
    'Escuela' { 12000.0 }
    'Management' { 9000.0 }
    'Ticket Buho' { 14000.0 }
    'Sala Bella Bestia' { 11000.0 }
    'Discografica' { 5000.0 }
    'Eventos' { 8000.0 }
    default { 10000.0 }
  }
}

$officialLines = @('Escuela','Management','Ticket Buho','Sala Bella Bestia','Discografica','Eventos')
$panelMaxRows = 62
$panelMaxCols = 12
$inputMaxRows = 90
$inputMaxCols = 8
$guideMaxRows = 26
$guideMaxCols = 7
$inputUiRows = 18
$inputAutoVisualRows = 11

function Get-SampleIncome {
  param([string]$line)
  switch ($line) {
    'Escuela' { return 16000.0 }
    'Management' { return 11000.0 }
    'Ticket Buho' { return 14000.0 }
    'Sala Bella Bestia' { return 12000.0 }
    'Discografica' { return 7000.0 }
    'Eventos' { return 10000.0 }
    default { return 9000.0 }
  }
}

function Get-SampleExpense {
  param([string]$line)
  switch ($line) {
    'Escuela' { return 9800.0 }
    'Management' { return 7600.0 }
    'Ticket Buho' { return 9200.0 }
    'Sala Bella Bestia' { return 9100.0 }
    'Discografica' { return 5200.0 }
    'Eventos' { return 6800.0 }
    default { return 6200.0 }
  }
}

function AddAgg { param([hashtable]$map,[string]$m,[string]$l,[double]$i,[double]$g,[double]$o,[string]$n)
  if ([string]::IsNullOrWhiteSpace($m) -or [string]::IsNullOrWhiteSpace($l)) { return }
  $k = $m + '|' + $l
  if (-not $map.ContainsKey($k)) { $map[$k] = [ordered]@{m=$m;l=$l;i=0.0;g=0.0;o=(Goal $l);n=''} }
  $it = $map[$k]; $it.i=[Math]::Round($it.i+$i,2); $it.g=[Math]::Round($it.g+$g,2)
  if ($o -gt 0) { $it.o=$o }
  if (-not [string]::IsNullOrWhiteSpace($n) -and [string]::IsNullOrWhiteSpace([string]$it.n)) { $it.n=$n.Trim() }
}

function AddFmt { param([System.Collections.Generic.List[object]]$req,[int]$sid,[int]$r1,[int]$r2,[int]$c1,[int]$c2,[hashtable]$fmt,[string]$fields)
  if ($fmt.ContainsKey('textFormat')) {
    if (-not $fmt.textFormat.ContainsKey('fontFamily') -or [string]::IsNullOrWhiteSpace([string]$fmt.textFormat.fontFamily)) {
      $fmt.textFormat.fontFamily = 'Montserrat'
    }
    if (-not $fmt.textFormat.ContainsKey('fontSize') -or [int]$fmt.textFormat.fontSize -le 0) {
      $fmt.textFormat.fontSize = 10
    }
  }
  $fieldMask = (($fields -split ',') | ForEach-Object { 'userEnteredFormat.' + $_.Trim() }) -join ','
  $req.Add(@{repeatCell=@{range=@{sheetId=$sid;startRowIndex=$r1;endRowIndex=$r2;startColumnIndex=$c1;endColumnIndex=$c2};cell=@{userEnteredFormat=$fmt};fields=$fieldMask}}) | Out-Null
}

function AddGridBorders { param([System.Collections.Generic.List[object]]$req,[int]$sid,[int]$r1,[int]$r2,[int]$c1,[int]$c2)
  $line = @{ style = 'SOLID'; color = @{ red = 0.75; green = 0.75; blue = 0.75 } }
  $req.Add(@{
    updateBorders = @{
      range = @{ sheetId = $sid; startRowIndex = $r1; endRowIndex = $r2; startColumnIndex = $c1; endColumnIndex = $c2 }
      top = $line
      bottom = $line
      left = $line
      right = $line
      innerHorizontal = $line
      innerVertical = $line
    }
  }) | Out-Null
}

$token = Get-AccessToken -ServiceAccountKey $ServiceAccountKeyPath
$serviceAccountEmail = ''
try {
  $serviceAccountEmail = [string]((Get-Content -LiteralPath $ServiceAccountKeyPath -Raw | ConvertFrom-Json).client_email)
} catch {}
$metaFields = 'properties(locale,timeZone),sheets(properties(sheetId,title,hidden,gridProperties),charts(chartId),conditionalFormats,protectedRanges(protectedRangeId,description,warningOnly,range))'
$meta = Invoke-GApi -Method GET -Uri ("https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}") -Token $token

$map = @{}; foreach ($s in $meta.sheets) { $map[[string]$s.properties.title] = [int]$s.properties.sheetId }
if (-not $map.ContainsKey('00_PANEL') -or -not $map.ContainsKey('01_ENTRADA')) { throw 'Faltan hojas 00_PANEL y 01_ENTRADA' }
if (-not $map.ContainsKey('00_GUIA_USO')) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{
    requests = @(
      @{
        addSheet = @{
          properties = @{
            title = '00_GUIA_USO'
            gridProperties = @{
              rowCount = 90
              columnCount = 10
            }
          }
        }
      }
    )
  } | Out-Null
  $meta = Invoke-GApi -Method GET -Uri ("https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}") -Token $token
  $map = @{}; foreach ($s in $meta.sheets) { $map[[string]$s.properties.title] = [int]$s.properties.sheetId }
}
if (-not $map.ContainsKey('99_CONFIG')) {
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{
    requests = @(
      @{
        addSheet = @{
          properties = @{
            title = '99_CONFIG'
            hidden = $true
            gridProperties = @{
              rowCount = 120
              columnCount = 12
            }
          }
        }
      }
    )
  } | Out-Null
  $meta = Invoke-GApi -Method GET -Uri ("https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}") -Token $token
  $map = @{}; foreach ($s in $meta.sheets) { $map[[string]$s.properties.title] = [int]$s.properties.sheetId }
}
$sidPanel = $map['00_PANEL']; $sidInput = $map['01_ENTRADA']; $sidGuide = $map['00_GUIA_USO']; $sidConfig = $map['99_CONFIG']; $visible = @('00_PANEL','01_ENTRADA','00_GUIA_USO')

if ($RefreshOnly) {
  $rq = New-Object 'System.Collections.Generic.List[object]'
  foreach ($s in $meta.sheets) {
    $rq.Add(@{updateSheetProperties=@{properties=@{sheetId=[int]$s.properties.sheetId;hidden=(-not ($visible -contains [string]$s.properties.title));gridProperties=@{hideGridlines=$true}};fields='hidden,gridProperties.hideGridlines'}}) | Out-Null
  }
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{requests=$rq} | Out-Null
  Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{valueInputOption='USER_ENTERED';data=@(@{range='00_PANEL!A2';values=@(,@('="Actualizado: "&TEXT(NOW();"dd/mm/yyyy hh:mm:ss")&" | Solo editas 01_ENTRADA"'))})} | Out-Null
  [ordered]@{ok=$true;mode='refresh_only';spreadsheetId=$SpreadsheetId;updatedAt=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 8
  return
}

$ag=@{}; $det=0
foreach ($r in (Get-Values -Range ("01_ENTRADA!A5:H{0}" -f $inputMaxRows) -Token $token)) {
  $m=if($r.Count -gt 0){ToMonth $r[0]}else{''}; $l=if($r.Count -gt 1){Norm ([string]$r[1])}else{''}
  if (-not [string]::IsNullOrWhiteSpace($m) -and -not [string]::IsNullOrWhiteSpace($l)) {
    $iv = if($r.Count -gt 2){ToNum $r[2]}else{0.0}
    $gv = if($r.Count -gt 3){ToNum $r[3]}else{0.0}
    $ov = if($r.Count -gt 4){ToNum $r[4]}else{0.0}
    $nv = if($r.Count -gt 7){[string]$r[7]}else{''}
    AddAgg $ag $m $l $iv $gv $ov $nv
    $det++
  }
}

$fromTx=0
if ($det -eq 0 -and $map.ContainsKey('02_TRANSACCIONES')) {
  foreach ($r in (Get-Values -Range '02_TRANSACCIONES!A2:J4000' -Token $token)) {
    $m=if($r.Count -gt 0){ToMonth $r[0]}else{''}; $l=if($r.Count -gt 2){Norm ([string]$r[2])}else{''}
    if ([string]::IsNullOrWhiteSpace($m) -or [string]::IsNullOrWhiteSpace($l)) { continue }
    $imp=if($r.Count -gt 7){ToNum $r[7]}else{0.0}; $tipo=if($r.Count -gt 1){([string]$r[1]).ToLowerInvariant()}else{''}; $n=if($r.Count -gt 5){[string]$r[5]}else{''}
    if ($tipo -like '*gasto*' -or $imp -lt 0) { AddAgg $ag $m $l 0.0 ([Math]::Abs($imp)) (Goal $l) $n } else { AddAgg $ag $m $l ([Math]::Abs($imp)) 0.0 (Goal $l) $n }
    $fromTx++
  }
}

$items=@($ag.Values)
$latestMonth = ''
if ($items.Count -gt 0) {
  $latestMonth = ($items | Sort-Object @{Expression={ [string]$_.m };Ascending=$false} | Select-Object -First 1).m
}
if ([string]::IsNullOrWhiteSpace($latestMonth)) {
  $latestMonth = (Get-Date).ToString('yyyy-MM')
}

$inputMainRows = New-Object System.Collections.Generic.List[object]
$inputNoteRows = New-Object System.Collections.Generic.List[object]
foreach ($ln in $officialLines) {
  $k = $latestMonth + '|' + $ln
  if ($ag.ContainsKey($k)) {
    $it = $ag[$k]
    $inputMainRows.Add(@([string]$latestMonth,[string]$ln,[double]$it.i,[double]$it.g,[double]$it.o)) | Out-Null
    $inputNoteRows.Add(@([string]$it.n)) | Out-Null
  }
  else {
    $inputMainRows.Add(@([string]$latestMonth,[string]$ln,[double](Get-SampleIncome $ln),[double](Get-SampleExpense $ln),[double](Goal $ln))) | Out-Null
    $inputNoteRows.Add(@('Ejemplo ficticio')) | Out-Null
  }
}

$req = New-Object 'System.Collections.Generic.List[object]'
$req.Add(@{updateSpreadsheetProperties=@{properties=@{locale='es_ES';timeZone='Europe/Madrid'};fields='locale,timeZone'}}) | Out-Null
foreach ($s in $meta.sheets) {
  $req.Add(@{updateSheetProperties=@{properties=@{sheetId=[int]$s.properties.sheetId;hidden=(-not ($visible -contains [string]$s.properties.title));gridProperties=@{hideGridlines=$true}};fields='hidden,gridProperties.hideGridlines'}}) | Out-Null
}

function AddTrimGrid {
  param(
    [System.Collections.Generic.List[object]]$ReqList,
    [object]$SheetMeta,
    [int]$TargetRows,
    [int]$TargetCols
  )
  if ($null -eq $SheetMeta -or $null -eq $SheetMeta.properties -or $null -eq $SheetMeta.properties.gridProperties) { return }
  $sid = [int]$SheetMeta.properties.sheetId
  $curRows = [int]$SheetMeta.properties.gridProperties.rowCount
  $curCols = [int]$SheetMeta.properties.gridProperties.columnCount
  if ($curRows -gt $TargetRows) {
    $ReqList.Add(@{
      deleteDimension = @{
        range = @{
          sheetId = $sid
          dimension = 'ROWS'
          startIndex = $TargetRows
          endIndex = $curRows
        }
      }
    }) | Out-Null
  }
  if ($curCols -gt $TargetCols) {
    $ReqList.Add(@{
      deleteDimension = @{
        range = @{
          sheetId = $sid
          dimension = 'COLUMNS'
          startIndex = $TargetCols
          endIndex = $curCols
        }
      }
    }) | Out-Null
  }
}

$panelMeta = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sidPanel } | Select-Object -First 1
$inputMeta = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sidInput } | Select-Object -First 1
$guideMeta = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sidGuide } | Select-Object -First 1
$configMeta = $meta.sheets | Where-Object { [int]$_.properties.sheetId -eq $sidConfig } | Select-Object -First 1
AddTrimGrid -ReqList $req -SheetMeta $panelMeta -TargetRows $panelMaxRows -TargetCols $panelMaxCols
AddTrimGrid -ReqList $req -SheetMeta $inputMeta -TargetRows $inputMaxRows -TargetCols $inputMaxCols
AddTrimGrid -ReqList $req -SheetMeta $guideMeta -TargetRows $guideMaxRows -TargetCols $guideMaxCols
AddTrimGrid -ReqList $req -SheetMeta $configMeta -TargetRows 120 -TargetCols 12

$req.Add(@{updateSheetProperties=@{properties=@{sheetId=$sidPanel;gridProperties=@{frozenRowCount=2;rowCount=$panelMaxRows;columnCount=$panelMaxCols}};fields='gridProperties.frozenRowCount,gridProperties.rowCount,gridProperties.columnCount'}}) | Out-Null
$req.Add(@{updateSheetProperties=@{properties=@{sheetId=$sidInput;gridProperties=@{frozenRowCount=4;rowCount=$inputMaxRows;columnCount=$inputMaxCols}};fields='gridProperties.frozenRowCount,gridProperties.rowCount,gridProperties.columnCount'}}) | Out-Null
$req.Add(@{updateSheetProperties=@{properties=@{sheetId=$sidGuide;gridProperties=@{frozenRowCount=2;rowCount=$guideMaxRows;columnCount=$guideMaxCols}};fields='gridProperties.frozenRowCount,gridProperties.rowCount,gridProperties.columnCount'}}) | Out-Null
$req.Add(@{updateSheetProperties=@{properties=@{sheetId=$sidConfig;hidden=$true;gridProperties=@{rowCount=120;columnCount=12}};fields='hidden,gridProperties.rowCount,gridProperties.columnCount'}}) | Out-Null

# Base visual corporativa: tipografia unica y tamano coherente en hojas visibles
$req.Add(@{
  repeatCell = @{
    range = @{ sheetId = $sidPanel; startRowIndex = 0; endRowIndex = $panelMaxRows; startColumnIndex = 0; endColumnIndex = $panelMaxCols }
    cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat'; fontSize = 11 } } }
    fields = 'userEnteredFormat.textFormat.fontFamily,userEnteredFormat.textFormat.fontSize'
  }
}) | Out-Null
$req.Add(@{
  repeatCell = @{
    range = @{ sheetId = $sidInput; startRowIndex = 0; endRowIndex = $inputMaxRows; startColumnIndex = 0; endColumnIndex = $inputMaxCols }
    cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat'; fontSize = 11 } } }
    fields = 'userEnteredFormat.textFormat.fontFamily,userEnteredFormat.textFormat.fontSize'
  }
}) | Out-Null
$req.Add(@{
  repeatCell = @{
    range = @{ sheetId = $sidGuide; startRowIndex = 0; endRowIndex = $guideMaxRows; startColumnIndex = 0; endColumnIndex = $guideMaxCols }
    cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat'; fontSize = 11 } } }
    fields = 'userEnteredFormat.textFormat.fontFamily,userEnteredFormat.textFormat.fontSize'
  }
}) | Out-Null

for($i=0;$i -lt 12;$i++){ $w=@(180,150,170,250,170,150,250,240,170,170,360,120)[$i]; $req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='COLUMNS';startIndex=$i;endIndex=($i+1)};properties=@{pixelSize=$w};fields='pixelSize'}}) | Out-Null }
for($i=0;$i -lt 8;$i++){ $w=@(150,230,170,170,180,170,140,380)[$i]; $req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidInput;dimension='COLUMNS';startIndex=$i;endIndex=($i+1)};properties=@{pixelSize=$w};fields='pixelSize'}}) | Out-Null }
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=0;endIndex=1};properties=@{pixelSize=48};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=1;endIndex=2};properties=@{pixelSize=32};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=2;endIndex=$panelMaxRows};properties=@{pixelSize=26};fields='pixelSize'}}) | Out-Null
for($r=30;$r -lt 32;$r++){ $req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=$r;endIndex=($r+1)};properties=@{pixelSize=34};fields='pixelSize'}}) | Out-Null }
for($r=32;$r -lt 38;$r++){ $req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=$r;endIndex=($r+1)};properties=@{pixelSize=42};fields='pixelSize'}}) | Out-Null }
for($r=40;$r -lt 46;$r++){ $req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=$r;endIndex=($r+1)};properties=@{pixelSize=38};fields='pixelSize'}}) | Out-Null }
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=38;endIndex=39};properties=@{pixelSize=34};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=39;endIndex=40};properties=@{pixelSize=30};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=46;endIndex=47};properties=@{pixelSize=34};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidPanel;dimension='ROWS';startIndex=47;endIndex=48};properties=@{pixelSize=38};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidInput;dimension='ROWS';startIndex=0;endIndex=1};properties=@{pixelSize=48};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidInput;dimension='ROWS';startIndex=1;endIndex=4};properties=@{pixelSize=32};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidInput;dimension='ROWS';startIndex=4;endIndex=$inputMaxRows};properties=@{pixelSize=26};fields='pixelSize'}}) | Out-Null
for($i=0;$i -lt 7;$i++){ $w=@(130,300,230,120,240,180,270)[$i]; $req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidGuide;dimension='COLUMNS';startIndex=$i;endIndex=($i+1)};properties=@{pixelSize=$w};fields='pixelSize'}}) | Out-Null }
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidGuide;dimension='ROWS';startIndex=0;endIndex=2};properties=@{pixelSize=38};fields='pixelSize'}}) | Out-Null
$req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidGuide;dimension='ROWS';startIndex=2;endIndex=$guideMaxRows};properties=@{pixelSize=32};fields='pixelSize'}}) | Out-Null

foreach ($sheetMeta in $meta.sheets) {
  if (-not $sheetMeta.charts) { continue }
  $sheetTitle = [string]$sheetMeta.properties.title
  $sheetId = [int]$sheetMeta.properties.sheetId
  $isVisible = ($visible -contains $sheetTitle)
  $shouldPurgeCharts = (($sheetId -eq $sidPanel) -or (-not $isVisible))
  if ($shouldPurgeCharts) {
    foreach ($ch in $sheetMeta.charts) {
      $req.Add(@{deleteEmbeddedObject=@{objectId=[int]$ch.chartId}}) | Out-Null
    }
  }
}

$req.Add(@{unmergeCells=@{range=@{sheetId=$sidPanel;startRowIndex=0;endRowIndex=$panelMaxRows;startColumnIndex=0;endColumnIndex=$panelMaxCols}}}) | Out-Null
$req.Add(@{unmergeCells=@{range=@{sheetId=$sidInput;startRowIndex=0;endRowIndex=$inputMaxRows;startColumnIndex=0;endColumnIndex=$inputMaxCols}}}) | Out-Null
$req.Add(@{unmergeCells=@{range=@{sheetId=$sidGuide;startRowIndex=0;endRowIndex=$guideMaxRows;startColumnIndex=0;endColumnIndex=$guideMaxCols}}}) | Out-Null
$merges = @(
  @{sid=$sidPanel;r1=0;r2=1;c1=0;c2=12},@{sid=$sidPanel;r1=1;r2=2;c1=0;c2=12},
  @{sid=$sidPanel;r1=3;r2=4;c1=0;c2=3},@{sid=$sidPanel;r1=3;r2=4;c1=3;c2=6},@{sid=$sidPanel;r1=3;r2=4;c1=6;c2=9},@{sid=$sidPanel;r1=3;r2=4;c1=9;c2=12},
  @{sid=$sidPanel;r1=4;r2=6;c1=0;c2=3},@{sid=$sidPanel;r1=4;r2=6;c1=3;c2=6},@{sid=$sidPanel;r1=4;r2=6;c1=6;c2=9},@{sid=$sidPanel;r1=4;r2=6;c1=9;c2=12},
  @{sid=$sidPanel;r1=7;r2=8;c1=0;c2=12},
  @{sid=$sidPanel;r1=30;r2=31;c1=0;c2=8},@{sid=$sidPanel;r1=30;r2=31;c1=8;c2=11},
  @{sid=$sidPanel;r1=38;r2=39;c1=0;c2=12},
  @{sid=$sidPanel;r1=46;r2=47;c1=0;c2=12},@{sid=$sidPanel;r1=47;r2=48;c1=0;c2=12},
  @{sid=$sidInput;r1=0;r2=1;c1=0;c2=8},@{sid=$sidInput;r1=1;r2=2;c1=0;c2=8},@{sid=$sidInput;r1=2;r2=3;c1=0;c2=8},
  @{sid=$sidInput;r1=11;r2=12;c1=0;c2=5},@{sid=$sidInput;r1=11;r2=13;c1=7;c2=8},
  @{sid=$sidGuide;r1=0;r2=1;c1=0;c2=7},@{sid=$sidGuide;r1=1;r2=2;c1=0;c2=7},
  @{sid=$sidGuide;r1=3;r2=4;c1=0;c2=7},@{sid=$sidGuide;r1=13;r2=14;c1=0;c2=7},
  @{sid=$sidGuide;r1=19;r2=20;c1=0;c2=7},@{sid=$sidGuide;r1=20;r2=21;c1=0;c2=7},@{sid=$sidGuide;r1=21;r2=22;c1=0;c2=7},@{sid=$sidGuide;r1=22;r2=23;c1=0;c2=7},@{sid=$sidGuide;r1=23;r2=24;c1=0;c2=7}
)
foreach($m in $merges){ $req.Add(@{mergeCells=@{range=@{sheetId=$m.sid;startRowIndex=$m.r1;endRowIndex=$m.r2;startColumnIndex=$m.c1;endColumnIndex=$m.c2};mergeType='MERGE_ALL'}}) | Out-Null }

foreach($s in $meta.sheets){
  $sid=[int]$s.properties.sheetId
  if($sid -ne $sidPanel -and $sid -ne $sidInput -and $sid -ne $sidGuide){continue}
  if($s.conditionalFormats){ for($i=0;$i -lt $s.conditionalFormats.Count;$i++){ $req.Add(@{deleteConditionalFormatRule=@{sheetId=$sid;index=0}}) | Out-Null } }
  if($s.protectedRanges){ foreach($pr in $s.protectedRanges){ $psid=$null; try{$psid=[int]$pr.range.sheetId}catch{}; if($psid -eq $sid){ $req.Add(@{deleteProtectedRange=@{protectedRangeId=[int]$pr.protectedRangeId}}) | Out-Null } } }
}

$panelEditors = @()
if (-not [string]::IsNullOrWhiteSpace($serviceAccountEmail)) {
  $panelEditors += $serviceAccountEmail
}
# Bloqueo fuerte del panel/guia:
# el robot queda como editor explicito.
# Google puede conservar al propietario del archivo como editor por politica interna.

$req.Add(@{
  addProtectedRange = @{
    protectedRange = @{
      description = 'DECISION_MODE_PANEL'
      warningOnly = $false
      range = @{ sheetId = $sidPanel; startRowIndex = 0; endRowIndex = $panelMaxRows; startColumnIndex = 0; endColumnIndex = $panelMaxCols }
      editors = @{ users = $panelEditors }
    }
  }
}) | Out-Null

$req.Add(@{
  addProtectedRange = @{
    protectedRange = @{
      description = 'DECISION_MODE_INPUT_HEADERS'
      warningOnly = $false
      range = @{ sheetId = $sidInput; startRowIndex = 0; endRowIndex = 4; startColumnIndex = 0; endColumnIndex = $inputMaxCols }
      editors = @{ users = $panelEditors }
    }
  }
}) | Out-Null

$req.Add(@{
  addProtectedRange = @{
    protectedRange = @{
      description = 'DECISION_MODE_INPUT_FORMULAS'
      warningOnly = $false
      range = @{ sheetId = $sidInput; startRowIndex = 4; endRowIndex = $inputMaxRows; startColumnIndex = 5; endColumnIndex = 7 }
      editors = @{ users = $panelEditors }
    }
  }
}) | Out-Null

$req.Add(@{
  addProtectedRange = @{
    protectedRange = @{
      description = 'DECISION_MODE_INPUT_BOTON'
      warningOnly = $false
      range = @{ sheetId = $sidInput; startRowIndex = 11; endRowIndex = 13; startColumnIndex = 7; endColumnIndex = 8 }
      editors = @{ users = $panelEditors }
    }
  }
}) | Out-Null

$req.Add(@{
  addProtectedRange = @{
    protectedRange = @{
      description = 'DECISION_MODE_GUIDE'
      warningOnly = $false
      range = @{ sheetId = $sidGuide; startRowIndex = 0; endRowIndex = $guideMaxRows; startColumnIndex = 0; endColumnIndex = $guideMaxCols }
      editors = @{ users = $panelEditors }
    }
  }
}) | Out-Null

$baseMask = 'userEnteredFormat.backgroundColor,userEnteredFormat.textFormat,userEnteredFormat.horizontalAlignment,userEnteredFormat.verticalAlignment,userEnteredFormat.wrapStrategy'
$baseFmt = @{
  backgroundColor = @{ red = 1; green = 1; blue = 1 }
  textFormat = @{ fontFamily = 'Montserrat'; fontSize = 10; foregroundColor = @{ red = 0.10; green = 0.11; blue = 0.12 } }
  horizontalAlignment = 'LEFT'
  verticalAlignment = 'MIDDLE'
  wrapStrategy = 'CLIP'
}
$req.Add(@{repeatCell=@{range=@{sheetId=$sidPanel;startRowIndex=0;endRowIndex=$panelMaxRows;startColumnIndex=0;endColumnIndex=$panelMaxCols};cell=@{userEnteredFormat=$baseFmt};fields=$baseMask}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidInput;startRowIndex=0;endRowIndex=$inputMaxRows;startColumnIndex=0;endColumnIndex=$inputMaxCols};cell=@{userEnteredFormat=$baseFmt};fields=$baseMask}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidGuide;startRowIndex=0;endRowIndex=$guideMaxRows;startColumnIndex=0;endColumnIndex=$guideMaxCols};cell=@{userEnteredFormat=$baseFmt};fields=$baseMask}}) | Out-Null

AddFmt -req $req -sid $sidPanel -r1 0 -r2 1 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1};fontFamily='Montserrat';fontSize=18};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 1 -r2 2 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true;fontFamily='Montserrat'}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidPanel -r1 3 -r2 4 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=0.98;green=0.89;blue=0.89};textFormat=@{bold=$true;fontFamily='Montserrat'};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 4 -r2 6 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=1.00;green=0.97;blue=0.80};textFormat=@{bold=$true;fontFamily='Montserrat';fontSize=15};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 7 -r2 8 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1};fontFamily='Montserrat'};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 8 -r2 9 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true;fontFamily='Montserrat'};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 30 -r2 31 -c1 0 -c2 8 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1}};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 30 -r2 31 -c1 8 -c2 11 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1}};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 31 -r2 32 -c1 0 -c2 8 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 31 -r2 32 -c1 8 -c2 11 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 32 -r2 38 -c1 0 -c2 8 -fmt @{backgroundColor=@{red=0.86;green=0.96;blue=0.88};textFormat=@{bold=$false};horizontalAlignment='LEFT'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 32 -r2 35 -c1 8 -c2 11 -fmt @{backgroundColor=@{red=0.86;green=0.96;blue=0.88};textFormat=@{bold=$false};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 31 -r2 32 -c1 0 -c2 11 -fmt @{wrapStrategy='WRAP';verticalAlignment='MIDDLE'} -fields 'wrapStrategy,verticalAlignment'
AddFmt -req $req -sid $sidPanel -r1 38 -r2 39 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1}};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 39 -r2 40 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 32 -r2 38 -c1 6 -c2 8 -fmt @{wrapStrategy='WRAP';verticalAlignment='MIDDLE'} -fields 'wrapStrategy,verticalAlignment'
AddFmt -req $req -sid $sidPanel -r1 40 -r2 46 -c1 3 -c2 4 -fmt @{wrapStrategy='WRAP';verticalAlignment='MIDDLE'} -fields 'wrapStrategy,verticalAlignment'
AddFmt -req $req -sid $sidPanel -r1 40 -r2 46 -c1 0 -c2 5 -fmt @{verticalAlignment='MIDDLE'} -fields 'verticalAlignment'
AddFmt -req $req -sid $sidPanel -r1 46 -r2 47 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1}};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 47 -r2 48 -c1 0 -c2 12 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true};horizontalAlignment='CENTER';wrapStrategy='WRAP'} -fields 'backgroundColor,textFormat,horizontalAlignment,wrapStrategy'
AddFmt -req $req -sid $sidPanel -r1 32 -r2 35 -c1 10 -c2 11 -fmt @{wrapStrategy='WRAP';verticalAlignment='MIDDLE';horizontalAlignment='LEFT'} -fields 'wrapStrategy,verticalAlignment,horizontalAlignment'
AddFmt -req $req -sid $sidPanel -r1 32 -r2 35 -c1 8 -c2 11 -fmt @{verticalAlignment='MIDDLE'} -fields 'verticalAlignment'

AddFmt -req $req -sid $sidInput -r1 0 -r2 1 -c1 0 -c2 8 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1};fontFamily='Montserrat';fontSize=16};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidInput -r1 1 -r2 2 -c1 0 -c2 8 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidInput -r1 2 -r2 3 -c1 0 -c2 8 -fmt @{backgroundColor=@{red=0.98;green=0.89;blue=0.89};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidInput -r1 3 -r2 4 -c1 0 -c2 8 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1}};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidInput -r1 4 -r2 $inputUiRows -c1 0 -c2 5 -fmt @{backgroundColor=@{red=1.00;green=0.97;blue=0.80}} -fields 'backgroundColor'
AddFmt -req $req -sid $sidInput -r1 4 -r2 $inputAutoVisualRows -c1 5 -c2 7 -fmt @{backgroundColor=@{red=0.95;green=0.95;blue=0.95};textFormat=@{bold=$true}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidInput -r1 $inputAutoVisualRows -r2 $inputUiRows -c1 5 -c2 7 -fmt @{backgroundColor=@{red=1.00;green=0.97;blue=0.80};textFormat=@{bold=$false}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidInput -r1 4 -r2 $inputUiRows -c1 7 -c2 8 -fmt @{backgroundColor=@{red=1.00;green=0.97;blue=0.80}} -fields 'backgroundColor'
AddFmt -req $req -sid $sidInput -r1 11 -r2 12 -c1 0 -c2 5 -fmt @{backgroundColor=@{red=1.00;green=0.95;blue=0.78};textFormat=@{bold=$true}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidInput -r1 11 -r2 13 -c1 7 -c2 8 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1};fontSize=12};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidGuide -r1 0 -r2 1 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1};fontFamily='Montserrat';fontSize=16};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidGuide -r1 1 -r2 2 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidGuide -r1 3 -r2 4 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1}};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidGuide -r1 4 -r2 14 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=0.99;green=0.95;blue=0.95};textFormat=@{fontFamily='Montserrat'}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidGuide -r1 13 -r2 14 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=0.70;green=0.00;blue=0.00};textFormat=@{bold=$true;foregroundColor=@{red=1;green=1;blue=1}};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidGuide -r1 14 -r2 15 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=1.00;green=0.83;blue=0.00};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
AddFmt -req $req -sid $sidGuide -r1 15 -r2 16 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=0.86;green=0.96;blue=0.88};textFormat=@{bold=$true}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidGuide -r1 16 -r2 17 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=0.99;green=0.95;blue=0.78};textFormat=@{bold=$true}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidGuide -r1 17 -r2 18 -c1 0 -c2 7 -fmt @{backgroundColor=@{red=0.99;green=0.89;blue=0.89};textFormat=@{bold=$true}} -fields 'backgroundColor,textFormat'
AddFmt -req $req -sid $sidGuide -r1 5 -r2 13 -c1 0 -c2 1 -fmt @{backgroundColor=@{red=1.00;green=0.95;blue=0.78};textFormat=@{bold=$true};horizontalAlignment='CENTER'} -fields 'backgroundColor,textFormat,horizontalAlignment'
for($r=4;$r -lt 14;$r++){ $req.Add(@{updateDimensionProperties=@{range=@{sheetId=$sidGuide;dimension='ROWS';startIndex=$r;endIndex=($r+1)};properties=@{pixelSize=38};fields='pixelSize'}}) | Out-Null }
AddFmt -req $req -sid $sidGuide -r1 4 -r2 24 -c1 0 -c2 7 -fmt @{wrapStrategy='WRAP';verticalAlignment='MIDDLE'} -fields 'wrapStrategy,verticalAlignment'

$req.Add(@{repeatCell=@{range=@{sheetId=$sidInput;startRowIndex=4;endRowIndex=$inputMaxRows;startColumnIndex=0;endColumnIndex=8};cell=@{};fields='dataValidation'}}) | Out-Null
$vals=@(); foreach($ln in @('Escuela','Management','Ticket Buho','Sala Bella Bestia','Discografica','Eventos')){ $vals += @{userEnteredValue=$ln} }
$req.Add(@{setDataValidation=@{range=@{sheetId=$sidInput;startRowIndex=4;endRowIndex=$inputUiRows;startColumnIndex=1;endColumnIndex=2};rule=@{condition=@{type='ONE_OF_LIST';values=$vals};strict=$true;showCustomUi=$false}}}) | Out-Null
$req.Add(@{setDataValidation=@{range=@{sheetId=$sidInput;startRowIndex=4;endRowIndex=$inputUiRows;startColumnIndex=2;endColumnIndex=5};rule=@{condition=@{type='NUMBER_GREATER_THAN_EQ';values=@(@{userEnteredValue='0'})};strict=$true;showCustomUi=$false}}}) | Out-Null

$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=9;endRowIndex=15;startColumnIndex=0;endColumnIndex=7});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$G10="VERDE"'})};format=@{backgroundColor=@{red=0.86;green=0.96;blue=0.88}}}};index=0}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=9;endRowIndex=15;startColumnIndex=0;endColumnIndex=7});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$G10="AMARILLO"'})};format=@{backgroundColor=@{red=0.99;green=0.95;blue=0.78}}}};index=1}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=9;endRowIndex=15;startColumnIndex=0;endColumnIndex=7});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$G10="ROJO"'})};format=@{backgroundColor=@{red=0.99;green=0.89;blue=0.89}}}};index=2}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=32;endRowIndex=38;startColumnIndex=0;endColumnIndex=8});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$F33="BAJO"'})};format=@{backgroundColor=@{red=0.86;green=0.96;blue=0.88}}}};index=3}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=32;endRowIndex=38;startColumnIndex=0;endColumnIndex=8});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$F33="MEDIO"'})};format=@{backgroundColor=@{red=0.99;green=0.95;blue=0.78}}}};index=4}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=32;endRowIndex=38;startColumnIndex=0;endColumnIndex=8});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$F33="ALTO"'})};format=@{backgroundColor=@{red=0.99;green=0.89;blue=0.89}}}};index=5}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=40;endRowIndex=46;startColumnIndex=0;endColumnIndex=5});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$B41="BAJO"'})};format=@{backgroundColor=@{red=0.86;green=0.96;blue=0.88}}}};index=6}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=40;endRowIndex=46;startColumnIndex=0;endColumnIndex=5});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$B41="MEDIO"'})};format=@{backgroundColor=@{red=0.99;green=0.95;blue=0.78}}}};index=7}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidPanel;startRowIndex=40;endRowIndex=46;startColumnIndex=0;endColumnIndex=5});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$B41="ALTO"'})};format=@{backgroundColor=@{red=0.99;green=0.89;blue=0.89}}}};index=8}}) | Out-Null

$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidInput;startRowIndex=4;endRowIndex=$inputUiRows;startColumnIndex=0;endColumnIndex=8});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$G5="VERDE"'})};format=@{backgroundColor=@{red=0.86;green=0.96;blue=0.88}}}};index=0}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidInput;startRowIndex=4;endRowIndex=$inputUiRows;startColumnIndex=0;endColumnIndex=8});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$G5="AMARILLO"'})};format=@{backgroundColor=@{red=0.99;green=0.95;blue=0.78}}}};index=1}}) | Out-Null
$req.Add(@{addConditionalFormatRule=@{rule=@{ranges=@(@{sheetId=$sidInput;startRowIndex=4;endRowIndex=$inputUiRows;startColumnIndex=0;endColumnIndex=8});booleanRule=@{condition=@{type='CUSTOM_FORMULA';values=@(@{userEnteredValue='=$G5="ROJO"'})};format=@{backgroundColor=@{red=0.99;green=0.89;blue=0.89}}}};index=2}}) | Out-Null

$req.Add(@{repeatCell=@{range=@{sheetId=$sidPanel;startRowIndex=4;endRowIndex=6;startColumnIndex=0;endColumnIndex=12};cell=@{userEnteredFormat=@{numberFormat=@{type='CURRENCY'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidPanel;startRowIndex=9;endRowIndex=$panelMaxRows;startColumnIndex=1;endColumnIndex=5};cell=@{userEnteredFormat=@{numberFormat=@{type='CURRENCY'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidPanel;startRowIndex=32;endRowIndex=$panelMaxRows;startColumnIndex=7;endColumnIndex=8};cell=@{userEnteredFormat=@{numberFormat=@{type='CURRENCY'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidPanel;startRowIndex=32;endRowIndex=35;startColumnIndex=9;endColumnIndex=10};cell=@{userEnteredFormat=@{numberFormat=@{type='CURRENCY'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidPanel;startRowIndex=40;endRowIndex=46;startColumnIndex=4;endColumnIndex=5};cell=@{userEnteredFormat=@{numberFormat=@{type='CURRENCY'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidPanel;startRowIndex=9;endRowIndex=15;startColumnIndex=5;endColumnIndex=6};cell=@{userEnteredFormat=@{numberFormat=@{type='PERCENT';pattern='0.00%'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidInput;startRowIndex=4;endRowIndex=$inputUiRows;startColumnIndex=2;endColumnIndex=6};cell=@{userEnteredFormat=@{numberFormat=@{type='CURRENCY'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null
$req.Add(@{repeatCell=@{range=@{sheetId=$sidConfig;startRowIndex=1;endRowIndex=8;startColumnIndex=2;endColumnIndex=3};cell=@{userEnteredFormat=@{numberFormat=@{type='PERCENT';pattern='0.00%'}}};fields='userEnteredFormat.numberFormat'}}) | Out-Null

# Bordes para lectura visual (tablas claras y separadas)
AddGridBorders -req $req -sid $sidPanel -r1 8 -r2 15 -c1 0 -c2 7
${scenarioLine} = @{ style = 'SOLID'; color = @{ red = 0.75; green = 0.75; blue = 0.75 } }
$req.Add(@{
  updateBorders = @{
    range = @{ sheetId = $sidPanel; startRowIndex = 31; endRowIndex = 38; startColumnIndex = 0; endColumnIndex = 8 }
    top = ${scenarioLine}
    bottom = ${scenarioLine}
    left = ${scenarioLine}
    innerHorizontal = ${scenarioLine}
    innerVertical = ${scenarioLine}
  }
}) | Out-Null
${summaryLine} = @{ style = 'SOLID'; color = @{ red = 0.75; green = 0.75; blue = 0.75 } }
$req.Add(@{
  updateBorders = @{
    range = @{ sheetId = $sidPanel; startRowIndex = 31; endRowIndex = 35; startColumnIndex = 8; endColumnIndex = 11 }
    top = ${summaryLine}
    bottom = ${summaryLine}
    right = ${summaryLine}
    innerHorizontal = ${summaryLine}
    innerVertical = ${summaryLine}
  }
}) | Out-Null
AddGridBorders -req $req -sid $sidPanel -r1 40 -r2 46 -c1 0 -c2 5
AddGridBorders -req $req -sid $sidInput -r1 3 -r2 12 -c1 0 -c2 8
AddGridBorders -req $req -sid $sidGuide -r1 4 -r2 19 -c1 0 -c2 7

# Graficos visuales del panel (sin solapes)
$req.Add(@{
  addChart = @{
    chart = @{
      spec = @{
        title = 'Resultado por linea de negocio'
        basicChart = @{
          chartType = 'BAR'
          legendPosition = 'NO_LEGEND'
          axis = @(
            @{ position = 'BOTTOM_AXIS'; title = 'EUR' },
            @{ position = 'LEFT_AXIS'; title = 'Linea' }
          )
          domains = @(
            @{ domain = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 8; endRowIndex = 15; startColumnIndex = 0; endColumnIndex = 1 }) } } }
          )
          series = @(
            @{ series = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 8; endRowIndex = 15; startColumnIndex = 4; endColumnIndex = 5 }) } }; targetAxis = 'BOTTOM_AXIS' }
          )
          headerCount = 1
        }
      }
      position = @{
        overlayPosition = @{
          anchorCell = @{ sheetId = $sidPanel; rowIndex = 16; columnIndex = 0 }
          offsetXPixels = 0
          offsetYPixels = 0
          widthPixels = 350
          heightPixels = 280
        }
      }
    }
  }
}) | Out-Null

$req.Add(@{
  addChart = @{
    chart = @{
      spec = @{
        title = 'Distribucion de ingresos por linea'
        pieChart = @{
          legendPosition = 'RIGHT_LEGEND'
          domain = @{ sourceRange = @{ sources = @(@{ sheetId = $sidConfig; startRowIndex = 1; endRowIndex = 7; startColumnIndex = 3; endColumnIndex = 4 }) } }
          series = @{ sourceRange = @{ sources = @(@{ sheetId = $sidConfig; startRowIndex = 1; endRowIndex = 7; startColumnIndex = 2; endColumnIndex = 3 }) } }
          pieHole = 0.45
        }
      }
      position = @{
        overlayPosition = @{
          anchorCell = @{ sheetId = $sidPanel; rowIndex = 16; columnIndex = 8 }
          offsetXPixels = 0
          offsetYPixels = 0
          widthPixels = 350
          heightPixels = 280
        }
      }
    }
  }
}) | Out-Null

$req.Add(@{
  addChart = @{
    chart = @{
      spec = @{
        title = 'Escenarios 12 meses'
        basicChart = @{
          chartType = 'COLUMN'
          legendPosition = 'NO_LEGEND'
          axis = @(
            @{ position = 'BOTTOM_AXIS'; title = 'Escenario' },
            @{ position = 'LEFT_AXIS'; title = 'Resultado EUR' }
          )
          domains = @(
            @{ domain = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 31; endRowIndex = 35; startColumnIndex = 8; endColumnIndex = 9 }) } } }
          )
          series = @(
            @{ series = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 31; endRowIndex = 35; startColumnIndex = 9; endColumnIndex = 10 }) } }; targetAxis = 'LEFT_AXIS' }
          )
          headerCount = 1
        }
      }
      position = @{
        overlayPosition = @{
          anchorCell = @{ sheetId = $sidPanel; rowIndex = 16; columnIndex = 4 }
          offsetXPixels = 0
          offsetYPixels = 0
          widthPixels = 350
          heightPixels = 280
        }
      }
    }
  }
}) | Out-Null

$req.Add(@{
  addChart = @{
    chart = @{
      spec = @{
        title = 'Tendencia de margen por linea (%)'
        basicChart = @{
          chartType = 'COLUMN'
          legendPosition = 'NO_LEGEND'
          axis = @(
            @{ position = 'BOTTOM_AXIS'; title = 'Linea' },
            @{ position = 'LEFT_AXIS'; title = 'Margen %' }
          )
          domains = @(
            @{ domain = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 8; endRowIndex = 15; startColumnIndex = 0; endColumnIndex = 1 }) } } }
          )
          series = @(
            @{ series = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 8; endRowIndex = 15; startColumnIndex = 5; endColumnIndex = 6 }) } }; targetAxis = 'LEFT_AXIS' }
          )
          headerCount = 1
        }
      }
      position = @{
        overlayPosition = @{
          anchorCell = @{ sheetId = $sidPanel; rowIndex = 48; columnIndex = 0 }
          offsetXPixels = 0
          offsetYPixels = 0
          widthPixels = 560
          heightPixels = 260
        }
      }
    }
  }
}) | Out-Null

$req.Add(@{
  addChart = @{
    chart = @{
      spec = @{
        title = 'Comparativa ingresos vs gastos por linea'
        basicChart = @{
          chartType = 'BAR'
          legendPosition = 'BOTTOM_LEGEND'
          axis = @(
            @{ position = 'BOTTOM_AXIS'; title = 'EUR' },
            @{ position = 'LEFT_AXIS'; title = 'Linea' }
          )
          domains = @(
            @{ domain = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 8; endRowIndex = 15; startColumnIndex = 0; endColumnIndex = 1 }) } } }
          )
          series = @(
            @{ series = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 8; endRowIndex = 15; startColumnIndex = 1; endColumnIndex = 2 }) } }; targetAxis = 'BOTTOM_AXIS' },
            @{ series = @{ sourceRange = @{ sources = @(@{ sheetId = $sidPanel; startRowIndex = 8; endRowIndex = 15; startColumnIndex = 2; endColumnIndex = 3 }) } }; targetAxis = 'BOTTOM_AXIS' }
          )
          headerCount = 1
        }
      }
      position = @{
        overlayPosition = @{
          anchorCell = @{ sheetId = $sidPanel; rowIndex = 48; columnIndex = 6 }
          offsetXPixels = 0
          offsetYPixels = 0
          widthPixels = 560
          heightPixels = 260
        }
      }
    }
  }
}) | Out-Null

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{requests=$req} | Out-Null

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId,[uri]::EscapeDataString(("00_PANEL!A1:L{0}" -f $panelMaxRows))) -Token $token -Body @{} | Out-Null
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId,[uri]::EscapeDataString(("01_ENTRADA!A1:H{0}" -f $inputMaxRows))) -Token $token -Body @{} | Out-Null
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId,[uri]::EscapeDataString(("00_GUIA_USO!A1:G{0}" -f $guideMaxRows))) -Token $token -Body @{} | Out-Null
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}:clear" -f $SpreadsheetId,[uri]::EscapeDataString('99_CONFIG!A1:L120')) -Token $token -Body @{} | Out-Null

$panelData = @(
  @{range='00_PANEL!A1';values=@(,@('PANEL CORPORATIVO ARTES BUHO - CONTABILIDAD DE DECISION'))},
  @{range='00_PANEL!A2';values=@(,@('="Actualizado: "&TEXT(NOW();"dd/mm/yyyy hh:mm:ss")&" | Solo editas 01_ENTRADA"'))},
  @{range='00_PANEL!A4';values=@(,@('Liquidez total actual'))}, @{range='00_PANEL!D4';values=@(,@('Ingresos acumulados del año'))}, @{range='00_PANEL!G4';values=@(,@('Gastos acumulados del año'))}, @{range='00_PANEL!J4';values=@(,@('Desviación del objetivo'))},
  @{range='00_PANEL!A5';values=@(,@(("=IFERROR(SUM('01_ENTRADA'!F5:F{0});0)" -f $inputMaxRows)))},
  @{range='00_PANEL!D5';values=@(,@(("=IFERROR(SUMIFS('01_ENTRADA'!C5:C{0};'01_ENTRADA'!A5:A{0};"">=""&TEXT(TODAY();""yyyy"")&""-01"";'01_ENTRADA'!A5:A{0};""<=""&TEXT(TODAY();""yyyy"")&""-12"");0)" -f $inputMaxRows)))},
  @{range='00_PANEL!G5';values=@(,@(("=IFERROR(SUMIFS('01_ENTRADA'!D5:D{0};'01_ENTRADA'!A5:A{0};"">=""&TEXT(TODAY();""yyyy"")&""-01"";'01_ENTRADA'!A5:A{0};""<=""&TEXT(TODAY();""yyyy"")&""-12"");0)" -f $inputMaxRows)))},
  @{range='00_PANEL!J5';values=@(,@(("=IFERROR(SUM('01_ENTRADA'!C5:C{0})-SUM('01_ENTRADA'!E5:E{0});0)" -f $inputMaxRows)))},
  @{range='00_PANEL!A8';values=@(,@('RADAR POR LINEA DE NEGOCIO'))},
  @{range='00_PANEL!A9:G9';values=@(,@('Linea de negocio','Ingresos','Gastos','Objetivo','Resultado','Margen %','Semaforo'))},
  @{range='00_PANEL!A10:A15';values=@(@('Escuela'),@('Management'),@('Ticket Buho'),@('Sala Bella Bestia'),@('Discografica'),@('Eventos'))},
  @{range='00_PANEL!B10';values=@(,@(("=ARRAYFORMULA(IF(A10:A15="""";"""";IFERROR(SUMIF('01_ENTRADA'!B5:B{0};A10:A15;'01_ENTRADA'!C5:C{0});0)))" -f $inputMaxRows)))},
  @{range='00_PANEL!C10';values=@(,@(("=ARRAYFORMULA(IF(A10:A15="""";"""";IFERROR(SUMIF('01_ENTRADA'!B5:B{0};A10:A15;'01_ENTRADA'!D5:D{0});0)))" -f $inputMaxRows)))},
  @{range='00_PANEL!D10';values=@(,@('=ARRAYFORMULA(IF(A10:A15="";"";IF(A10:A15="Escuela";12000;IF(A10:A15="Management";9000;IF(A10:A15="Ticket Buho";14000;IF(A10:A15="Sala Bella Bestia";11000;IF(A10:A15="Discografica";5000;8000)))))))'))},
  @{range='00_PANEL!E10';values=@(,@('=ARRAYFORMULA(IF(A10:A15="";"";B10:B15-C10:C15))'))},
  @{range='00_PANEL!F10';values=@(,@('=ARRAYFORMULA(IF(A10:A15="";"";IFERROR(E10:E15/B10:B15;0)))'))},
  @{range='00_PANEL!G10';values=@(,@('=ARRAYFORMULA(IF(A10:A15="";"";IF(E10:E15>=0;"VERDE";IF(E10:E15>=-0,15*D10:D15;"AMARILLO";"ROJO"))))'))},
  @{range='00_PANEL!A31';values=@(,@('ESCENARIOS 12 MESES - POR LINEA Y GLOBAL'))},
  @{range='00_PANEL!A32:H32';values=@(,@('Linea','Base 12M','Optimista 12M','Pesimista 12M','Brecha pesimista','Riesgo','Accion semanal recomendada','Ingreso extra si sale mal'))},
  @{range='00_PANEL!A33:A38';values=@(@('Escuela'),@('Management'),@('Ticket Buho'),@('Sala Bella Bestia'),@('Discografica'),@('Eventos'))},
  @{range='00_PANEL!B33';values=@(,@('=ARRAYFORMULA(IF(A33:A38="";"";E10:E15*12))'))},
  @{range='00_PANEL!C33';values=@(,@('=ARRAYFORMULA(IF(A33:A38="";"";B33:B38*1,25))'))},
  @{range='00_PANEL!D33';values=@(,@('=ARRAYFORMULA(IF(A33:A38="";"";B33:B38*0,75))'))},
  @{range='00_PANEL!E33';values=@(,@('=ARRAYFORMULA(IF(A33:A38="";"";D33:D38-B33:B38))'))},
  @{range='00_PANEL!F33';values=@(,@('=ARRAYFORMULA(IF(A33:A38="";"";IF(D33:D38>=0;"BAJO";IF(D33:D38>=-0,2*ABS(B33:B38);"MEDIO";"ALTO"))))'))},
  @{range='00_PANEL!G33';values=@(,@('=ARRAYFORMULA(IF(A33:A38="";"";IF(F33:F38="ALTO";"Plan de choque 7 dias: bajar gasto variable + subir ventas";IF(F33:F38="MEDIO";"Control diario: vigilar caja + proteger margen";IF(A33:A38="Escuela";"Escalar captacion y retencion mensual";IF(A33:A38="Management";"Escalar artistas con mayor margen";IF(A33:A38="Ticket Buho";"Escalar conversion de ticketing";IF(A33:A38="Sala Bella Bestia";"Escalar ocupacion de sala con margen";IF(A33:A38="Discografica";"Escalar lanzamientos rentables";"Escalar eventos de mayor ticket")))))))))'))},
  @{range='00_PANEL!H33';values=@(,@('=ARRAYFORMULA(IF(A33:A38="";"";IF(-D33:D38>0;-D33:D38;0)))'))},
  @{range='00_PANEL!I31';values=@(,@('RESUMEN GLOBAL 12M'))},
  @{range='00_PANEL!I32:K32';values=@(,@('Escenario','Resultado 12M','Accion global'))},
  @{range='00_PANEL!I33';values=@(,@('Optimista'))},
  @{range='00_PANEL!I34';values=@(,@('Base'))},
  @{range='00_PANEL!I35';values=@(,@('Pesimista'))},
  @{range='00_PANEL!J33';values=@(,@('=SUM(C33:C38)'))},
  @{range='00_PANEL!J34';values=@(,@('=SUM(B33:B38)'))},
  @{range='00_PANEL!J35';values=@(,@('=SUM(D33:D38)'))},
  @{range='00_PANEL!K33';values=@(,@('=IF(J33>=0;"Escalar lo que mejor funciona";"Vender mas sin subir estructura")'))},
  @{range='00_PANEL!K34';values=@(,@('=IF(J34>=0;"Mantener base y optimizar conversion";"Recortar gasto variable hoy")'))},
  @{range='00_PANEL!K35';values=@(,@('=IF(J35>=0;"Modo prudente con seguimiento diario";"Defender caja: recorte + cobro inmediato")'))},
  @{range='00_PANEL!A39';values=@(,@('BLOQUE IA - RECOMENDACIONES CONTABLES'))},
  @{range='00_PANEL!A40:E40';values=@(,@('Linea','Riesgo IA','Semaforo','Recomendacion semanal','Ingreso extra si sale mal'))},
  @{range='00_PANEL!A41';values=@(,@('=IFERROR(FILTER(A33:A38;A33:A38<>"");"")'))},
  @{range='00_PANEL!B41';values=@(,@('=IFERROR(FILTER(F33:F38;A33:A38<>"");"")'))},
  @{range='00_PANEL!C41';values=@(,@('=IFERROR(ARRAYFORMULA(IF(A41:A46="";"";VLOOKUP(A41:A46;A10:G15;7;FALSE)));"")'))},
  @{range='00_PANEL!D41';values=@(,@('=IFERROR(FILTER(G33:G38;A33:A38<>"");"")'))},
  @{range='00_PANEL!E41';values=@(,@('=IFERROR(FILTER(H33:H38;A33:A38<>"");"")'))},
  @{range='00_PANEL!A47';values=@(,@('ANALISIS VISUAL AVANZADO'))},
  @{range='00_PANEL!A48';values=@(,@('Graficos extra para decidir rapido: tendencia de margen y comparativa ingresos/gastos por linea.'))}
)

$configData = @(
  @{range='99_CONFIG!A1:D1';values=@(,@('BLOQUE','LINEA','PESO','ETIQUETA'))},
  @{range='99_CONFIG!A2';values=@(,@('DONUT_HELPER'))},
  @{range='99_CONFIG!B2';values=@(,@('=ARRAYFORMULA(IF(00_PANEL!A10:A15="";"";00_PANEL!A10:A15))'))},
  @{range='99_CONFIG!C2';values=@(,@('=ARRAYFORMULA(IF(00_PANEL!A10:A15="";"";IFERROR(00_PANEL!B10:B15/SUM(00_PANEL!B10:B15);0)))'))},
  @{range='99_CONFIG!D2';values=@(,@('=ARRAYFORMULA(IF(00_PANEL!A10:A15="";"";00_PANEL!A10:A15&" ("&TEXT(99_CONFIG!C2:C7;"0%")&")"))'))}
)

$panelUrl = 'https://docs.google.com/spreadsheets/d/' + $SpreadsheetId + '/edit#gid=0'

$inputData = @(
  @{range='01_ENTRADA!A1';values=@(,@('ENTRADA RAPIDA - ARTES BUHO'))},
  @{range='01_ENTRADA!A2';values=@(,@('Introduce datos aqui. El panel se actualiza sin pulsar botones.'))},
  @{range='01_ENTRADA!A3';values=@(,@('Edita: Mes, Linea, Ingresos, Gastos, Objetivo y Nota. Consulta 00_GUIA_USO.'))},
  @{range='01_ENTRADA!A4:H4';values=@(,@('Mes (YYYY-MM)','Linea de negocio','Ingresos reales','Gastos reales','Objetivo mensual','Resultado','Semaforo','Nota'))},
  @{range='01_ENTRADA!A12';values=@(,@('PASO FINAL: pulsa el boton rojo y decide con semaforo + escenario pesimista.'))},
  @{range='01_ENTRADA!H12';values=@(,@('=HYPERLINK("' + $panelUrl + '";"VER PANEL Y DECIDIR")'))}
)
# Evita #REF! por expansion de ARRAYFORMULA: cargamos solo columnas manuales (A:E y H).
if ($inputMainRows.Count -gt 0) { $inputData += @{range=('01_ENTRADA!A5:E{0}' -f (4+$inputMainRows.Count)); values=$inputMainRows.ToArray()} }
if ($inputNoteRows.Count -gt 0) { $inputData += @{range=('01_ENTRADA!H5:H{0}' -f (4+$inputNoteRows.Count)); values=$inputNoteRows.ToArray()} }
$inputData += @{range='01_ENTRADA!F5';values=@(,@(("=ARRAYFORMULA(IF(B5:B{0}="""";"""";C5:C{0}-D5:D{0}))" -f $inputMaxRows)))}
$inputData += @{range='01_ENTRADA!G5';values=@(,@(("=ARRAYFORMULA(IF(B5:B{0}="""";"""";IF(F5:F{0}>=0;""VERDE"";IF(F5:F{0}>=-0,15*E5:E{0};""AMARILLO"";""ROJO""))))" -f $inputMaxRows)))}

$guideData = @(
  @{range='00_GUIA_USO!A1';values=@(,@('MANUAL RAPIDO - ARTES BUHO CONTABILIDAD DE DECISION'))},
  @{range='00_GUIA_USO!A2';values=@(,@('LEE SOLO ESTO: 01_ENTRADA para cargar datos. 00_PANEL para decidir. 00_GUIA_USO para consultar pasos.'))},
  @{range='00_GUIA_USO!A4';values=@(,@('PASOS RAPIDOS (SIN TECNICO)'))},
  @{range='00_GUIA_USO!A5:G13';values=@(
    @('Paso','Que haces','Donde lo haces','Tiempo','Que te muestra','Semaforo','Decision recomendada'),
    @('PASO 1','Rellena una fila por linea (Mes + Linea + Ingresos + Gastos + Objetivo + Nota)','01_ENTRADA','1 minuto','Datos actualizados del periodo','',''),
    @('PASO 2','Pulsa VER PANEL Y DECIDIR','Boton rojo en 01_ENTRADA','5 segundos','Abre el cuadro de mando completo','',''),
    @('PASO 3','Mira el RADAR POR LINEA','00_PANEL','20 segundos','Resultado, margen y color por linea','Verde/Amarillo/Rojo','Escalar / Vigilar / Plan de choque'),
    @('PASO 4','Mira ESCENARIOS 12M','00_PANEL','20 segundos','Escenario Optimista, Base y Pesimista','','Ajustar gasto e inversion'),
    @('PASO 5','Ejecuta RECOMENDACION SEMANAL','00_PANEL','20 segundos','Accion de negocio concreta','','Aplicar accion de 7 dias'),
    @('PASO 6','Reunion corta de cierre','00_PANEL + equipo','5 minutos','Decision clara por linea','','Repetir cada semana'),
    @('PASO 7','Revisar solo lineas amarillas y rojas','00_PANEL','1 minuto','Prioridad real del negocio','AMARILLO/ROJO','Actuar hoy sin esperar')
  )},
  @{range='00_GUIA_USO!A14';values=@(,@('LECTURA DEL SEMAFORO'))},
  @{range='00_GUIA_USO!A15:G15';values=@(,@('Color','Significado','Accion','Escenario típico','Que miro primero','Meta semanal','Cuando pedir ayuda'))},
  @{range='00_GUIA_USO!A16:G18';values=@(
  @('VERDE','Linea rentable','Escalar manteniendo margen','Optimista','Capacidad de venta','10% ingreso con margen','Si baja el margen 2 semanas'),
  @('AMARILLO','Margen ajustado','Control diario de gasto y conversion','Base','Caja diaria y cobros','Volver a verde en 7 dias','Si no mejora en 7 dias'),
  @('ROJO','Riesgo de perdida','Plan de choque 7 dias','Pesimista','Gasto fijo y ventas urgentes','Salir de negativo','Pedir decision inmediata')
  )},
  @{range='00_GUIA_USO!A20:G24';values=@(
    @('LINEAS OFICIALES: Escuela, Management, Ticket Buho, Sala Bella Bestia, Discografica y Eventos.','','','','','',''),
    @('SI VES BLOQUEO: esta bien. Solo se edita 01_ENTRADA para evitar errores del equipo.','','','','','',''),
    @('BOTON RAPIDO: Menu CONTABILIDAD ARTES BUHO > 4) Actualizar panel de decision.','','','','','',''),
    @('REGLA SIMPLE: 01_ENTRADA para cargar. 00_PANEL para decidir.','','','','','',''),
    @('REVISION OBLIGATORIA: escenario pesimista + semaforo + recomendacion semanal.','','','','','','')
  )}
)

Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}/values:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{valueInputOption='USER_ENTERED';data=($panelData+$configData+$inputData+$guideData)} | Out-Null

# Pasada final: garantiza tipografia corporativa unica en hojas visibles
$fontPassReq = @(
  @{
    repeatCell = @{
      range = @{ sheetId = $sidPanel; startRowIndex = 0; endRowIndex = $panelMaxRows; startColumnIndex = 0; endColumnIndex = $panelMaxCols }
      cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat' } } }
      fields = 'userEnteredFormat.textFormat.fontFamily'
    }
  },
  @{
    repeatCell = @{
      range = @{ sheetId = $sidInput; startRowIndex = 0; endRowIndex = $inputMaxRows; startColumnIndex = 0; endColumnIndex = $inputMaxCols }
      cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat' } } }
      fields = 'userEnteredFormat.textFormat.fontFamily'
    }
  },
  @{
    repeatCell = @{
      range = @{ sheetId = $sidGuide; startRowIndex = 0; endRowIndex = $guideMaxRows; startColumnIndex = 0; endColumnIndex = $guideMaxCols }
      cell = @{ userEnteredFormat = @{ textFormat = @{ fontFamily = 'Montserrat' } } }
      fields = 'userEnteredFormat.textFormat.fontFamily'
    }
  }
)
Invoke-GApi -Method POST -Uri ("https://sheets.googleapis.com/v4/spreadsheets/{0}:batchUpdate" -f $SpreadsheetId) -Token $token -Body @{requests=$fontPassReq} | Out-Null

[ordered]@{ok=$true;mode='decision_minimal_full';spreadsheetId=$SpreadsheetId;visibleSheets=$visible;inputRowsDetected=$det;importedFromTransactions=$fromTx;rowsLoaded=$inputMainRows.Count;updatedAt=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 10
