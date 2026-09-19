# ============================================================
# run-tests.ps1 -- Chay selftest LISP headless qua accoreconsole
# Dat tai: MTOPlugin/lisp/tests/run-tests.ps1
#
# Cach dung:
#   .\run-tests.ps1
#   .\run-tests.ps1 -Dwg "D:\...\Electrical Power.dwg"
#   .\run-tests.ps1 -TestFile test-core.lsp
# ============================================================

param(
    [string]$Dwg = "",
    [string]$TestFile = "test-core.lsp",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# ---- Duong dan ----
$testDir  = $PSScriptRoot
$lispDir  = Split-Path -Parent $testDir
$projRoot = Split-Path -Parent $lispDir

$outDir     = Join-Path $testDir "out"
$resultsPath = Join-Path $outDir "results.txt"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
if (Test-Path $resultsPath) { Remove-Item $resultsPath -Force }

# ---- Tim accoreconsole.exe ----
$candidates = @(
    "D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe",
    "C:\Program Files\Autodesk\AutoCAD 2026\accoreconsole.exe",
    "C:\Program Files\Autodesk\AutoCAD 2025\accoreconsole.exe",
    "C:\Program Files\Autodesk\AutoCAD 2024\accoreconsole.exe",
    "C:\Program Files\Autodesk\AutoCAD 2023\accoreconsole.exe",
    "C:\Program Files\Autodesk\AutoCAD 2022\accoreconsole.exe"
)
$acad = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $acad) {
    Write-Host "TEST ENVIRONMENT: AutoCAD accoreconsole unavailable" -ForegroundColor Yellow
    Write-Host "Khong tim thay accoreconsole.exe trong cac duong dan da biet." -ForegroundColor Yellow
    exit 3
}

Write-Host "accoreconsole: $acad"

# ---- Helper: chuyen sang duong dan kieu LISP ----
function ToLispPath([string]$p) { return ($p -replace '\\', '/') }

# ---- Helper: kiem tra can bang ngoac / string cua file LISP ----
# LY DO: mot file co the co loi cu phap o CUOI file trong khi cac defun
# phia truoc van duoc dinh nghia => test van PASS nhung file KHONG load sach.
# Lop kiem tra nay chan loai loi do.
function Test-LispBalance([string]$path) {
    $text = Get-Content $path -Raw
    $depth = 0; $inString = $false; $line = 1; $badLine = -1
    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($c -eq "`n") { $line++; continue }
        if ($inString) {
            if ($c -eq '\') { $i++; continue }
            if ($c -eq '"') { $inString = $false }
            continue
        }
        if ($c -eq ';') {
            while ($i -lt $text.Length -and $text[$i] -ne "`n") { $i++ }
            $line++; continue
        }
        if ($c -eq '"') { $inString = $true; continue }
        if ($c -eq '(') { $depth++ }
        if ($c -eq ')') {
            $depth--
            if ($depth -lt 0 -and $badLine -lt 0) { $badLine = $line }
        }
    }
    if ($inString) { return "string khong dong" }
    if ($depth -ne 0) { return "lech ngoac: depth=$depth" }
    if ($badLine -gt 0) { return "thua ngoac dong (dong $badLine)" }
    return $null
}

# Auto-load MOI file .lsp trong lisp/ (khong de quy; tests/ nam rieng)
$libFiles = @(Get-ChildItem -Path $lispDir -Filter "*.lsp" -File | Sort-Object Name)

$fwFile   = Join-Path $testDir "framework.lsp"
$testPath = Join-Path $testDir $TestFile

foreach ($f in @($fwFile, $testPath)) {
    if (-not (Test-Path $f)) {
        Write-Error "Thieu file: $f"
        exit 2
    }
}
if ($libFiles.Count -eq 0) {
    Write-Error "Khong tim thay module .lsp nao trong $lispDir"
    exit 2
}

Write-Host ("Modules: " + (($libFiles | ForEach-Object { $_.Name }) -join ", "))

# ---- BUOC 1: LINT cu phap TRUOC khi chay ----
$lintBad = 0
foreach ($f in (@($libFiles) + @(Get-Item $fwFile) + @(Get-Item $testPath))) {
    $err = Test-LispBalance $f.FullName
    if ($err) {
        Write-Host ("  LINT-FAIL {0}: {1}" -f $f.Name, $err) -ForegroundColor Red
        $lintBad++
    }
}
if ($lintBad -gt 0) {
    Write-Host ("KET LUAN: LOI CU PHAP ({0} file) -- khong chay test" -f $lintBad) -ForegroundColor Red
    exit 2
}

