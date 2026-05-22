param(
  [string]$SpreadsheetId = 'REPLACE_WITH_ID',
  [string]$TokenProfile = 'default',
  [ValidateSet('oauth','service_account')]
  [string]$AuthMode = 'service_account',
  [string]$ServiceAccountKeyPath = 'C:\Users\elrub\Desktop\CARPETA CODEX\secrets\robot-codex-key-20260308-220232.json',
  [string]$OutputJson = 'audit\reports\remote_sheet_deep_audit.json'
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
  param(
    [string]$Profile,
    [ValidateSet('oauth','service_account')]
    [string]$Mode,
    [string]$ServiceAccountKey
  )

  if ($Mode -eq 'service_account') {
    $helper = Join-Path $PSScriptRoot 'get_service_account_access_token.js'
    if (-not (Test-Path -LiteralPath $ServiceAccountKey)) {
      throw ('No existe ServiceAccountKeyPath: ' + $ServiceAccountKey)
    }

    $token = ''
    try {
      if (-not (Test-Path -LiteralPath $helper)) {
        throw ('No existe helper de cuenta de servicio: ' + $helper)
      }
      $nodeCmd = Get-NodeCommand
      $token = & $nodeCmd $helper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
    } catch {
      $pyHelper = Join-Path $PSScriptRoot 'get_service_account_access_token.py'
      if (-not (Test-Path -LiteralPath $pyHelper)) { throw }
      $pythonCmd = Get-PythonCommand
      $token = & $pythonCmd $pyHelper --keyPath $ServiceAccountKey --scopes 'https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/drive'
    }
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
  param(
    [ValidateSet('GET','POST')]
    [string]$Method,
    [string]$Uri,
    [string]$Token,
    $Body = $null
  )

  $headers = @{ Authorization = ('Bearer ' + $Token) }
  $maxRetries = 7
  $baseDelayMs = 700

  for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
    try {
      if ($Method -eq 'GET') {
        return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers -ErrorAction Stop
      }

      $json = if ($null -eq $Body) { '{}' } else { $Body | ConvertTo-Json -Depth 40 }
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
      return Invoke-RestMethod -Method Post -Uri $Uri -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bytes -ErrorAction Stop
    }
    catch {
      $statusCode = Get-ApiStatusCodeFromError -ErrorRecord $_
      $isTransient = @(-1,408,429,500,502,503,504) -contains $statusCode
      if ($isTransient -and $attempt -lt $maxRetries) {
        $waitMs = [int]([Math]::Round($baseDelayMs * [Math]::Pow(2, $attempt))) + (Get-Random -Minimum 140 -Maximum 640)
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

function Get-ColumnName {
  param([int]$Column)
  $out = ''
  $n = [Math]::Max(1, $Column)
  while ($n -gt 0) {
    $m = ($n - 1) % 26
    $out = [char](65 + $m) + $out
    $n = [Math]::Floor(($n - $m - 1) / 26)
  }
  return $out
}

function Get-A1Cell {
  param(
    [int]$Row,
    [int]$Column
  )
  return (Get-ColumnName -Column $Column) + $Row
}

function Escape-SheetNameForA1 {
  param([string]$Name)
  return "'" + ([string]$Name).Replace("'", "''") + "'"
}

function Add-Counter {
  param(
    [hashtable]$Map,
    [string]$Key
  )
  if ([string]::IsNullOrWhiteSpace($Key)) { return }
  if ($Map.ContainsKey($Key)) {
    $Map[$Key] = [int]$Map[$Key] + 1
  } else {
    $Map[$Key] = 1
  }
}

function Top-Counters {
  param(
    [hashtable]$Map,
    [int]$Top = 12
  )
  if ($null -eq $Map -or $Map.Count -eq 0) { return @() }
  return $Map.GetEnumerator() |
    Sort-Object -Property Value -Descending |
    Select-Object -First $Top |
    ForEach-Object {
      [ordered]@{
        value = [string]$_.Key
        count = [int]$_.Value
      }
    }
}

function ColorObj-ToHex {
  param($Color)
  if ($null -eq $Color) { return '' }
  $r = 0.0
  $g = 0.0
  $b = 0.0
  try { if ($Color.PSObject.Properties.Name -contains 'red') { $r = [double]$Color.red } } catch {}
  try { if ($Color.PSObject.Properties.Name -contains 'green') { $g = [double]$Color.green } } catch {}
  try { if ($Color.PSObject.Properties.Name -contains 'blue') { $b = [double]$Color.blue } } catch {}

  $ri = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($r * 255)))
  $gi = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($g * 255)))
  $bi = [Math]::Max(0, [Math]::Min(255, [int][Math]::Round($b * 255)))
  return ('#{0:X2}{1:X2}{2:X2}' -f $ri, $gi, $bi)
}

