# ============================================================
# build-updater.ps1 -- Bien dich UpdaterApp.exe bang csc.exe
# (khong can cai gi - csc co san trong Windows)
#
# Output: installer\updater\UpdaterApp.exe
# ============================================================

param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root "installer\updater\UpdaterApp.cs"
$outExe = Join-Path $root "installer\updater\UpdaterApp.exe"
$csc    = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"

if (-not (Test-Path -LiteralPath $csc)) { throw "Thieu csc.exe: $csc" }
if (-not (Test-Path -LiteralPath $src)) { throw "Thieu source: $src" }

$refs = @(
    "System.dll"
    "System.Core.dll"
    "System.IO.Compression.dll"
    "System.IO.Compression.FileSystem.dll"
) | ForEach-Object { "/reference:$($_)" }

if (-not $Quiet) { Write-Host "=== BUILD UPDATER ===" -ForegroundColor Cyan }
& $csc /nologo /target:exe /codepage:65001 /optimize+ `
    "/out:$outExe" $refs $src

if ($LASTEXITCODE -ne 0) { throw "Bien dich UpdaterApp that bai (csc exit $LASTEXITCODE)" }

$kb = [math]::Round((Get-Item -LiteralPath $outExe).Length / 1KB, 1)
if (-not $Quiet) {
    Write-Host ("  Output: {0}" -f $outExe) -ForegroundColor Green
    Write-Host ("  Dung luong: {0} KB" -f $kb)
}
Write-Output $outExe