# ---- Sinh script .scr ----
# LUU Y: AutoCAD mac dinh SECURELOAD=1 -> chan (load ...) ngoai TRUSTEDPATHS
# ("File load canceled"). Harness tat SECURELOAD trong PHIEN TEST nay thoi
# (khong ghi vao registry / khong doi cau hinh nguoi dung).
$scrPath = Join-Path $outDir "run.scr"
$loadStatusPath = Join-Path $outDir "load-status.txt"
if (Test-Path $loadStatusPath) { Remove-Item $loadStatusPath -Force }

$scrLines = @()
$scrLines += "(setvar `"SECURELOAD`" 0)"
# Dat *MTO-HOME* de mto-loader nap dung cac module (findfile khong resolve abs path)
$scrLines += "(setq *MTO-HOME* `"$(ToLispPath $lispDir)`")"
$scrLines += "(setq *MTO-LOAD-FAIL* `"`")"
$scrLines += "(defun mto-qload (p) (if (vl-catch-all-error-p (vl-catch-all-apply 'load (list p))) (setq *MTO-LOAD-FAIL* (strcat *MTO-LOAD-FAIL* p `"|`"))))"
$scrLines += "(setq *MTO-RESULT-PATH* `"$(ToLispPath $resultsPath)`")"
foreach ($lf in $libFiles) {
    $scrLines += "(mto-qload `"$(ToLispPath $lf.FullName)`")"
}
$scrLines += "(mto-qload `"$(ToLispPath $fwFile)`")"
$scrLines += "(mto-qload `"$(ToLispPath $testPath)`")"
# ghi danh sach file load loi
$scrLines += "(setq __f (open `"$(ToLispPath $loadStatusPath)`" `"w`"))"
$scrLines += "(if __f (progn (write-line *MTO-LOAD-FAIL* __f) (close __f)))"
# Boc test run trong vl-catch-all-apply: neu test crash giua chung, van ghi
# duoc ket qua va bao TEST-FAIL thay vi mat trang file results.
$scrLines += "(setq *MTO-CATCH* (vl-catch-all-apply 'mto-run-tests (list *MTO-RESULT-PATH*)))"
$scrLines += "(if (vl-catch-all-error-p *MTO-CATCH*) (progn (setq *MTO-TEST-FAIL* (1+ *MTO-TEST-FAIL*)) (setq *MTO-TEST-LOG* (cons (strcat `"TEST-FAIL: UNCAUGHT-ERROR -- `" (vl-catch-all-error-message *MTO-CATCH*)) *MTO-TEST-LOG*))))"
$scrLines += "(mto-write-results *MTO-RESULT-PATH*)"
$scrLines += "(quit)"
Set-Content -Path $scrPath -Value $scrLines -Encoding ASCII

# ---- Chay ----
$useDwg = ($Dwg -ne "" -and (Test-Path $Dwg))
if ($useDwg) {
    Write-Host "DWG: $Dwg"
    & $acad /i $Dwg /s $scrPath 2>&1 | Out-Null
} else {
    & $acad /s $scrPath 2>&1 | Out-Null
}

# ---- Doc ket qua ----
if (-not (Test-Path $resultsPath)) {
    Write-Host "KHONG co file ket qua: $resultsPath" -ForegroundColor Red
    Write-Host "accoreconsole co the da loi khi load LISP." -ForegroundColor Red
    exit 2
}

# ---- BUOC 2: kiem tra LOAD STATUS (file nao load loi runtime) ----
if (Test-Path $loadStatusPath) {
    $failList = (Get-Content $loadStatusPath -Raw).Trim()
    if ($failList -ne "") {
        Write-Host "LINT/LOAD-FAIL:" -ForegroundColor Red
        foreach ($p in ($failList -split '\|' | Where-Object { $_ -ne "" })) {
            Write-Host ("  KHONG LOAD DUOC: {0}" -f $p) -ForegroundColor Red
        }
        Write-Host "KET LUAN: CO FILE KHONG LOAD SACH -- ket qua test KHONG dang tin" -ForegroundColor Red
        exit 2
    }
}

$text = Get-Content $resultsPath -Raw
$lines = $text -split "`r?`n" | Where-Object { $_ -ne "" }

Write-Host ""
Write-Host "---------- KET QUA TEST ----------" -ForegroundColor Cyan
foreach ($l in $lines) {
    if ($l -like "TEST-FAIL:*")     { Write-Host $l -ForegroundColor Red }
    elseif ($l -like "TEST-PASS:*") { Write-Host $l -ForegroundColor DarkGreen }
    else                            { Write-Host $l -ForegroundColor White }
}
Write-Host "---------------------------------" -ForegroundColor Cyan

$summary = $lines | Where-Object { $_ -like "TESTS:*" } | Select-Object -First 1
$verdict = $lines | Where-Object { $_ -like "RESULT:*" } | Select-Object -First 1

if ($verdict -eq "RESULT: ALL-PASS") {
    Write-Host "KET LUAN: PASS ($summary)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "KET LUAN: FAIL ($summary)" -ForegroundColor Red
    exit 1
}
