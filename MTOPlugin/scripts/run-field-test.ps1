# ============================================================
# run-field-test.ps1 -- Chay test MTO tren BAN VE THAT (DWG)
#
# Mo DWG bang accoreconsole, nap MTOPro, chay kich ban test,
# ghi ket qua ra file. KHONG sua ban ve goc (chi doc + ve them
# vao ban ve MOI khi test MTOTABLE).
#
# Cach dung:
#   .\run-field-test.ps1 -Dwg "D:\...\banve.dwg" -Script "survey.lsp" -Expr "(mto-survey ...)"
#   .\run-field-test.ps1 -Dwg "..." -FullTest
# ============================================================

param(
    [Parameter(Mandatory=$true)][string]$Dwg,
    [string]$Script = "survey.lsp",
    [string]$LispExpr = "",
    [string]$OutName = "",
    [string]$SaveTo = "",
    [int]$Mode = 0,
    [switch]$FullTest
)

$ErrorActionPreference = "Continue"

$root    = Split-Path -Parent $PSScriptRoot
$lispDir = Join-Path $root "lisp"
$testDir = Join-Path $lispDir "tests"
$outDir  = Join-Path $testDir "out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (-not (Test-Path -LiteralPath $Dwg)) { throw "Khong tim thay DWG: $Dwg" }
if ($OutName -eq "") { $OutName = [IO.Path]::GetFileNameWithoutExtension($Dwg) }

$resultFile = Join-Path $outDir ("FIELD-" + $OutName + ".txt")
$scrFile    = Join-Path $outDir ("field-" + $OutName + ".scr")
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

$acad = "D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe"
if (-not (Test-Path $acad)) { throw "Khong tim thay accoreconsole: $acad" }

function ToLisp([string]$p) { return ($p -replace '\\','/') }

# ---- Sinh script .scr ----
$lines = @()
$lines += '(setvar "SECURELOAD" 0)'
$lines += '(setvar "FILEDIA" 0)'
$lines += '(setq *MTO-HOME* "' + (ToLisp $lispDir) + '")'
$lines += '(load "' + (ToLisp (Join-Path $lispDir 'mto-loader.lsp')) + '")'
$lines += '(princ (strcat "\nFIELD: da nap " (itoa (cdr (assoc (quote OK) *MTO-LOAD-RESULT*))) "/16 module"))'

if ($FullTest) {
    $lines += '(load "' + (ToLisp (Join-Path $testDir 'fieldtest.lsp')) + '")'
    if ($SaveTo -ne "") {
        $lines += '(setq *FT-SAVE-TO* "' + (ToLisp $SaveTo) + '")'
        $lines += '(mto-fieldtest "' + (ToLisp $resultFile) + '" 2)'
    } else {
        $lines += '(mto-fieldtest "' + (ToLisp $resultFile) + '" ' + $Mode + ')'
    }
} else {
    $lines += '(load "' + (ToLisp (Join-Path $testDir $Script)) + '")'
    if ($LispExpr -ne "") {
        $lines += $LispExpr.Replace('__OUT__', (ToLisp $resultFile))
    }
}

$lines += '(princ "\nFIELD-END")'
$lines += '(quit)'

Set-Content -Path $scrFile -Value $lines -Encoding ASCII

Write-Host "=== FIELD TEST ===" -ForegroundColor Cyan
Write-Host ("  DWG     : {0}" -f $Dwg)
Write-Host ("  Size    : {0} MB" -f [math]::Round((Get-Item -LiteralPath $Dwg).Length/1MB,1))
Write-Host ("  Script  : {0}" -f $scrFile)
Write-Host ("  Result  : {0}" -f $resultFile)
Write-Host ""

$stdout = Join-Path $outDir ("field-" + $OutName + ".stdout.txt")
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath $acad -ArgumentList "/i", "`"$Dwg`"", "/s", "`"$scrFile`"" `
        -NoNewWindow -PassThru -RedirectStandardOutput $stdout
$timeoutMs = 600000
if (-not $p.WaitForExit($timeoutMs)) { $p.Kill(); Write-Host "TIMEOUT sau $($timeoutMs/1000)s (da kill)" -ForegroundColor Red }
$sw.Stop()
Write-Host ("  Thoi gian: {0:N1} s" -f $sw.Elapsed.TotalSeconds)
Write-Host ""

if (Test-Path $resultFile) {
    Write-Host "=== KET QUA (dau file) ===" -ForegroundColor Green
    Get-Content $resultFile -Encoding UTF8 | Select-Object -First 40
} else {
    Write-Host "KHONG co file ket qua. Stdout (dau):" -ForegroundColor Yellow
    if (Test-Path $stdout) {
        ((Get-Content $stdout -Raw) -replace "`0","") -split "`r?`n" | Where-Object { $_ -match 'FIELD|error|Error|Loi' } | Select-Object -First 20
    }
}
