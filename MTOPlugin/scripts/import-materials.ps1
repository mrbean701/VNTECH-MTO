# ============================================================
# import-materials.ps1 -- Doc DANH MUC VAT TU (Excel) -> sinh rules.json
#
# Input : config\DANH_MUC_VAT_TU.xlsx  (sheet DANH_MUC)
# Output: config\rules.json            (dung truc tiep cho MTOPro)
#
# Cach dung:
#   .\import-materials.ps1
#   .\import-materials.ps1 -Xlsx "duong-dan.xlsx" -Out "rules.json"
#   .\import-materials.ps1 -DryRun        # chi kiem tra, khong ghi file
# ============================================================

param(
    [string]$Xlsx = "",
    [string]$Out = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ($Xlsx -eq "") { $Xlsx = Join-Path $root "config\DANH_MUC_VAT_TU.xlsx" }
if ($Out  -eq "") { $Out  = Join-Path $root "config\rules.json" }
$Xlsx = [IO.Path]::GetFullPath($Xlsx)
$Out  = [IO.Path]::GetFullPath($Out)

if (-not (Test-Path -LiteralPath $Xlsx)) { throw "Khong tim thay file danh muc: $Xlsx" }

Write-Host "=== IMPORT DANH MUC VAT TU -> RULES ===" -ForegroundColor Cyan
Write-Host ("  Nguon : {0}" -f $Xlsx)
Write-Host ("  Dich  : {0}" -f $Out)
Write-Host ""

# ---- Doc Excel ----
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$rows = @()
try {
    $wb = $xl.Workbooks.Open($Xlsx, 0, $true)
    $ws = $wb.Worksheets.Item("DANH_MUC")
    if ($null -eq $ws) { throw "Khong tim thay sheet 'DANH_MUC'" }

    $used = $ws.UsedRange
    $nRows = $used.Rows.Count
    $nCols = $used.Columns.Count
    Write-Host ("  Sheet DANH_MUC: {0} dong x {1} cot" -f $nRows, $nCols)

    # header dong 1
    $headers = @()
    for ($c = 1; $c -le $nCols; $c++) {
        $headers += ([string]$ws.Cells.Item(1, $c).Text).Trim()
    }

    for ($r = 2; $r -le $nRows; $r++) {
        $vals = @()
        for ($c = 1; $c -le $nCols; $c++) {
            $vals += [string]$ws.Cells.Item($r, $c).Text
        }
        # bo qua dong trong
        $joined = ($vals -join "").Trim()
        if ($joined -eq "") { continue }
        $rows += ,@($vals)
    }
    $wb.Close($false)
    $wb = $null
}
finally {
    if ($wb) { try { $wb.Close($false) } catch { } }
    try { $xl.Quit() } catch { }
    try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl) } catch { }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}

Write-Host ("  So dong du lieu: {0}" -f $rows.Count)
Write-Host ""

# ---- Chi so cot (0-based) ----
$CI = @{
    STT=0; CODE=1; NAME=2; SPEC=3; UNIT=4; SYSTEM=5; BLOCK=6; LAYER=7;
    CALC=8; FACTOR=9; PRIORITY=10; STATUS=11; NOTE=12
}

function Get-Cell($row, $idx) {
    if ($idx -lt $row.Count) { return ([string]$row[$idx]).Trim() }
    return ""
}

# ---- Chuyen doi ----
$rules = New-Object System.Collections.ArrayList
$systems = @{}
$errors = New-Object System.Collections.ArrayList
$warn = New-Object System.Collections.ArrayList
$n = 0

