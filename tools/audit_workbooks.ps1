param(
  [string[]]$WorkbookPaths,
  [string]$OutputJson = 'C:\Users\elrub\Desktop\CAPETA CODEX\contabilidad-ia-booking\audit\inputs\workbooks_audit_raw.json'
)

$ErrorActionPreference = 'Stop'

function Release-ComObject {
  param([Parameter(Mandatory=$false)]$ComObject)
  if ($null -ne $ComObject) {
    try { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ComObject) } catch {}
  }
}

if (-not $WorkbookPaths -or $WorkbookPaths.Count -eq 0) {
  throw 'Provide at least one workbook path in -WorkbookPaths'
}

$excel = $null
$results = New-Object System.Collections.Generic.List[object]

try {
  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $excel.AskToUpdateLinks = $false

  foreach ($path in $WorkbookPaths) {
    $wb = $null
    $workbookResult = [ordered]@{
      filePath = $path
      fileName = [System.IO.Path]::GetFileName($path)
      exists = (Test-Path $path)
      sizeBytes = if (Test-Path $path) { (Get-Item $path).Length } else { 0 }
      lastWriteTime = if (Test-Path $path) { (Get-Item $path).LastWriteTime.ToString('o') } else { '' }
      workbookSheetCount = 0
      definedNamesCount = 0
      externalLinks = @()
      calcVersion = ''
      hasVBProject = $false
      worksheets = @()
      riskFlags = @()
      errors = @()
    }

    if (-not (Test-Path $path)) {
      $workbookResult.errors += 'File not found'
      $results.Add([pscustomobject]$workbookResult)
      continue
    }

    try {
      $wb = $excel.Workbooks.Open($path, 0, $true)
      $workbookResult.workbookSheetCount = [int]$wb.Worksheets.Count
      $workbookResult.definedNamesCount = [int]$wb.Names.Count
      $workbookResult.calcVersion = [string]$wb.CalculationVersion
      try { $workbookResult.hasVBProject = [bool]$wb.HasVBProject } catch { $workbookResult.hasVBProject = $false }

      try {
        $links = $wb.LinkSources(1)
        if ($null -ne $links) {
          $workbookResult.externalLinks = @($links)
        }
      } catch {}

      $xlCellTypeFormulas = -4123
      $xlCellTypeConstants = 2
      $xlCellTypeAllValidation = -4174

      $sheetResults = New-Object System.Collections.Generic.List[object]

      foreach ($ws in $wb.Worksheets) {
        $used = $null
        $sheetObj = [ordered]@{
          name = [string]$ws.Name
          visible = [int]$ws.Visible
          protectContents = [bool]$ws.ProtectContents
          usedRange = [ordered]@{
            firstRow = 0
            firstColumn = 0
            rowCount = 0
            columnCount = 0
            lastRow = 0
            lastColumn = 0
          }
          effectiveRange = [ordered]@{
            firstDataRow = 0
            firstDataColumn = 0
            lastDataRow = 0
            lastDataColumn = 0
            effectiveRowCount = 0
            effectiveColumnCount = 0
            nonEmptyCells = 0
          }
          formulasCount = 0
          constantsCount = 0
          validationCellsCount = 0
          chartObjectsCount = 0
          pivotTablesCount = 0
          listObjectsCount = 0
          commentsCount = 0
          hyperlinksCount = 0
          headerSample = @()
          sampleRows = @()
          sheetRiskFlags = @()
          scanError = ''
        }

        try {
          $used = $ws.UsedRange
          $firstRow = [int]$used.Row
          $firstCol = [int]$used.Column
          $rowCount = [int]$used.Rows.Count
          $colCount = [int]$used.Columns.Count
          $lastRow = $firstRow + $rowCount - 1
          $lastCol = $firstCol + $colCount - 1

          $sheetObj.usedRange.firstRow = $firstRow
          $sheetObj.usedRange.firstColumn = $firstCol
          $sheetObj.usedRange.rowCount = $rowCount
          $sheetObj.usedRange.columnCount = $colCount
          $sheetObj.usedRange.lastRow = $lastRow
          $sheetObj.usedRange.lastColumn = $lastCol

          $vals = $used.Value2
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
                $text = if ($null -eq $v) { '' } else { [string]$v }
                if (-not [string]::IsNullOrWhiteSpace($text)) {
                  $nonEmpty++
                  if ($r -lt $minRelRow) { $minRelRow = $r }
                  if ($r -gt $maxRelRow) { $maxRelRow = $r }
                  if ($c -lt $minRelCol) { $minRelCol = $c }
                  if ($c -gt $maxRelCol) { $maxRelCol = $c }
                }
              }
            }
          }
          else {
            $v = $vals
            $text = if ($null -eq $v) { '' } else { [string]$v }
            if (-not [string]::IsNullOrWhiteSpace($text)) {
              $nonEmpty = 1
              $minRelRow = 1
              $maxRelRow = 1
              $minRelCol = 1
              $maxRelCol = 1
            }
          }

          $sheetObj.effectiveRange.nonEmptyCells = $nonEmpty

          if ($nonEmpty -gt 0) {
            $fdr = $firstRow + $minRelRow - 1
            $fdc = $firstCol + $minRelCol - 1
            $ldr = $firstRow + $maxRelRow - 1
            $ldc = $firstCol + $maxRelCol - 1

            $sheetObj.effectiveRange.firstDataRow = $fdr
            $sheetObj.effectiveRange.firstDataColumn = $fdc
            $sheetObj.effectiveRange.lastDataRow = $ldr
            $sheetObj.effectiveRange.lastDataColumn = $ldc
            $sheetObj.effectiveRange.effectiveRowCount = $ldr - $fdr + 1
            $sheetObj.effectiveRange.effectiveColumnCount = $ldc - $fdc + 1
          }

          try {
            $f = $used.SpecialCells($xlCellTypeFormulas)
            $sheetObj.formulasCount = [int64]$f.CountLarge
            Release-ComObject $f
          } catch { $sheetObj.formulasCount = 0 }

          try {
            $c = $used.SpecialCells($xlCellTypeConstants)
            $sheetObj.constantsCount = [int64]$c.CountLarge
            Release-ComObject $c
          } catch { $sheetObj.constantsCount = 0 }

          try {
            $v = $used.SpecialCells($xlCellTypeAllValidation)
            $sheetObj.validationCellsCount = [int64]$v.CountLarge
            Release-ComObject $v
          } catch { $sheetObj.validationCellsCount = 0 }

          try { $sheetObj.chartObjectsCount = [int]$ws.ChartObjects().Count } catch { $sheetObj.chartObjectsCount = 0 }
          try { $sheetObj.pivotTablesCount = [int]$ws.PivotTables().Count } catch { $sheetObj.pivotTablesCount = 0 }
          try { $sheetObj.listObjectsCount = [int]$ws.ListObjects.Count } catch { $sheetObj.listObjectsCount = 0 }
          try { $sheetObj.commentsCount = [int]$ws.Comments.Count } catch { $sheetObj.commentsCount = 0 }
          try { $sheetObj.hyperlinksCount = [int]$ws.Hyperlinks.Count } catch { $sheetObj.hyperlinksCount = 0 }

          $headerRow = if ($sheetObj.effectiveRange.firstDataRow -gt 0) { $sheetObj.effectiveRange.firstDataRow } else { $firstRow }
          $headerStartCol = if ($sheetObj.effectiveRange.firstDataColumn -gt 0) { $sheetObj.effectiveRange.firstDataColumn } else { $firstCol }
          $maxHeaderCols = [Math]::Min([Math]::Max($sheetObj.effectiveRange.effectiveColumnCount, $colCount), 30)

          $headers = @()
          for ($i = 0; $i -lt $maxHeaderCols; $i++) {
            $txt = [string]$ws.Cells.Item($headerRow, $headerStartCol + $i).Text
            if (-not [string]::IsNullOrWhiteSpace($txt)) {
              $headers += $txt.Trim()
            }
          }
          $sheetObj.headerSample = $headers

          $maxSampleRows = [Math]::Min($sheetObj.effectiveRange.effectiveRowCount, 8)
          $maxSampleCols = [Math]::Min([Math]::Max($sheetObj.effectiveRange.effectiveColumnCount, $colCount), 10)
          if ($maxSampleRows -gt 0 -and $maxSampleCols -gt 0 -and $headerRow -gt 0) {
            for ($r = 0; $r -lt $maxSampleRows; $r++) {
              $rowVals = @()
              for ($cix = 0; $cix -lt $maxSampleCols; $cix++) {
                $val = [string]$ws.Cells.Item($headerRow + $r, $headerStartCol + $cix).Text
                $rowVals += $val
              }
              $sheetObj.sampleRows += ,$rowVals
            }
          }

          if ($headers.Count -eq 0 -and $sheetObj.effectiveRange.nonEmptyCells -gt 20) {
            $sheetObj.sheetRiskFlags += 'No clear headers in first data row'
          }

          if ($sheetObj.effectiveRange.effectiveRowCount -gt 500 -and $sheetObj.formulasCount -eq 0) {
            $sheetObj.sheetRiskFlags += 'Large manual dataset without formulas'
          }

          if ($sheetObj.validationCellsCount -eq 0 -and $sheetObj.effectiveRange.effectiveRowCount -gt 50) {
            $sheetObj.sheetRiskFlags += 'No data validation in medium/large sheet'
          }

          if ($sheetObj.pivotTablesCount -eq 0 -and $sheetObj.chartObjectsCount -eq 0 -and $sheetObj.effectiveRange.effectiveRowCount -gt 120) {
            $sheetObj.sheetRiskFlags += 'No pivots/charts despite relevant data volume'
          }

          $usedCellsEstimate = [int64]([Math]::Max(1, ($sheetObj.effectiveRange.effectiveRowCount * [Math]::Max(1, $sheetObj.effectiveRange.effectiveColumnCount))))
          $formulaDensity = [math]::Round(($sheetObj.formulasCount / $usedCellsEstimate) * 100, 2)
          if ($formulaDensity -gt 80 -and $sheetObj.constantsCount -lt 40) {
            $sheetObj.sheetRiskFlags += 'Very high formula density with low manual inputs'
          }
        }
        catch {
          $sheetObj.scanError = $_.Exception.Message
        }
        finally {
          Release-ComObject $used
          Release-ComObject $ws
        }

        $sheetResults.Add([pscustomobject]$sheetObj)
      }

      $workbookResult.worksheets = $sheetResults

      if ($workbookResult.externalLinks.Count -gt 0) {
        $workbookResult.riskFlags += 'Workbook has external links'
      }

      if (($sheetResults | Measure-Object -Property formulasCount -Sum).Sum -eq 0) {
        $workbookResult.riskFlags += 'Workbook appears mostly manual (no formulas detected)'
      }

      $hiddenCount = ($sheetResults | Where-Object { $_.visible -ne -1 }).Count
      if ($hiddenCount -gt 0) {
        $workbookResult.riskFlags += ('Workbook has hidden sheets: ' + $hiddenCount)
      }

      $noValidationCount = ($sheetResults | Where-Object { $_.validationCellsCount -eq 0 -and $_.effectiveRange.effectiveRowCount -gt 50 }).Count
      if ($noValidationCount -gt 0) {
        $workbookResult.riskFlags += ('Sheets with no validation: ' + $noValidationCount)
      }
    }
    catch {
      $workbookResult.errors += $_.Exception.Message
    }
    finally {
      if ($null -ne $wb) {
        try { $wb.Close($false) } catch {}
        Release-ComObject $wb
      }
    }

    $results.Add([pscustomobject]$workbookResult)
  }
}
finally {
  if ($null -ne $excel) {
    try { $excel.Quit() } catch {}
    Release-ComObject $excel
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}

$final = [ordered]@{
  scannedAt = (Get-Date).ToString('o')
  workbookCount = $results.Count
  workbooks = $results
}

$final | ConvertTo-Json -Depth 25 | Set-Content -Path $OutputJson -Encoding UTF8
Write-Output ('AUDIT_RAW_OK=' + $OutputJson)