function GridRange-ToA1 {
  param(
    $Range,
    [hashtable]$SheetIdToName,
    [string]$FallbackSheetName
  )

  if ($null -eq $Range) { return '' }

  $sheetName = $FallbackSheetName
  try {
    if ($Range.PSObject.Properties.Name -contains 'sheetId') {
      $sid = [string]$Range.sheetId
      if ($SheetIdToName.ContainsKey($sid)) { $sheetName = [string]$SheetIdToName[$sid] }
    }
  } catch {}

  $hasStartRow = $false
  $hasStartCol = $false
  $hasEndRow = $false
  $hasEndCol = $false
  try { $hasStartRow = $Range.PSObject.Properties.Name -contains 'startRowIndex' } catch {}
  try { $hasStartCol = $Range.PSObject.Properties.Name -contains 'startColumnIndex' } catch {}
  try { $hasEndRow = $Range.PSObject.Properties.Name -contains 'endRowIndex' } catch {}
  try { $hasEndCol = $Range.PSObject.Properties.Name -contains 'endColumnIndex' } catch {}

  if (-not ($hasStartRow -or $hasStartCol -or $hasEndRow -or $hasEndCol)) {
    return ((Escape-SheetNameForA1 -Name $sheetName) + '!HOJA_COMPLETA')
  }

  $sr = 1
  $sc = 1
  $er = 2
  $ec = 2

  try { if ($hasStartRow) { $sr = [int]$Range.startRowIndex + 1 } } catch {}
  try { if ($hasStartCol) { $sc = [int]$Range.startColumnIndex + 1 } } catch {}
  try { if ($hasEndRow) { $er = [int]$Range.endRowIndex } } catch {}
  try { if ($hasEndCol) { $ec = [int]$Range.endColumnIndex } } catch {}

  $endRow = [Math]::Max($sr, $er)
  $endCol = [Math]::Max($sc, $ec)
  $start = Get-A1Cell -Row $sr -Column $sc
  $end = Get-A1Cell -Row $endRow -Column $endCol
  $sheetPrefix = Escape-SheetNameForA1 -Name $sheetName

  if ($start -eq $end) {
    return $sheetPrefix + '!' + $start
  }
  return $sheetPrefix + '!' + $start + ':' + $end
}

function Rectangles-Overlap {
  param(
    [int]$AStartRow,
    [int]$AEndRow,
    [int]$AStartCol,
    [int]$AEndCol,
    [int]$BStartRow,
    [int]$BEndRow,
    [int]$BStartCol,
    [int]$BEndCol
  )
  $rowsOverlap = ($AStartRow -lt $BEndRow) -and ($BStartRow -lt $AEndRow)
  $colsOverlap = ($AStartCol -lt $BEndCol) -and ($BStartCol -lt $AEndCol)
  return ($rowsOverlap -and $colsOverlap)
}

$token = Get-AccessToken -Profile $TokenProfile -Mode $AuthMode -ServiceAccountKey $ServiceAccountKeyPath

$metaFields = 'spreadsheetId,properties(title,locale,timeZone),sheets(properties(sheetId,title,index,hidden,gridProperties),merges,basicFilter,filterViews,conditionalFormats,protectedRanges(protectedRangeId,description,warningOnly,range,editors),charts(chartId,spec(title,basicChart(chartType),pieChart),position(overlayPosition(anchorCell(sheetId,rowIndex,columnIndex),offsetXPixels,offsetYPixels,widthPixels,heightPixels))))'
$metaUri = "https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?fields=${metaFields}"
$meta = Invoke-GApi -Method GET -Uri $metaUri -Token $token

