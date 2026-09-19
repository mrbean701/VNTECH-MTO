# ============================================================
# run-all-tests.ps1 -- Chay TOAN BO test suite MTO LISP
# Dat tai: MTOPlugin/lisp/tests/run-all-tests.ps1
#
# Cach dung:
#   .\run-all-tests.ps1
# Exit code: 0 = tat ca PASS, 1 = co FAIL
# ============================================================

$ErrorActionPreference = "Continue"

$testDir = $PSScriptRoot
$runner  = Join-Path $testDir "run-tests.ps1"

$suites = @(
    "test-core.lsp",
    "test-select.lsp",
    "test-text.lsp",
    "test-block.lsp",
    "test-geometry.lsp",
    "test-result.lsp",
    "test-csv.lsp",
    "test-orphan.lsp",
    "test-loader.lsp",
    "test-table.lsp",
    "test-find.lsp",
    "test-update.lsp",
    "test-undo.lsp",
    "test-formula.lsp",
    "test-subtotal.lsp",
    "test-floor.lsp",
    "test-config.lsp",
    "test-selfup.lsp"
)

$results = @()
$totalPass = 0
$totalTests = 0
$anyFail = $false

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " MTO LISP -- FULL TEST SUITE" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# ---- BUOC 0: LINT cu phap TAT CA file LISP (chan loi cu phap lot qua) ----
Write-Host ""
Write-Host "[0] LINT cu phap..." -ForegroundColor Cyan
$lintOut = & powershell -ExecutionPolicy Bypass -File (Join-Path $testDir "check-lisp-syntax.ps1") 2>&1
$lintOut | Select-Object -Last 2 | ForEach-Object { Write-Host "    $_" }
$lintOk = ($LASTEXITCODE -eq 0)
if (-not $lintOk) {
    Write-Host "KET LUAN: LOI CU PHAP -- dung lai, khong chay test" -ForegroundColor Red
    exit 2
}

Write-Host ""
Write-Host "[1] Chay test suite..." -ForegroundColor Cyan

foreach ($s in $suites) {
    $out = & powershell -ExecutionPolicy Bypass -File $runner -TestFile $s 2>&1
    $verdict = $out | Where-Object { $_ -like "*KET LUAN:*" } | Select-Object -First 1
    $summary = $out | Where-Object { $_ -like "TESTS:*" } | Select-Object -First 1

    $ok = ($verdict -like "*PASS*") -and ($verdict -notlike "*FAIL*")
    if (-not $ok) { $anyFail = $true }

    # tach "n/m" tu summary
    if ($summary -match "TESTS:\s*(\d+)/(\d+)") {
        $totalPass  += [int]$Matches[1]
        $totalTests += [int]$Matches[2]
    }

    $color = if ($ok) { "Green" } else { "Red" }
    Write-Host ("{0,-20} {1}" -f $s, $verdict) -ForegroundColor $color

    $results += [pscustomobject]@{
        Suite   = $s
        Verdict = $verdict
        Summary = $summary
        Pass    = $ok
    }
}

Write-Host "----------------------------------------------" -ForegroundColor Cyan
Write-Host ("TONG: {0}/{1} test PASSED" -f $totalPass, $totalTests) -ForegroundColor Yellow

if ($anyFail) {
    Write-Host "KET LUAN: CO SUITE FAIL" -ForegroundColor Red
    exit 1
} else {
    Write-Host "KET LUAN: TAT CA PASS" -ForegroundColor Green
    exit 0
}
