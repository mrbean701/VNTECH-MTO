# ============================================================
# check-lisp-syntax.ps1 -- Kiem tra co ban cu phap file LISP
#
# Phat hien: ngoac ( ) lech, string khong dong.
# Day la lop kiem tra TINH (khong can AutoCAD), chay TRUOC moi test.
#
# Cach dung:
#   .\check-lisp-syntax.ps1
# Exit code: 0 = tat ca OK, 1 = co file loi
# ============================================================

param(
    [string]$Dir = ""
)

$ErrorActionPreference = "Stop"

if ($Dir -eq "") {
    $Dir = Split-Path -Parent $PSScriptRoot   # thu muc lisp/
}

$files = Get-ChildItem -Path $Dir -Filter "*.lsp" -File | Sort-Object Name
$testFiles = @()
$testDir = Join-Path $Dir "tests"
if (Test-Path $testDir) {
    $testFiles = Get-ChildItem -Path $testDir -Filter "*.lsp" -File | Sort-Object Name
}

$all = @($files) + @($testFiles)
$bad = 0

Write-Host ""
Write-Host "=== LISP SYNTAX CHECK (ngoac + string) ===" -ForegroundColor Cyan

foreach ($f in $all) {
    $text = Get-Content $f.FullName -Raw
    $depth = 0
    $inString = $false
    $line = 1
    $firstBadLine = -1
    $firstBadReason = ""
    $minDepth = 0

    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($c -eq "`n") { $line++; continue }

        if ($inString) {
            if ($c -eq '\') { $i++; continue }   # escape
            if ($c -eq '"')  { $inString = $false }
            continue
        }

        if ($c -eq ';') {
            # comment den het dong
            while ($i -lt $text.Length -and $text[$i] -ne "`n") { $i++ }
            $line++
            continue
        }

        if ($c -eq '"') { $inString = $true; continue }
        if ($c -eq '(') { $depth++ }
        if ($c -eq ')') {
            $depth--
            if ($depth -lt 0 -and $firstBadLine -lt 0) {
                $firstBadLine = $line
                $firstBadReason = "thua ngoac dong"
            }
        }
    }

    $ok = $true
    $reason = ""
    if ($inString) { $ok = $false; $reason = "string khong dong" }
    elseif ($firstBadLine -gt 0) { $ok = $false; $reason = "thua ngoac dong o DONG $firstBadLine (depth cuoi = $depth)" }
    elseif ($depth -ne 0) { $ok = $false; $reason = "lech ngoac: depth=$depth (thua $([math]::Abs($depth)) ngoac)" }

    # ---- Kiem tra dung ten bien `t` (symbol bao ve cua AutoLISP) ----
    # Da tung gay loi that: "incorrect object to bind: T"
    if ($ok) {
        $ln = 0
        foreach ($textLine in ($text -split "`r?`n")) {
            $ln++
            $code = $textLine
            # bo comment
            $ci = $code.IndexOf(';')
            if ($ci -ge 0) { $code = $code.Substring(0, $ci) }
            if ($code -eq "") { continue }
            # (foreach t ...)  hoac  bien local trong defun: (defun f (a / x t y)
            if ($code -match '\(\s*foreach\s+t\s' ) {
                $ok = $false; $reason = "dung bien 't' trong foreach (dong $ln) -> loi 'incorrect object to bind: T'"
                break
            }
            if ($code -match '\(\s*defun\s+[^\s]+\s+\([^)]*/\s[^)]*\bt\b[^)]*\)') {
                $ok = $false; $reason = "khai bao bien local 't' trong defun (dong $ln) -> loi 'incorrect object to bind: T'"
                break
            }
            if ($code -match '\(\s*setq\s+t\s') {
                $ok = $false; $reason = "gan gia tri cho 't' (dong $ln) -> loi 'incorrect object to bind: T'"
                break
            }
        }
    }

    if ($ok) {
        Write-Host ("  OK   {0}" -f $f.Name) -ForegroundColor DarkGreen
    } else {
        Write-Host ("  FAIL {0} -- {1}" -f $f.Name, $reason) -ForegroundColor Red
        $bad++
    }
}

Write-Host "-----------------------------------------" -ForegroundColor Cyan
if ($bad -eq 0) {
    Write-Host ("KET LUAN: {0} file OK" -f $all.Count) -ForegroundColor Green
    exit 0
} else {
    Write-Host ("KET LUAN: {0}/{1} file LOI CU PHAP" -f $bad, $all.Count) -ForegroundColor Red
    exit 1
}