$sheetIdToName = @{}
foreach ($s in $meta.sheets) {
  $sheetIdToName[[string]$s.properties.sheetId] = [string]$s.properties.title
}

$sheetQuick = @{}
$ranges = @()

foreach ($s in $meta.sheets) {
  $title = [string]$s.properties.title
  $rows = [int]$s.properties.gridProperties.rowCount
  $cols = [int]$s.properties.gridProperties.columnCount
  $maxCol = Get-ColumnName -Column ([Math]::Max(1, $cols))
  $fullRange = (Escape-SheetNameForA1 -Name $title) + '!A1:' + $maxCol + $rows

  $baseValuesUri = 'https://sheets.googleapis.com/v4/spreadsheets/{0}/values/{1}' -f $SpreadsheetId, [uri]::EscapeDataString($fullRange)

  $valuesRes = Invoke-GApi -Method GET -Uri ($baseValuesUri + '?valueRenderOption=FORMATTED_VALUE') -Token $token
  $formulaRes = Invoke-GApi -Method GET -Uri ($baseValuesUri + '?valueRenderOption=FORMULA') -Token $token

  $vals = @()
  if ($valuesRes.values) { $vals = @($valuesRes.values) }

  $formVals = @()
  if ($formulaRes.values) { $formVals = @($formulaRes.values) }

  $usedRows = $vals.Count
  $usedCols = 0
  foreach ($r in $vals) {
    if ($r -and $r.Count -gt $usedCols) { $usedCols = [int]$r.Count }
  }

  if ($usedRows -le 0 -or $usedCols -le 0) {
    $usedRows = 1
    $usedCols = 1
  }

  $usedRangeA1 = (Escape-SheetNameForA1 -Name $title) + '!A1:' + (Get-ColumnName -Column $usedCols) + $usedRows
  $ranges += $usedRangeA1

  $sampleData = New-Object System.Collections.Generic.List[object]
  $maxSampleRows = [Math]::Min($vals.Count, 8)
  for ($ri = 0; $ri -lt $maxSampleRows; $ri++) {
    $rowVals = @()
    $maxSampleCols = [Math]::Min((@($vals[$ri])).Count, 12)
    for ($ci = 0; $ci -lt $maxSampleCols; $ci++) {
      $rowVals += [string]$vals[$ri][$ci]
    }
    $sampleData.Add($rowVals)
  }

  $sampleFormulas = New-Object System.Collections.Generic.List[object]
  $errorCells = 0
  for ($ri = 0; $ri -lt $formVals.Count; $ri++) {
    $row = @($formVals[$ri])
    for ($ci = 0; $ci -lt $row.Count; $ci++) {
      $f = [string]$row[$ci]
      if ($f.StartsWith('=')) {
        $sampleFormulas.Add([ordered]@{
          cell = Get-A1Cell -Row ($ri + 1) -Column ($ci + 1)
          formula = $f
        })
        if ($sampleFormulas.Count -ge 40) { break }
      }
    }
    if ($sampleFormulas.Count -ge 40) { break }
  }

  foreach ($row in $vals) {
    foreach ($cellVal in @($row)) {
      $txt = [string]$cellVal
      if ($txt -match '^(#REF!|#ERROR!|#N/A|#VALUE!|#DIV/0!|#NAME\?)$') {
        $errorCells++
      }
    }
  }

  $sheetQuick[$title] = [ordered]@{
    title = $title
    sheetId = [int]$s.properties.sheetId
    index = [int]$s.properties.index
    hidden = [bool]$s.properties.hidden
    rowCount = $rows
    columnCount = $cols
    usedRows = $usedRows
    usedColumns = $usedCols
    usedRange = $usedRangeA1
    sampleData = $sampleData
    sampleFormulas = $sampleFormulas
    errorCells = [int]$errorCells
  }
}

