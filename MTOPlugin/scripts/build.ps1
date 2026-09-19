# =============================================================
# Build MTOPlugin cho mot autocad version
#
# Cach dung:
#   .\scripts\build.ps1 -AcadVersion 2025
#   .\scripts\build.ps1 -AcadVersion 2020 -Config Release
#   .\scripts\build.ps1 -AcadDirectory "C:\Program Files\Autodesk\AutoCAD 2020"
#
# Yeu cau: .NET SDK (dotnet) hoac Visual Studio / Build Tools (MSBuild).
# Neu khong co MSBuild cua VS, script tu dong dung 'dotnet build'.
# =============================================================
param(
    [string]$AcadVersion = "",
    [string]$AcadDirectory = "",
    [string]$Config = "Debug"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not $AcadDirectory) {
    if ($AcadVersion) {
        $candidate = "C:\Program Files\Autodesk\AutoCAD $AcadVersion"
        if (Test-Path "$candidate\acad.exe") {
            $AcadDirectory = $candidate
        }
    } else {
        # Tu dong tim phien ban AutoCAD cao nhat da cai (2018->2026)
        for ($v = 2026; $v -ge 2018; $v--) {
            $candidate = "C:\Program Files\Autodesk\AutoCAD $v"
            if (Test-Path "$candidate\acad.exe") {
                $AcadDirectory = $candidate
                $AcadVersion = "$v"
                break
            }
        }
    }
}

if (-not $AcadDirectory -or -not (Test-Path "$AcadDirectory\AcMgd.dll")) {
    Write-Host "[ERR] Khong tim thay AutoCAD (AcMgd.dll)." -ForegroundColor Red
    Write-Host "       Truyen: -AcadVersion 2025 hoac -AcadDirectory 'C:\Program Files\Autodesk\AutoCAD 2025'"
    exit 1
}

# AutoCAD 2025+ chay .NET 8 -> build net8.0-windows (MtoNet8=true)
$isNet8 = ($AcadDirectory -match 'AutoCAD 202[56]')
if ($isNet8) {
    Write-Host "[OK] AutoCAD 2025+ phat hien -> build net8.0-windows." -ForegroundColor Green
}
Write-Host "[OK] AcadDirectory: $AcadDirectory" -ForegroundColor Green

# Tim MSBuild cua Visual Studio / Build Tools
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msbuild = $null
if (Test-Path $vswhere) {
    $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" | Select-Object -First 1
}
if (-not $msbuild) {
    $legacy = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    if (Test-Path $legacy) { $msbuild = $legacy }
}

if (-not $msbuild) {
    # Fallback: .NET SDK (dotnet build) — MSBuild di kem SDK
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnet) {
        Write-Host "[OK] Khong co MSBuild cua VS -> dung 'dotnet build'." -ForegroundColor Green
        $dotnetArgs = @("build", "$root\MTOPlugin.sln", "--nologo",
            "-p:AcadDirectory=$AcadDirectory",
            "-p:Configuration=$Config",
            "-m")
        if ($isNet8) { $dotnetArgs += "-p:MtoNet8=true" } else { $dotnetArgs += "-p:MtoNet8=false" }
        & dotnet @dotnetArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERR] Build that bai (exit code $LASTEXITCODE)." -ForegroundColor Red
            exit $LASTEXITCODE
        }
        $tfm = if ($isNet8) { "net8.0-windows" } else { "net48" }
        Write-Host "[OK] Build hoan tat." -ForegroundColor Green
        Write-Host "     Plugin DLL: $root\src\MTOPlugin\bin\$Config\$tfm\MTOPlugin.dll"
        exit 0
    }
    Write-Host "[ERR] Khong tim thay MSBuild cung nhu dotnet. Cai .NET SDK hoac Visual Studio Build Tools." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] MSBuild: $msbuild" -ForegroundColor Green

$msbuildArgs = @(
    "$root\MTOPlugin.sln",
    "/p:AcadDirectory=$AcadDirectory",
    "/p:Configuration=$Config",
    "/t:Build",
    "/restore",
    "/m"
)
if ($isNet8) { $msbuildArgs += "/p:MtoNet8=true" } else { $msbuildArgs += "/p:MtoNet8=false" }

& $msbuild $msbuildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERR] Build that bai (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

$tfmOut = if ($isNet8) { "net8.0-windows" } else { "net48" }
Write-Host "[OK] Build hoan tat." -ForegroundColor Green
Write-Host "     Plugin DLL: $root\src\MTOPlugin\bin\$Config\$tfmOut\MTOPlugin.dll"
exit 0