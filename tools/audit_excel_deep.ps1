param(
  [Parameter(Mandatory = $true)]
  [string[]]$WorkbookPaths,
  [string]$OutputJson = 'audit\reports\excel_deep_audit.json'
)

$ErrorActionPreference = 'Stop'

function Release-ComObject {
  param([Parameter(Mandatory = $false)]$ComObject)
  if ($null -ne $ComObject) {
    try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject) } catch {}
  }
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

function Convert-ColorIntToHex {
  param($ColorInt)
  if ($null -eq $ColorInt) { return '' }
  $n = 0
  try { $n = [int]$ColorInt } catch { return '' }
  if ($n -lt 0) { return '' }
  $r = $n -band 255
  $g = ($n -shr 8) -band 255
  $b = ($n -shr 16) -band 255
  return ('#{0:X2}{1:X2}{2:X2}' -f $r, $g, $b)
}

function Get-HAlignName {
  param($Value)
  $n = 0
  try { $n = [int]$Value } catch { return '' }
  switch ($n) {
    -4131 { return 'LEFT' }
    -4108 { return 'CENTER' }
    -4152 { return 'RIGHT' }
    -4130 { return 'JUSTIFY' }
    -4117 { return 'DISTRIBUTED' }
    1 { return 'GENERAL' }
    5 { return 'FILL' }
    7 { return 'CENTER_SELECTION' }
    default { return ('H_' + $n) }
  }
}