$gridFields = 'sheets(properties(sheetId,title),data(rowMetadata(pixelSize),columnMetadata(pixelSize),rowData(values(formattedValue,userEnteredValue,dataValidation,effectiveFormat(numberFormat,backgroundColor,textFormat,horizontalAlignment,verticalAlignment,borders),userEnteredFormat(numberFormat,backgroundColor,textFormat,horizontalAlignment,verticalAlignment,borders)))))'
$gridUri = "https://sheets.googleapis.com/v4/spreadsheets/${SpreadsheetId}?includeGridData=true&fields=${gridFields}"
foreach ($r in $ranges) {
  $gridUri += '&ranges=' + [uri]::EscapeDataString($r)
}
$grid = Invoke-GApi -Method GET -Uri $gridUri -Token $token

$sheetDeepByTitle = @{}
foreach ($sh in $grid.sheets) {
  $title = [string]$sh.properties.title

  $fillColors = @{}
  $fontNames = @{}
  $fontSizes = @{}
  $numberFormats = @{}
  $hAligns = @{}
  $vAligns = @{}
  $rowHeights = @{}
  $colWidths = @{}
  $boldCount = 0
  $italicCount = 0
  $borderCells = 0
  $validationCount = 0
  $validationSamples = New-Object System.Collections.Generic.List[object]
  $nonEmptyCells = 0

  $data = $null
  if ($sh.data -and $sh.data.Count -gt 0) { $data = $sh.data[0] }

  if ($data -and $data.rowMetadata) {
    foreach ($rm in $data.rowMetadata) {
      if ($rm -and ($rm.PSObject.Properties.Name -contains 'pixelSize')) {
        Add-Counter -Map $rowHeights -Key ([string][int]$rm.pixelSize)
      }
    }
  }

  if ($data -and $data.columnMetadata) {
    foreach ($cm in $data.columnMetadata) {
      if ($cm -and ($cm.PSObject.Properties.Name -contains 'pixelSize')) {
        Add-Counter -Map $colWidths -Key ([string][int]$cm.pixelSize)
      }
    }
  }

  if ($data -and $data.rowData) {
    for ($ri = 0; $ri -lt $data.rowData.Count; $ri++) {
      $row = $data.rowData[$ri]
      if (-not $row -or -not $row.values) { continue }

      for ($ci = 0; $ci -lt $row.values.Count; $ci++) {
        $cell = $row.values[$ci]
        if (-not $cell) { continue }

        $formatted = ''
        if ($cell.PSObject.Properties.Name -contains 'formattedValue') {
          $formatted = [string]$cell.formattedValue
        }
        $hasUserEntered = ($cell.PSObject.Properties.Name -contains 'userEnteredValue') -and ($null -ne $cell.userEnteredValue)
        if (-not [string]::IsNullOrWhiteSpace($formatted) -or $hasUserEntered) {
          $nonEmptyCells++
        }

        if (($cell.PSObject.Properties.Name -contains 'dataValidation') -and $cell.dataValidation) {
          $validationCount++
          if ($validationSamples.Count -lt 40) {
            $dvType = ''
            $dvValues = @()
            try { $dvType = [string]$cell.dataValidation.condition.type } catch {}
            try {
              if ($cell.dataValidation.condition.values) {
                foreach ($v in $cell.dataValidation.condition.values) {
                  $dvValues += [string]$v.userEnteredValue
                }
              }
            } catch {}

            $dvStrict = $false
            $dvCustomUi = $false
            try { $dvStrict = [bool]$cell.dataValidation.strict } catch {}
            try { $dvCustomUi = [bool]$cell.dataValidation.showCustomUi } catch {}
            $validationSamples.Add([ordered]@{
              cell = Get-A1Cell -Row ($ri + 1) -Column ($ci + 1)
              conditionType = $dvType
              values = $dvValues
              strict = $dvStrict
              showCustomUi = $dvCustomUi
            })
          }
        }

        $fmt = $null
        if (($cell.PSObject.Properties.Name -contains 'effectiveFormat') -and $cell.effectiveFormat) {
          $fmt = $cell.effectiveFormat
        } elseif (($cell.PSObject.Properties.Name -contains 'userEnteredFormat') -and $cell.userEnteredFormat) {
          $fmt = $cell.userEnteredFormat
        }

        if ($fmt) {
          $nf = ''
          try {
            $nfType = [string]$fmt.numberFormat.type
            $nfPattern = [string]$fmt.numberFormat.pattern
            $nf = ($nfType + '|' + $nfPattern).Trim('|')
          } catch {}
          Add-Counter -Map $numberFormats -Key $nf

          $bgHex = ''
          try {
            if ($fmt.PSObject.Properties.Name -contains 'backgroundColor') {
              $bgHex = ColorObj-ToHex -Color $fmt.backgroundColor
            }
          } catch {}
          Add-Counter -Map $fillColors -Key $bgHex

          try { Add-Counter -Map $hAligns -Key ([string]$fmt.horizontalAlignment) } catch {}
          try { Add-Counter -Map $vAligns -Key ([string]$fmt.verticalAlignment) } catch {}

          $tf = $null
          try { $tf = $fmt.textFormat } catch {}
          if ($tf) {
            try { Add-Counter -Map $fontNames -Key ([string]$tf.fontFamily) } catch {}
            try { Add-Counter -Map $fontSizes -Key ([string]$tf.fontSize) } catch {}
            try { if ([bool]$tf.bold) { $boldCount++ } } catch {}
            try { if ([bool]$tf.italic) { $italicCount++ } } catch {}
          }

          $hasBorder = $false
          foreach ($side in @('top', 'bottom', 'left', 'right')) {
            try {
              $b = $fmt.borders.$side
              if ($b -and $b.style -and ([string]$b.style).ToUpper() -ne 'NONE') {
                $hasBorder = $true
                break
              }
            } catch {}
          }
          if ($hasBorder) { $borderCells++ }
        }
      }
    }
  }

  $sheetDeepByTitle[$title] = [ordered]@{
    nonEmptyCells = $nonEmptyCells
    formats = [ordered]@{
      fillColorsTop = Top-Counters -Map $fillColors
      fontNamesTop = Top-Counters -Map $fontNames
      fontSizesTop = Top-Counters -Map $fontSizes
      numberFormatsTop = Top-Counters -Map $numberFormats
      horizontalAlignmentTop = Top-Counters -Map $hAligns
      verticalAlignmentTop = Top-Counters -Map $vAligns
      boldCells = $boldCount
      italicCells = $italicCount
      borderCells = $borderCells
      rowHeightsTop = Top-Counters -Map $rowHeights
      columnWidthsTop = Top-Counters -Map $colWidths
    }
    validations = [ordered]@{
      count = $validationCount
      sample = $validationSamples
    }
  }
}

