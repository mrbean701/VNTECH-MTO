# ============================================================
# export-excel.ps1 -- Xuat ket qua MTO ra Excel (.xlsx) tu CSV
#
# Buoc 1: doc CSV (AutoLISP ghi ANSI + escape \U+XXXX) -> GIAI MA Unicode
# Buoc 2: ghi CSV da giai ma ra file tam (UTF-8 BOM de Excel doc dung tieng Viet)
# Buoc 3: mo bang Excel, format header, luu .xlsx
#
# Cach dung:
#   .\export-excel.ps1 -Csv "duong-dan.csv"
#   .\export-excel.ps1 -Csv "..." -Xlsx "ket-qua.xlsx"
# ============================================================

param(
    [Parameter(Mandatory=$true)][string]$Csv,
    [string]$Xlsx = "",
    [string]$SheetName = "KHOI LUONG"
)

$ErrorActionPreference = "Stop"
$Csv = [IO.Path]::GetFullPath($Csv)
if (-not (Test-Path -LiteralPath $Csv)) { throw "Khong tim thay CSV: $Csv" }
if ($Xlsx -eq "") { $Xlsx = [IO.Path]::ChangeExtension($Csv, ".xlsx") }
$Xlsx = [IO.Path]::GetFullPath($Xlsx)

# ---- Giai ma escape Unicode cua AutoLISP: \U+1EE6 -> ky tu that ----
function ConvertFrom-AutoLispEscape {
    param([string]$s)
    if ($null -eq $s) { return "" }
    $s = $s.TrimStart([char]0xFEFF)
    return [regex]::Replace($s, '\\U\+([0-9A-Fa-f]{4})', {
        param($m)
        try { return [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) } catch { return $m.Value }
    })
}

# ---- Doc CSV: thu UTF-8, neu hong thi ANSI(1258) ----
$raw = [IO.File]::ReadAllText($Csv, [Text.Encoding]::UTF8)
if ($raw.IndexOf([char]0xFFFD) -ge 0) {
    $raw = [IO.File]::ReadAllText($Csv, [Text.Encoding]::GetEncoding(1258))
}
$raw = ConvertFrom-AutoLispEscape $raw

# ---- Ghi ra file tam (UTF-8 BOM) de Excel doc dung tieng Viet ----
$tmp = Join-Path $env:TEMP ("mto-export-" + [Guid]::NewGuid().ToString("N") + ".csv")
[IO.File]::WriteAllText($tmp, $raw, (New-Object Text.UTF8Encoding($true)))

$lines = $raw -split "`r?`n" | Where-Object { $_ -ne "" }
Write-Host ("CSV: {0} dong ({1} du lieu)" -f $lines.Count, ($lines.Count - 1))

# ---- Mo bang Excel ----
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$wb = $null
try {
    $wb = $xl.Workbooks.Open($tmp, 0, $true)      # read-only
    $ws = $wb.Worksheets.Item(1)
    $ws.Name = $SheetName

    $used = $ws.UsedRange
    $nRows = $used.Rows.Count
    $nCols = $used.Columns.Count

    $hdr = $ws.Range($ws.Cells.Item(1, 1), $ws.Cells.Item(1, $nCols))
    $hdr.Font.Bold = 1
    $hdr.Interior.ColorIndex = 15
    $hdr.HorizontalAlignment = -4108

    $all = $ws.Range($ws.Cells.Item(1, 1), $ws.Cells.Item($nRows, $nCols))
    $all.Borders.LineStyle = 1
    $ws.Columns.AutoFit() | Out-Null
    for ($c = 1; $c -le $nCols; $c++) {
        if ($ws.Columns.Item($c).ColumnWidth -gt 42) { $ws.Columns.Item($c).ColumnWidth = 42 }
    }

    if (Test-Path -LiteralPath $Xlsx) { Remove-Item -LiteralPath $Xlsx -Force }
    $wb.SaveAs($Xlsx, 51)     # 51 = xlOpenXMLWorkbook
    $wb.Close($false)
    $wb = $null

    $kb = [math]::Round((Get-Item -LiteralPath $Xlsx).Length / 1KB, 1)
    Write-Host ""
    Write-Host "=== XUAT EXCEL XONG ===" -ForegroundColor Green
    Write-Host ("  File      : {0}" -f $Xlsx)
    Write-Host ("  Dung luong: {0} KB" -f $kb)
    Write-Host ("  Kich thuoc: {0} dong x {1} cot" -f $nRows, $nCols)
}
finally {
    if ($wb) { try { $wb.Close($false) } catch { } }
    try { $xl.Quit() } catch { }
    try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl) } catch { }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