function Get-VAlignName {
  param($Value)
  $n = 0
  try { $n = [int]$Value } catch { return '' }
  switch ($n) {
    -4160 { return 'TOP' }
    -4108 { return 'CENTER' }
    -4107 { return 'BOTTOM' }
    -4130 { return 'JUSTIFY' }
    -4117 { return 'DISTRIBUTED' }
    default { return ('V_' + $n) }
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

function Get-A1Address {
  param(
    [int]$Row,
    [int]$Column
  )
  return (Get-ColumnName -Column $Column) + $Row
}

function Get-EffectiveBoundsFromUsed {
  param($UsedRange)

  $firstRow = [int]$UsedRange.Row
  $firstCol = [int]$UsedRange.Column
  $rowCount = [int]$UsedRange.Rows.Count
  $colCount = [int]$UsedRange.Columns.Count
  $lastRow = $firstRow + $rowCount - 1
  $lastCol = $firstCol + $colCount - 1

  $vals = $UsedRange.Value2
  $minRelRow = [int]::MaxValue
  $maxRelRow = 0
  $minRelCol = [int]::MaxValue
  $maxRelCol = 0
  $nonEmpty = 0

  if ($vals -is [System.Array]) {
    $rLow = $vals.GetLowerBound(0)
    $rHigh = $vals.GetUpperBound(0)
    $cLow = $vals.GetLowerBound(1)
    $cHigh = $vals.GetUpperBound(1)

    for ($r = $rLow; $r -le $rHigh; $r++) {
      for ($c = $cLow; $c -le $cHigh; $c++) {
        $v = $vals.GetValue($r, $c)
        $txt = if ($null -eq $v) { '' } else { [string]$v }
        if (-not [string]::IsNullOrWhiteSpace($txt)) {
          $nonEmpty++
          if ($r -lt $minRelRow) { $minRelRow = $r }
          if ($r -gt $maxRelRow) { $maxRelRow = $r }
          if ($c -lt $minRelCol) { $minRelCol = $c }
          if ($c -gt $maxRelCol) { $maxRelCol = $c }
        }
      }
    }
  } else {
    $single = if ($null -eq $vals) { '' } else { [string]$vals }
    if (-not [string]::IsNullOrWhiteSpace($single)) {
      $nonEmpty = 1
      $minRelRow = 1
      $maxRelRow = 1
      $minRelCol = 1
      $maxRelCol = 1
    }
  }

  $effective = [ordered]@{
    firstDataRow = 0
    firstDataColumn = 0
    lastDataRow = 0
    lastDataColumn = 0
    effectiveRowCount = 0
    effectiveColumnCount = 0
    nonEmptyCells = [int]$nonEmpty
  }

  if ($nonEmpty -gt 0) {
    $effective.firstDataRow = $firstRow + $minRelRow - 1
    $effective.firstDataColumn = $firstCol + $minRelCol - 1
    $effective.lastDataRow = $firstRow + $maxRelRow - 1
    $effective.lastDataColumn = $firstCol + $maxRelCol - 1
    $effective.effectiveRowCount = $effective.lastDataRow - $effective.firstDataRow + 1
    $effective.effectiveColumnCount = $effective.lastDataColumn - $effective.firstDataColumn + 1
  }

  return [ordered]@{
    used = [ordered]@{
      firstRow = $firstRow
      firstColumn = $firstCol
      rowCount = $rowCount
      columnCount = $colCount
      lastRow = $lastRow
      lastColumn = $lastCol
    }
    effective = $effective
  }
}

function Get-ValidationTypeName {
  param($TypeNumber)
  $n = 0
  try { $n = [int]$TypeNumber } catch { return '' }
  switch ($n) {
    1 { return 'WHOLE_NUMBER' }
    2 { return 'DECIMAL' }
    3 { return 'LIST' }
    4 { return 'DATE' }
    5 { return 'TIME' }
    6 { return 'TEXT_LENGTH' }
    7 { return 'CUSTOM' }
    default { return ('TYPE_' + $n) }
  }
}

function Get-ValidationOperatorName {
  param($OperatorNumber)
  $n = 0
  try { $n = [int]$OperatorNumber } catch { return '' }
  switch ($n) {
    1 { return 'BETWEEN' }
    2 { return 'NOT_BETWEEN' }
    3 { return 'EQUAL' }
    4 { return 'NOT_EQUAL' }
    5 { return 'GREATER_THAN' }
    6 { return 'LESS_THAN' }
    7 { return 'GREATER_EQUAL' }
    8 { return 'LESS_EQUAL' }
    default { return ('OP_' + $n) }
  }
}

function Normalize-WorkbookPath {
  param([string]$RawPath)

  $p = [string]$RawPath
  if ([string]::IsNullOrWhiteSpace($p)) { return '' }
  $p = $p.Trim()

  if (($p.StartsWith('"') -and $p.EndsWith('"')) -or ($p.StartsWith("'") -and $p.EndsWith("'"))) {
    $p = $p.Substring(1, $p.Length - 2).Trim()
  }

  if ($p.StartsWith('file://')) {
    $p = $p.Replace('file:///', '').Replace('file://', '')
  }

  $p = $p.Replace('/', '\')
  return $p
}

if (-not $WorkbookPaths -or $WorkbookPaths.Count -eq 0) {
  throw 'Debes indicar al menos un path en -WorkbookPaths'
}

$expandedPaths = New-Object System.Collections.Generic.List[string]
foreach ($raw in $WorkbookPaths) {
  $candidate = Normalize-WorkbookPath -RawPath $raw
  if ([string]::IsNullOrWhiteSpace($candidate)) { continue }

  if ($candidate.Contains(',') -and -not (Test-Path -LiteralPath $candidate)) {
    foreach ($part in ($candidate -split ',')) {
      $norm = Normalize-WorkbookPath -RawPath $part
      if (-not [string]::IsNullOrWhiteSpace($norm)) {
        $expandedPaths.Add($norm)
      }
    }
    continue
  }

  $expandedPaths.Add($candidate)
}

if ($expandedPaths.Count -eq 0) {
  throw 'No se pudo resolver ningun path valido en -WorkbookPaths'
}

$excel = $null
$booksOut = New-Object System.Collections.Generic.List[object]

try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $excel.AskToUpdateLinks = $false

  foreach ($path in $expandedPaths) {
    $resolved = ''
    try {
      $resolved = [System.IO.Path]::GetFullPath($path)
    } catch {
      $resolved = $path
    }
    $bookObj = [ordered]@{
      filePath = $resolved
      fileName = [System.IO.Path]::GetFileName($resolved)
      exists = (Test-Path -LiteralPath $resolved)
      sizeBytes = 0
      lastWriteTime = ''
      workbookSheetCount = 0
      workbookProtection = [ordered]@{
        protectStructure = $false
        protectWindows = $false
      }
      worksheets = @()
      errors = @()
    }

    if (-not $bookObj.exists) {
      $bookObj.errors += 'FILE_NOT_FOUND'
      $booksOut.Add([pscustomobject]$bookObj)
      continue
    }

    $fi = Get-Item -LiteralPath $resolved
    $bookObj.sizeBytes = [int64]$fi.Length
    $bookObj.lastWriteTime = $fi.LastWriteTime.ToString('o')

    $wb = $null
    try {
      $wb = $excel.Workbooks.Open($resolved, 0, $true)
      $bookObj.workbookSheetCount = [int]$wb.Worksheets.Count
      try { $bookObj.workbookProtection.protectStructure = [bool]$wb.ProtectStructure } catch {}
      try { $bookObj.workbookProtection.protectWindows = [bool]$wb.ProtectWindows } catch {}

      $sheetOut = New-Object System.Collections.Generic.List[object]
      foreach ($ws in $wb.Worksheets) {
        $used = $null
        try {
          $used = $ws.UsedRange
          $ranges = Get-EffectiveBoundsFromUsed -UsedRange $used
          $eff = $ranges.effective

          $rowHeights = @{}
          $colWidths = @{}
          $fillColors = @{}
          $fontNames = @{}
          $fontSizes = @{}
          $numberFormats = @{}
          $hAligns = @{}
          $vAligns = @{}
          $boldCount = 0
          $italicCount = 0
          $borderCells = 0
          $scannedCells = 0

          $merged = @{}
          $sampleValues = New-Object System.Collections.Generic.List[object]
          $formulaSamples = New-Object System.Collections.Generic.List[object]

          if ($eff.nonEmptyCells -gt 0) {
            $sampleLastRow = [Math]::Min($eff.lastDataRow, $eff.firstDataRow + 7)
            $sampleLastCol = [Math]::Min($eff.lastDataColumn, $eff.firstDataColumn + 9)
            for ($sr = $eff.firstDataRow; $sr -le $sampleLastRow; $sr++) {
              $row = @()
              for ($sc = $eff.firstDataColumn; $sc -le $sampleLastCol; $sc++) {
                $row += [string]$ws.Cells.Item($sr, $sc).Text
              }
              $sampleValues.Add($row)
            }

            for ($r = $eff.firstDataRow; $r -le $eff.lastDataRow; $r++) {
              Add-Counter -Map $rowHeights -Key ([string]([math]::Round([double]$ws.Rows.Item($r).RowHeight, 2)))
            }
            for ($c = $eff.firstDataColumn; $c -le $eff.lastDataColumn; $c++) {
              Add-Counter -Map $colWidths -Key ([string]([math]::Round([double]$ws.Columns.Item($c).ColumnWidth, 2)))
            }

            for ($r = $eff.firstDataRow; $r -le $eff.lastDataRow; $r++) {
              for ($c = $eff.firstDataColumn; $c -le $eff.lastDataColumn; $c++) {
                $cell = $ws.Cells.Item($r, $c)
                $text = [string]$cell.Text
                $formula = ''
                try { $formula = [string]$cell.Formula } catch {}
                $hasFormula = -not [string]::IsNullOrWhiteSpace($formula) -and $formula.StartsWith('=')
                $hasText = -not [string]::IsNullOrWhiteSpace($text)
                if (-not $hasText -and -not $hasFormula) { continue }

                $scannedCells++

                Add-Counter -Map $numberFormats -Key ([string]$cell.NumberFormat)
                Add-Counter -Map $fillColors -Key (Convert-ColorIntToHex -ColorInt $cell.Interior.Color)
                Add-Counter -Map $fontNames -Key ([string]$cell.Font.Name)
                Add-Counter -Map $fontSizes -Key ([string]$cell.Font.Size)
                Add-Counter -Map $hAligns -Key (Get-HAlignName -Value $cell.HorizontalAlignment)
                Add-Counter -Map $vAligns -Key (Get-VAlignName -Value $cell.VerticalAlignment)

                try { if ([bool]$cell.Font.Bold) { $boldCount++ } } catch {}
                try { if ([bool]$cell.Font.Italic) { $italicCount++ } } catch {}

                $hasBorder = $false
                foreach ($bi in @(7, 8, 9, 10)) {
                  try {
                    $ls = [int]$cell.Borders.Item($bi).LineStyle
                    if ($ls -ne -4142 -and $ls -ne 0) {
                      $hasBorder = $true
                      break
                    }
                  } catch {}
                }
                if ($hasBorder) { $borderCells++ }

                try {
                  if ([bool]$cell.MergeCells) {
                    $mergeAddr = [string]$cell.MergeArea.Address($false, $false)
                    if (-not [string]::IsNullOrWhiteSpace($mergeAddr)) {
                      $merged[$mergeAddr] = $true
                    }
                  }
                } catch {}

                if ($hasFormula -and $formulaSamples.Count -lt 40) {
                  $formulaSamples.Add([ordered]@{
                    cell = Get-A1Address -Row $r -Column $c
                    formula = $formula
                  })
                }
              }
            }
          }

          $validationCount = 0
          $validationSamples = New-Object System.Collections.Generic.List[object]
          try {
            $valCells = $used.SpecialCells(-4174)
            $validationCount = [int64]$valCells.CountLarge
            foreach ($vc in $valCells.Cells) {
              if ($validationSamples.Count -ge 40) { break }
              try {
                $v = $vc.Validation
                $validationSamples.Add([ordered]@{
                  cell = [string]$vc.Address($false, $false)
                  type = Get-ValidationTypeName -TypeNumber $v.Type
                  operator = Get-ValidationOperatorName -OperatorNumber $v.Operator
                  formula1 = [string]$v.Formula1
                  formula2 = [string]$v.Formula2
                  inCellDropdown = [bool]$v.InCellDropdown
                  ignoreBlank = [bool]$v.IgnoreBlank
                })
              } catch {}
            }
            Release-ComObject $valCells
          } catch {}

          $filterInfo = [ordered]@{
            autoFilterMode = $false
            filterMode = $false
            range = ''
            activeCriteria = @()
          }
          try { $filterInfo.autoFilterMode = [bool]$ws.AutoFilterMode } catch {}
          try { $filterInfo.filterMode = [bool]$ws.FilterMode } catch {}
          try {
            if ($ws.AutoFilter -and $ws.AutoFilter.Range) {
              $filterInfo.range = [string]$ws.AutoFilter.Range.Address($false, $false)
              $criteria = New-Object System.Collections.Generic.List[object]
              $filters = $ws.AutoFilter.Filters
              for ($i = 1; $i -le [int]$filters.Count; $i++) {
                $f = $filters.Item($i)
                if ($f -and $f.On) {
                  $criteria1 = ''
                  $criteria2 = ''
                  $operator = ''
                  try { $criteria1 = [string]$f.Criteria1 } catch {}
                  try { $criteria2 = [string]$f.Criteria2 } catch {}
                  try { $operator = [string]$f.Operator } catch {}
                  $criteria.Add([ordered]@{
                    fieldIndex = $i
                    criteria1 = $criteria1
                    criteria2 = $criteria2
                    operator = $operator
                  })
                }
              }
              $filterInfo.activeCriteria = $criteria
            }
          } catch {}

          $cfCount = 0
          $cfSamples = New-Object System.Collections.Generic.List[object]
          try {
            $fcs = $used.FormatConditions
            $cfCount = [int]$fcs.Count
            for ($i = 1; $i -le [Math]::Min($cfCount, 25); $i++) {
              try {
                $rule = $fcs.Item($i)
                $cfOperator = ''
                $cfFormula1 = ''
                $cfFormula2 = ''
                $cfAppliesTo = ''
                try { $cfOperator = [string]$rule.Operator } catch {}
                try { $cfFormula1 = [string]$rule.Formula1 } catch {}
                try { $cfFormula2 = [string]$rule.Formula2 } catch {}
                try { $cfAppliesTo = [string]$rule.AppliesTo.Address($false, $false) } catch {}
                $cfSamples.Add([ordered]@{
                  type = [string]$rule.Type
                  operator = $cfOperator
                  formula1 = $cfFormula1
                  formula2 = $cfFormula2
                  appliesTo = $cfAppliesTo
                })
              } catch {}
            }
          } catch {}

          $protectContents = $false
          $protectDrawing = $false
          $protectScenarios = $false
          try { $protectContents = [bool]$ws.ProtectContents } catch {}
          try { $protectDrawing = [bool]$ws.ProtectDrawingObjects } catch {}
          try { $protectScenarios = [bool]$ws.ProtectScenarios } catch {}

          $sheetObj = [ordered]@{
            name = [string]$ws.Name
            visible = [int]$ws.Visible
            structure = [ordered]@{
              usedRange = $ranges.used
              effectiveRange = $ranges.effective
            }
            dataAndFormulas = [ordered]@{
              sampleValues = $sampleValues
              sampleFormulas = $formulaSamples
            }
            formats = [ordered]@{
              scannedCells = $scannedCells
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
            mergedCells = [ordered]@{
              count = $merged.Count
              sample = @($merged.Keys | Sort-Object | Select-Object -First 40)
            }
            dataValidation = [ordered]@{
              count = $validationCount
              sample = $validationSamples
            }
            filters = [ordered]@{
              autoFilterMode = $filterInfo.autoFilterMode
              filterMode = $filterInfo.filterMode
              range = $filterInfo.range
              activeCriteria = $filterInfo.activeCriteria
              filterViews = @()
            }
            conditionalFormatting = [ordered]@{
              count = $cfCount
              sample = $cfSamples
            }
            protections = [ordered]@{
              protectContents = $protectContents
              protectDrawingObjects = $protectDrawing
              protectScenarios = $protectScenarios
            }
          }

          $sheetOut.Add([pscustomobject]$sheetObj)
        } catch {
          $sheetOut.Add([pscustomobject]@{
            name = [string]$ws.Name
            scanError = $_.Exception.Message
          })
        } finally {
          Release-ComObject $used
          Release-ComObject $ws
        }
      }

      $bookObj.worksheets = $sheetOut
    } catch {
      $bookObj.errors += $_.Exception.Message
    } finally {
      if ($null -ne $wb) {
        try { $wb.Close($false) } catch {}
        Release-ComObject $wb
      }
    }

    $booksOut.Add([pscustomobject]$bookObj)
  }
} finally {
  if ($null -ne $excel) {
    try { $excel.Quit() } catch {}
    Release-ComObject $excel
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
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
  workbookCount = $booksOut.Count
  workbooks = $booksOut
}

$result | ConvertTo-Json -Depth 30 | Set-Content -Path $outPath -Encoding UTF8
Write-Output ('EXCEL_DEEP_AUDIT_OK=' + $outPath)