$permissions = @()
$permError = ''
try {
  $permUri = "https://www.googleapis.com/drive/v3/files/${SpreadsheetId}/permissions?fields=permissions(id,type,role,emailAddress,displayName,domain,allowFileDiscovery)"
  $permResp = Invoke-GApi -Method GET -Uri $permUri -Token $token
  if ($permResp.permissions) {
    $permissions = @($permResp.permissions | ForEach-Object {
      [ordered]@{
        id = [string]$_.id
        type = [string]$_.type
        role = [string]$_.role
        emailAddress = [string]$_.emailAddress
        displayName = [string]$_.displayName
        domain = [string]$_.domain
        allowFileDiscovery = [string]$_.allowFileDiscovery
      }
    })
  }
} catch {
  $permError = $_.Exception.Message
}

$sheetsOut = New-Object System.Collections.Generic.List[object]

foreach ($s in $meta.sheets) {
  $title = [string]$s.properties.title
  $quick = $sheetQuick[$title]
  $deep = $sheetDeepByTitle[$title]

  $mergeSample = @()
  $mergeCount = 0
  if ($s.merges) {
    $mergeCount = @($s.merges).Count
    foreach ($m in @($s.merges | Select-Object -First 40)) {
      $mergeSample += (GridRange-ToA1 -Range $m -SheetIdToName $sheetIdToName -FallbackSheetName $title)
    }
  }

  $filterViews = @()
  if ($s.filterViews) {
    foreach ($fv in $s.filterViews) {
      $fvRange = ''
      try { $fvRange = GridRange-ToA1 -Range $fv.range -SheetIdToName $sheetIdToName -FallbackSheetName $title } catch {}
      $criteriaCount = 0
      try {
        if ($fv.criteria) {
          $criteriaCount = ($fv.criteria.PSObject.Properties | Measure-Object).Count
        }
      } catch {}
      $filterViews += [ordered]@{
        title = [string]$fv.title
        range = $fvRange
        criteriaCount = $criteriaCount
      }
    }
  }

  $basicFilter = [ordered]@{
    exists = $false
    range = ''
    criteriaCount = 0
  }
  if ($s.basicFilter) {
    $basicFilter.exists = $true
    try { $basicFilter.range = GridRange-ToA1 -Range $s.basicFilter.range -SheetIdToName $sheetIdToName -FallbackSheetName $title } catch {}
    try {
      if ($s.basicFilter.criteria) {
        $basicFilter.criteriaCount = ($s.basicFilter.criteria.PSObject.Properties | Measure-Object).Count
      }
    } catch {}
  }

  $cfCount = 0
  $cfSample = @()
  if ($s.conditionalFormats) {
    $cfRules = @($s.conditionalFormats)
    $cfCount = $cfRules.Count

    foreach ($rule in @($cfRules | Select-Object -First 40)) {
      $rangesRule = @()
      try {
        if ($rule.ranges) {
          foreach ($rr in $rule.ranges) {
            $rangesRule += (GridRange-ToA1 -Range $rr -SheetIdToName $sheetIdToName -FallbackSheetName $title)
          }
        }
      } catch {}

      $ruleType = 'unknown'
      $conditionType = ''
      if ($rule.booleanRule) {
        $ruleType = 'booleanRule'
        try { $conditionType = [string]$rule.booleanRule.condition.type } catch {}
      } elseif ($rule.gradientRule) {
        $ruleType = 'gradientRule'
      }

      $cfSample += [ordered]@{
        ruleType = $ruleType
        conditionType = $conditionType
        ranges = $rangesRule
      }
    }
  }

  $protectCount = 0
  $protectSample = @()
  if ($s.protectedRanges) {
    $prs = @($s.protectedRanges)
    $protectCount = $prs.Count
    foreach ($pr in @($prs | Select-Object -First 40)) {
      $prRange = ''
      try { $prRange = GridRange-ToA1 -Range $pr.range -SheetIdToName $sheetIdToName -FallbackSheetName $title } catch {}
      $editorsUsers = @()
      $editorsGroups = @()
      $domainEdit = $false
      try {
        if ($pr.editors) {
          if ($pr.editors.users) { $editorsUsers = @($pr.editors.users) }
          if ($pr.editors.groups) { $editorsGroups = @($pr.editors.groups) }
          if ($pr.editors.PSObject.Properties.Name -contains 'domainUsersCanEdit') {
            $domainEdit = [bool]$pr.editors.domainUsersCanEdit
          }
        }
      } catch {}

      $protectSample += [ordered]@{
        protectedRangeId = [string]$pr.protectedRangeId
        description = [string]$pr.description
        warningOnly = [bool]$pr.warningOnly
        range = $prRange
        editorsUsers = $editorsUsers
        editorsGroups = $editorsGroups
        domainUsersCanEdit = $domainEdit
      }
    }
  }

  $chartCount = 0
  $chartSample = @()
  $chartBoxes = New-Object System.Collections.Generic.List[object]
  $chartOverlaps = @()
  $chartOverflow = @()
  if ($s.charts) {
    $charts = @($s.charts)
    $chartCount = $charts.Count
    foreach ($ch in @($charts | Select-Object -First 60)) {
      $chartId = [string]$ch.chartId
      $chartTitle = ''
      $chartType = 'UNKNOWN'
      try { $chartTitle = [string]$ch.spec.title } catch {}
      try {
        if ($ch.spec.basicChart) {
          $chartType = [string]$ch.spec.basicChart.chartType
        } elseif ($ch.spec.pieChart) {
          $chartType = 'PIE'
        } elseif ($ch.spec.histogramChart) {
          $chartType = 'HISTOGRAM'
        } elseif ($ch.spec.waterfallChart) {
          $chartType = 'WATERFALL'
        } elseif ($ch.spec.orgChart) {
          $chartType = 'ORG'
        } elseif ($ch.spec.treemapChart) {
          $chartType = 'TREEMAP'
        } elseif ($ch.spec.bubbleChart) {
          $chartType = 'BUBBLE'
        }
      } catch {}
      if ([string]::IsNullOrWhiteSpace($chartTitle)) { $chartTitle = 'Sin titulo' }
      if ([string]::IsNullOrWhiteSpace($chartType)) { $chartType = 'UNKNOWN' }

      $row0 = 0
      $col0 = 0
      $widthPx = 600
      $heightPx = 371
      try {
        $op = $ch.position.overlayPosition
        if ($op) {
          if ($op.anchorCell) {
            if ($op.anchorCell.PSObject.Properties.Name -contains 'rowIndex') { $row0 = [int]$op.anchorCell.rowIndex }
            if ($op.anchorCell.PSObject.Properties.Name -contains 'columnIndex') { $col0 = [int]$op.anchorCell.columnIndex }
          }
          if ($op.PSObject.Properties.Name -contains 'widthPixels') { $widthPx = [int]$op.widthPixels }
          if ($op.PSObject.Properties.Name -contains 'heightPixels') { $heightPx = [int]$op.heightPixels }
        }
      } catch {}

      $rowSpan = [Math]::Max(1, [int][Math]::Ceiling($heightPx / 21.0))
      $colSpan = [Math]::Max(1, [int][Math]::Ceiling($widthPx / 100.0))
      $rowEnd = $row0 + $rowSpan
      $colEnd = $col0 + $colSpan

      $anchorA1 = Get-A1Cell -Row ($row0 + 1) -Column ($col0 + 1)
      $boxA1 = (Escape-SheetNameForA1 -Name $title) + '!' + $anchorA1 + ':' + (Get-A1Cell -Row ([Math]::Max($row0 + 1, $rowEnd)) -Column ([Math]::Max($col0 + 1, $colEnd)))
      $isOverflow = ($rowEnd -gt [int]$s.properties.gridProperties.rowCount) -or ($colEnd -gt [int]$s.properties.gridProperties.columnCount)

      if ($isOverflow) {
        $chartOverflow += [ordered]@{
          chartId = $chartId
          title = $chartTitle
          approxRange = $boxA1
        }
      }

      $chartSample += [ordered]@{
        chartId = $chartId
        title = $chartTitle
        chartType = $chartType
        anchorCell = $anchorA1
        widthPixels = $widthPx
        heightPixels = $heightPx
        approxRange = $boxA1
        overflow = $isOverflow
      }

      $chartBoxes.Add([ordered]@{
        chartId = $chartId
        title = $chartTitle
        startRow = $row0
        endRow = $rowEnd
        startCol = $col0
        endCol = $colEnd
        approxRange = $boxA1
      }) | Out-Null
    }

    for ($i = 0; $i -lt $chartBoxes.Count; $i++) {
      for ($k = $i + 1; $k -lt $chartBoxes.Count; $k++) {
        $a = $chartBoxes[$i]
        $b = $chartBoxes[$k]
        if (Rectangles-Overlap -AStartRow $a.startRow -AEndRow $a.endRow -AStartCol $a.startCol -AEndCol $a.endCol -BStartRow $b.startRow -BEndRow $b.endRow -BStartCol $b.startCol -BEndCol $b.endCol) {
          $chartOverlaps += [ordered]@{
            chartA = $a.chartId
            chartATitle = $a.title
            rangeA = $a.approxRange
            chartB = $b.chartId
            chartBTitle = $b.title
            rangeB = $b.approxRange
          }
        }
      }
    }
  }

  $sheetObj = [ordered]@{
    title = $title
    sheetId = [int]$s.properties.sheetId
    index = [int]$s.properties.index
    hidden = [bool]$s.properties.hidden
    structure = [ordered]@{
      rowCount = [int]$s.properties.gridProperties.rowCount
      columnCount = [int]$s.properties.gridProperties.columnCount
      usedRows = [int]$quick.usedRows
      usedColumns = [int]$quick.usedColumns
      usedRange = [string]$quick.usedRange
    }
    dataAndFormulas = [ordered]@{
      sampleData = $quick.sampleData
      sampleFormulas = $quick.sampleFormulas
      nonEmptyCells = [int]$deep.nonEmptyCells
      errorCells = [int]$quick.errorCells
    }
    formats = $deep.formats
    mergedCells = [ordered]@{
      count = $mergeCount
      sample = $mergeSample
    }
    dataValidations = $deep.validations
    filters = [ordered]@{
      basicFilter = $basicFilter
      filterViews = $filterViews
    }
    conditionalFormatting = [ordered]@{
      count = $cfCount
      sample = $cfSample
    }
    protections = [ordered]@{
      count = $protectCount
      sample = $protectSample
    }
    charts = [ordered]@{
      count = $chartCount
      sample = $chartSample
      overlapCount = @($chartOverlaps).Count
      overlapSample = $chartOverlaps
      overflowCount = @($chartOverflow).Count
      overflowSample = $chartOverflow
    }
  }

  $sheetsOut.Add([pscustomobject]$sheetObj)
}

