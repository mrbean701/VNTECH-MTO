# =============================================================
# Chay unit test cho MTOPlugin.Core (khong can AutoCAD)
# =============================================================
param(
    [string]$Config = "Debug"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

# Uu tien dung VSTest Console (Visual Studio); fallback sang 'dotnet test'
$vstest = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Recurse `
    -Filter "vstest.console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $vstest) {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        Write-Host "[ERR] Khong tim thay vstest.console.exe cung nhu dotnet test." -ForegroundColor Red
        Write-Host "      Cai .NET SDK hoac Visual Studio Build Tools." -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Dung 'dotnet test'." -ForegroundColor Green
    & dotnet test "$root\tests\MTOPlugin.Tests\MTOPlugin.Tests.csproj" -c $Config --nologo
    exit $LASTEXITCODE
}

$dll = "$root\tests\MTOPlugin.Tests\bin\$Config\net8.0\MTOPlugin.Tests.dll"
if (-not (Test-Path $dll)) {
    Write-Host "[ERR] Chua build tests. Chay: .\scripts\build.ps1 truoc." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] VSTest: $($vstest.FullName)" -ForegroundColor Green
& $vstest.FullName $dll

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERR] Co test that bai." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "[OK] Tat ca test dat." -ForegroundColor Green
exit 0