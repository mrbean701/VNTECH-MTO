param(
    [Parameter(Mandatory = $false)]
    [ValidateSet(2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026)]
    [int]$AcadVersion = 2025,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Release', 'Debug')]
    [string]$Config = 'Release'
)

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$srcTfm = if ($AcadVersion -ge 2025) { 'net8.0-windows' } else { 'net48' }
$srcOut = Join-Path $root "src\MTOPlugin\bin\$Config\$srcTfm"

function Get-BundleFolder([int]$v) {
    if ($v -le 2022) { return 'MTOPlugin.2018-2022.bundle' }
    if ($v -le 2024) { return 'MTOPlugin.2023-2024.bundle' }
    return 'MTOPlugin.2025-2026.bundle'
}

$bundleName = Get-BundleFolder $AcadVersion
$bundleDir  = Join-Path $root "installer\bundles\$bundleName\Contents\Windows"

if (-not (Test-Path -LiteralPath $srcOut)) {
    throw "Khong tim thay thu muc output: $srcOut`nHay build truoc: scripts\build.ps1 -AcadVersion $AcadVersion -Config $Config"
}

# DLL + dependencies can thiet (EPPlus/LSJSON do NuGet tao ra trong output)
$files = @(
    'MTOPlugin.dll',
    'MTOPlugin.Core.dll',
    'MTOPlugin.UI.dll',
    'MTOPlugin.Logging.dll',
    'EPPlus.dll',
    'Newtonsoft.Json.dll'
)

New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null

$missing = $files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $srcOut $_)) }
if ($missing) {
    throw "Thieu DLL trong output: $($missing -join ', ')"
}

foreach ($f in $files) {
    Copy-Item -LiteralPath (Join-Path $srcOut $f) -Destination $bundleDir -Force
}

# Bao gồm mọi DLL phụ trợ khác từ output (vd System.Text.Encoding.CodePages) nếu có
Get-ChildItem -LiteralPath $srcOut -Filter '*.dll' | ForEach-Object {
    if ($files -notcontains $_.Name) {
        Copy-Item -LiteralPath $_.FullName -Destination $bundleDir -Force
    }
}

Write-Host "OK. Bundle: $bundleName (targets AutoCAD $AcadVersion)"
Write-Host "Signed: $((Get-ChildItem -LiteralPath $bundleDir -Filter '*.dll').Count) DLL -> $bundleDir"
Write-Host "Tao bo cai: iscc installer\mto.iss"