$totalErrorCells = 0
$totalChartOverlaps = 0
$totalChartOverflow = 0
$visibleLockedOk = $true
$entryValidations = 0
$recommendations = New-Object System.Collections.Generic.List[string]

foreach ($s in $sheetsOut) {
  try { $totalErrorCells += [int]$s.dataAndFormulas.errorCells } catch {}
  try { $totalChartOverlaps += [int]$s.charts.overlapCount } catch {}
  try { $totalChartOverflow += [int]$s.charts.overflowCount } catch {}
  if (-not [bool]$s.hidden) {
    if ([int]$s.protections.count -le 0) { $visibleLockedOk = $false }
  }
  if ([string]$s.title -eq '01_ENTRADA') {
    try { $entryValidations = [int]$s.dataValidations.count } catch {}
  }
}

if ($totalErrorCells -gt 0) { $recommendations.Add('Corregir celdas con error de formula antes de decidir.') | Out-Null }
if ($totalChartOverlaps -gt 0) { $recommendations.Add('Mover graficos para eliminar solapes en panel.') | Out-Null }
if ($totalChartOverflow -gt 0) { $recommendations.Add('Ajustar tamano/posicion de graficos que se salen de la hoja.') | Out-Null }
if (-not $visibleLockedOk) { $recommendations.Add('Reaplicar protecciones en hojas visibles.') | Out-Null }
if ($entryValidations -lt 10) { $recommendations.Add('Reforzar validaciones/desplegables en 01_ENTRADA.') | Out-Null }
if ($recommendations.Count -eq 0) { $recommendations.Add('Estado estable: mantener ciclo de auditoria y refresh automatico.') | Out-Null }

