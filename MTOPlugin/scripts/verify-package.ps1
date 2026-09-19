$ErrorActionPreference = "Continue"
$L = Join-Path $env:LOCALAPPDATA "MTOPro\lisp"
$b = Join-Path $env:APPDATA "Autodesk\ApplicationPlugins\MTOPro.2023.bundle\Contents\Windows"
$dll = Join-Path $b "MTOPlugin.dll"
$acad = "D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe"
$t = Join-Path $env:TEMP "mtofinal"
New-Item -ItemType Directory -Force -Path $t | Out-Null
$scr = Join-Path $t "f.scr"
$lp = ($L -replace '\\', '/')
$dl = ($dll -replace '\\', '/')

$lines = @()
$lines += '(setvar "SECURELOAD" 0)'
$lines += '(setq *MTO-HOME* "' + $lp + '")'
$lines += '(load "' + $lp + '/mto-loader.lsp")'
$lines += '(princ (strcat "\nCHECK-MTOBLK=" (if (null (vl-symbol-value (quote c:MTOBLK))) "NO" "YES")))'
$lines += '(princ (strcat "\nCHECK-MTOCFG=" (if (null (vl-symbol-value (quote c:MTOCFG))) "NO" "YES")))'
$lines += '(princ (strcat "\nCHECK-LOADED=" (itoa (cdr (assoc (quote OK) *MTO-LOAD-RESULT*))) "/" (itoa (length *MTO-MODULES*))))'
$lines += '(command "_.NETLOAD" "' + $dl + '")'
$lines += 'MTOZOOM'
$lines += '1A2B'
$lines += '(princ "\n=== ALL-END ===")'
$lines += '(quit)'

Set-Content -Path $scr -Value $lines -Encoding ASCII

$p = Start-Process -FilePath $acad -ArgumentList "/s", "`"$scr`"" -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $t "o.txt")
if (-not $p.WaitForExit(90000)) { $p.Kill(); Write-Host "TIMEOUT (da kill)" }

$raw = (Get-Content (Join-Path $t "o.txt") -Raw) -replace "`0", ""
$raw -split "`r?`n" | Where-Object { $_ -match 'CHECK-|MTOPro v|Nhap Handle|Khong tim thay|ALL-END' } | Select-Object -First 12