foreach ($row in $rows) {
    $n++
    $code = Get-Cell $row $CI.CODE
    $name = Get-Cell $row $CI.NAME
    $unit = Get-Cell $row $CI.UNIT
    $sysc = Get-Cell $row $CI.SYSTEM
    $blk  = Get-Cell $row $CI.BLOCK
    $lay  = Get-Cell $row $CI.LAYER
    $calc = Get-Cell $row $CI.CALC
    $fac  = Get-Cell $row $CI.FACTOR
    $prio = Get-Cell $row $CI.PRIORITY
    $stat = Get-Cell $row $CI.STATUS
    $note = Get-Cell $row $CI.NOTE
    $spec = Get-Cell $row $CI.SPEC

    # --- Kiem tra bat buoc ---
    if ($code -eq "" -or $name -eq "" -or $unit -eq "") {
        [void]$errors.Add("Dong $($n+1): THIEU Ma vat tu / Ten / Don vi")
        continue
    }
    if (($blk -eq "") -and ($lay -eq "")) {
        # Khong co dieu kien nhan dang -> van tao nhung la Draft
        [void]$warn.Add("$code ($name): chua co Ten block/Layer -> dat Draft")
        $stat = "Draft"
    }

    if ($sysc -eq "") { $sysc = "HE-KHAC" }
    if (-not $systems.ContainsKey($sysc)) { $systems[$sysc] = $sysc }

    if ($calc -eq "") { $calc = "Count" }
    # chuan hoa ten cach tinh
    $calcMap = @{ "count"="Count"; "dem"="Count"; "sumlength"="SumLength"; "dai"="SumLength";
                  "sumarea"="SumArea"; "dientich"="SumArea"; "attributesum"="AttributeSum" }
    $ck = $calc.ToLower().Replace(" ","")
    if ($calcMap.ContainsKey($ck)) { $calc = $calcMap[$ck] }

    $f = 1.0
    if ($fac -ne "") { try { $f = [double]::Parse($fac, [Globalization.CultureInfo]::InvariantCulture) } catch { $f = 1.0 } }

    $p = 100
    if ($prio -ne "") { try { $p = [int]$prio } catch { $p = 100 } }

    if ($stat -eq "") { $stat = "Active" }
    if ($stat -notin @("Active","Draft","Obsolete")) { $stat = "Active" }

    # --- Dieu kien nhan dang ---
    # BUG DA GAP: truoc day set entityKind = "both" khi co ca block+layer
    # -> RuleMatcher.MatchesBlock kiem tra MatchScalar(EntityKind,"block")
    #    nen "both" KHONG khop "block" => rule khong bao gio khop!
    # Sua: co blockNames -> entityKind = "block" (block cung co layer;
    #      layers khi do la dieu kien PHU). Chi co layer -> "geometry".
    $cond = [ordered]@{}
    if ($blk -ne "") { $cond["entityKind"] = "block" }
    else { $cond["entityKind"] = "geometry" }

    if ($blk -ne "") { $cond["blockNames"] = ($blk -replace '\s*;\s*',';') }
    if ($lay -ne "") { $cond["layers"] = ($lay -replace '\s*;\s*',';') }
    if ($cond["entityKind"] -eq "geometry") { $cond["geometryKinds"] = "Line;Polyline;Polyline2D;Polyline3D;Arc;Circle" }

    # --- Rule ---
    $rule = [ordered]@{
        code         = "R-" + $code
        version      = "1.0"
        description  = $note
        systemCode   = $sysc
        materialCode = $code
        materialName = $name
        specification= $spec
        unit         = $unit
        conditions   = @($cond)
        calculation  = $calc
        factor       = $f
        priority     = $p
        status       = $stat
    }
    [void]$rules.Add($rule)
}

# ---- Bao cao kiem tra ----
Write-Host "---- KET QUA KIEM TRA ----"
Write-Host ("  Hop le    : {0} vat tu" -f $rules.Count) -ForegroundColor Green
Write-Host ("  Canh bao  : {0}" -f $warn.Count) -ForegroundColor Yellow
Write-Host ("  Loi       : {0}" -f $errors.Count) -ForegroundColor Red
Write-Host ""

if ($warn.Count -gt 0) {
    Write-Host "CANH BAO (van nhap, nhung dat Draft):"
    $warn | Select-Object -First 15 | ForEach-Object { Write-Host ("  - " + $_) -ForegroundColor Yellow }
    Write-Host ""
}
if ($errors.Count -gt 0) {
    Write-Host "LOI (BI BO QUA):"
    $errors | Select-Object -First 15 | ForEach-Object { Write-Host ("  - " + $_) -ForegroundColor Red }
    Write-Host ""
    if ($errors.Count -gt 15) { Write-Host ("  ... va {0} loi khac" -f ($errors.Count - 15)) }
    Write-Host ""
}

if ($rules.Count -eq 0) { throw "Khong co vat tu hop le nao -> khong tao rules.json" }

# ---- Thong ke ----
$bySystem = $rules | Group-Object { $_.systemCode } | Sort-Object Name
Write-Host "PHAN BO THEO HE:"
foreach ($g in $bySystem) { Write-Host ("  {0,-16} {1} vat tu" -f $g.Name, $g.Count) }
$byCalc = $rules | Group-Object { $_.calculation } | Sort-Object Name
Write-Host "PHAN BO THEO CACH TINH:"
foreach ($g in $byCalc) { Write-Host ("  {0,-16} {1} vat tu" -f $g.Name, $g.Count) }
Write-Host ""

if ($DryRun) {
    Write-Host "DRY-RUN: khong ghi file." -ForegroundColor Yellow
    return
}

# ---- Ghi rules.json ----
$sysList = @()
foreach ($k in ($systems.Keys | Sort-Object)) {
    $sysList += [ordered]@{ code = $k; name = $k }
}

$doc = [ordered]@{
    name        = "Bo quy tac vat tu - " + (Get-Date -Format "yyyyMMdd")
    version     = "1.0"
    description = "Sinh tu danh muc vat tu cua cong ty bang import-materials.ps1"
    sourceFile  = [IO.Path]::GetFileName($Xlsx)
    importedAt  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    systems     = $sysList
    rules       = $rules
}

$json = $doc | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText($Out, $json, (New-Object Text.UTF8Encoding($false)))

Write-Host "=== DA TAO RULES ===" -ForegroundColor Green
Write-Host ("  File: {0} ({1} KB)" -f $Out, [math]::Round((Get-Item $Out).Length/1KB,1))
Write-Host ("  {0} rule | {1} he" -f $rules.Count, $sysList.Count)
Write-Host ""
Write-Host "BUOC TIEP: mo AutoCAD, chay MTO, chon file quy tac nay." -ForegroundColor Cyan