$qualityChecks = [ordered]@{
  ok = (($totalErrorCells -eq 0) -and ($totalChartOverlaps -eq 0) -and ($totalChartOverflow -eq 0) -and $visibleLockedOk -and ($entryValidations -ge 10))
  formulaErrorsTotal = $totalErrorCells
  chartOverlapsTotal = $totalChartOverlaps
  chartOverflowTotal = $totalChartOverflow
  visibleSheetsProtected = $visibleLockedOk
  entryValidationCount = $entryValidations
  recommendations = $recommendations
}

$outPath = if ([System.IO.Path]::IsPathRooted($OutputJson)) {
  $OutputJson
} else {
  Join-Path (Get-Location) $OutputJson
}

$outDir = Split-Path -Parent $outPath
if (-not (Test-Path -LiteralPath $outDir)) {
  New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$result = [ordered]@{
  auditedAt = (Get-Date).ToString('o')
  spreadsheetId = $SpreadsheetId
  title = [string]$meta.properties.title
  locale = [string]$meta.properties.locale
  timeZone = [string]$meta.properties.timeZone
  sheetCount = @($meta.sheets).Count
  sheets = $sheetsOut
  qualityChecks = $qualityChecks
  permissions = $permissions
  permissionsError = $permError
}

$result | ConvertTo-Json -Depth 35 | Set-Content -Path $outPath -Encoding UTF8
Write-Output ('REMOTE_DEEP_AUDIT_OK=' + $outPath)


