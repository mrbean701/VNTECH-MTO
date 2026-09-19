param(
    [ValidateSet('Release', 'Debug')]
    [string]$Config = 'Release',
    [string]$Version = '0.1.0'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$srcCsc      = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$appSource   = Join-Path $root 'installer\SetupApp\InstallerApp.cs'
$bundlesDir  = Join-Path $root 'installer\bundles'
$configFile  = Join-Path $root 'config\rules.sample.json'
$outputDir   = Join-Path $root 'output'
$exePath     = Join-Path $outputDir "MTOPlugin.Setup-$Version.exe"

if (-not (Test-Path -LiteralPath $srcCsc)) {
    throw "Thieu C# compiler: $srcCsc"
}
if (-not (Test-Path -LiteralPath $appSource)) {
    throw "Thieu source installer: $appSource"
}
if (-not (Test-Path -LiteralPath $configFile)) {
    throw "Thieu bo quy tac mau: $configFile"
}

# ---- 1. Kiem tra bundle (canh bao neu con trong DLL) ----
$bundleDirs = Get-ChildItem -LiteralPath $bundlesDir -Directory -Filter 'MTOPlugin.*.bundle' | Select-Object -ExpandProperty FullName
if (-not $bundleDirs) {
    throw "Khong tim thay bundle nao trong $bundlesDir"
}
foreach ($b in $bundleDirs) {
    $dll = Join-Path $b 'Contents\Windows\MTOPlugin.dll'
    if (-not (Test-Path -LiteralPath $dll)) {
        Write-Warning "CANH BAO: bundle [$b] chua co MTOPlugin.dll."
        Write-Warning "  Chay truoc: scripts\build.ps1 -AcadVersion X ; scripts\deploy-bundle.ps1 -AcadVersion X"
    }
}

# ---- 2. Dung payload (zip) ----
$temp = Join-Path $env:TEMP 'MTOPlugin.Setup.build'
if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $temp | Out-Null

foreach ($b in $bundleDirs) {
    Copy-Item -LiteralPath $b -Destination $temp -Recurse
}
$cfgDir = Join-Path $temp 'config'
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Copy-Item -LiteralPath $configFile -Destination $cfgDir

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$zipPath = Join-Path $outputDir 'MTOPlugin.Setup.payload.zip'
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)

Write-Host "Payload: $zipPath ($((Get-Item -LiteralPath $zipPath).Length) bytes)"

# ---- 3. Bien dich EXE, ghi payload vào resource ----
$refs = @(
    'System.dll',
    'System.Core.dll',
    'System.Drawing.dll',
    'System.Windows.Forms.dll',
    'System.xml.dll'
) | ForEach-Object { "/reference:$($_)" }

& $srcCsc /nologo /target:winexe /codepage:65001 `
    "/out:$exePath" `
    "/resource:$zipPath,InstallerApp.Payload.zip" `
    $refs `
    $appSource
if ($LASTEXITCODE -ne 0) {
    throw "Bien dich installer that bai (csc exit $LASTEXITCODE). Xem loi o tren."
}

# Giữ payload dạng sidecar cho phát triển (nếu EXE cần sửa chữa)
Write-Host ""
Write-Host "OK. Hoan tat bo cai 1-click:"
Write-Host "  $exePath"
Write-Host "Nguoi dung chi can double-click file EXE. Chua ban vao AutoCAD tu dong."
Write-Host "Kiem tra nhanh:  $exePath --check"