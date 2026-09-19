# ============================================================
# build-lisp-installer.ps1 -- Dong goi MTOPro thanh 1 file EXE cai dat
#
# Payload gom:
#   lisp/   17 module AutoLISP
#   config/ bo quy tac mau (rules.sample.json)
#   docs/   tai lieu huong dan + gioi thieu
#   dll/    (tuy chon) MTOPlugin.dll net48 + Core/UI/Logging
#
# Cach dung:
#   .\build-lisp-installer.ps1                 # dong goi (co DLL neu da build)
#   .\build-lisp-installer.ps1 -SkipDll        # chi LISP
#   .\build-lisp-installer.ps1 -Version 1.0.0
# ============================================================

param(
    [string]$Version = "",
    [switch]$SkipDll
)

$ErrorActionPreference = "Stop"

# ============================================================
# PHIEN BAN -- doc tu NGUON SU THAT DUY NHAT: version.json
# (neu -Version duoc truyen thi uu tien tham so dong lenh)
# ============================================================
$versionFile = Join-Path (Split-Path -Parent $PSScriptRoot) "version.json"
if ($Version -eq "") {
    if (Test-Path -LiteralPath $versionFile) {
        try {
            $vj = Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $Version = $vj.version
            Write-Host ("Phien ban (tu version.json): {0}" -f $Version) -ForegroundColor Cyan
        } catch {
            Write-Warning ("Khong doc duoc version.json: {0}" -f $_.Exception.Message)
        }
    }
    if (-not $Version) { $Version = "1.0.0"; Write-Warning "Dung fallback 1.0.0" }
}

$root        = Split-Path -Parent $PSScriptRoot
$csc         = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$appSource   = Join-Path $root "installer\SetupApp\InstallerLisp.cs"
$outputDir   = Join-Path $root "output"
$exePath     = Join-Path $outputDir "MTOPro.Setup-$Version.exe"
$zipPath     = Join-Path $outputDir "MTOPro.Setup.payload.zip"

if (-not (Test-Path -LiteralPath $csc)) { throw "Thieu C# compiler: $csc" }
if (-not (Test-Path -LiteralPath $appSource)) { throw "Thieu source installer: $appSource" }
if (-not (Test-Path -LiteralPath (Join-Path $root "lisp\mto-loader.lsp"))) { throw "Thieu lisp\mto-loader.lsp" }

Write-Host "=== DONG GOI MTOPro v$Version ===" -ForegroundColor Cyan

# ---- 1. Dung payload ----
$temp = Join-Path $env:TEMP "MTOPro.Setup.build"
if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $temp | Out-Null

# 1a. LISP (khong lay thu muc tests/)
$dstLisp = Join-Path $temp "lisp"
New-Item -ItemType Directory -Force -Path $dstLisp | Out-Null
$lsp = Get-ChildItem -Path (Join-Path $root "lisp") -Filter "*.lsp" -File
foreach ($f in $lsp) { Copy-Item $f.FullName -Destination $dstLisp }
Write-Host ("  LISP      : {0} file" -f $lsp.Count)

# 1b. config
$dstCfg = Join-Path $temp "config"
New-Item -ItemType Directory -Force -Path $dstCfg | Out-Null
$rules = Join-Path $root "config\rules.sample.json"
if (Test-Path -LiteralPath $rules) { Copy-Item $rules -Destination $dstCfg }
# Template danh muc vat tu (de nguoi dung dien)
$tmpl = Join-Path $root "config\DANH_MUC_VAT_TU.xlsx"
if (Test-Path -LiteralPath $tmpl) { Copy-Item $tmpl -Destination $dstCfg }
# Cong cu import
$dstTools = Join-Path $temp "tools"
New-Item -ItemType Directory -Force -Path $dstTools | Out-Null
foreach ($tn in @("import-materials.ps1","create-material-template.ps1")) {
    $tp = Join-Path $root "scripts\$tn"
    if (Test-Path -LiteralPath $tp) { Copy-Item $tp -Destination $dstTools }
}
Write-Host "  config    : rules.sample.json"

# 1c. docs (chi tai lieu nguoi dung)
# 1d. version.json (nguon phien ban cho ban cai)
if (Test-Path -LiteralPath $versionFile) { Copy-Item $versionFile -Destination $temp }
Write-Host "  version   : version.json"

$dstDocs = Join-Path $temp "docs"
New-Item -ItemType Directory -Force -Path $dstDocs | Out-Null
# Uu tien ban Word (.docx) cho nguoi dung cuoi; giu them .md cho ky thuat
$docFiles = @(
    "HUONG_DAN_SU_DUNG.docx",
    "HUONG_DAN_DO_CAP_VA_IN_BANG.docx",
    "GIAI_THICH_RULE_EDITOR.docx",
    "GIOI_THIEU_DU_AN.docx",
    "HUONG_DAN_SU_DUNG.md",
    "HUONG_DAN_DO_CAP_VA_IN_BANG.md",
    "GIAI_THICH_RULE_EDITOR.md",
    "GIOI_THIEU_DU_AN.md",
    "HUONG_DAN_NHAP_DANH_MUC_VAT_TU.docx",
    "HUONG_DAN_NHAP_DANH_MUC_VAT_TU.md"
)
foreach ($d in $docFiles) {
    $p = Join-Path $root "docs\$d"
    if (Test-Path -LiteralPath $p) { Copy-Item $p -Destination $dstDocs }
    else { Write-Warning "Thieu tai lieu: $d" }
}
Write-Host ("  docs      : {0} file" -f (Get-ChildItem $dstDocs).Count)

# 1d. DLL net48 (tuy chon)
$dllOk = $false
if (-not $SkipDll) {
    $binNet48 = Join-Path $root "src\MTOPlugin\bin\Release\net48"
    if (-not (Test-Path -LiteralPath (Join-Path $binNet48 "MTOPlugin.dll"))) {
        $binNet48 = Join-Path $root "src\MTOPlugin\bin\Debug\net48"
    }
    if (Test-Path -LiteralPath (Join-Path $binNet48 "MTOPlugin.dll")) {
        $dstDll = Join-Path $temp "dll"
        New-Item -ItemType Directory -Force -Path $dstDll | Out-Null
        foreach ($n in @("MTOPlugin.dll","MTOPlugin.Core.dll","MTOPlugin.UI.dll","MTOPlugin.Logging.dll","Newtonsoft.Json.dll","EPPlus.dll")) {
            $p = Join-Path $binNet48 $n
            if (Test-Path -LiteralPath $p) { Copy-Item $p -Destination $dstDll }
        }
        $dllOk = $true
        Write-Host ("  dll       : {0} file (net48)" -f (Get-ChildItem $dstDll).Count)
    } else {
        Write-Warning "Khong thay MTOPlugin.dll net48 -> bo qua phan .NET (chi cai LISP)."
        Write-Warning "  Build truoc: dotnet build src\MTOPlugin\MTOPlugin.csproj -f net48 /p:AcadDirectory=`"...`" /p:MtoNet8=false"
    }
}

# ---- 2. Nen payload ----
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)
$zipKb = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1KB, 1)
Write-Host ("  payload   : {0} KB" -f $zipKb)

# ---- 3. Bien dich EXE, nhung payload ----
$refs = @("System.dll","System.Core.dll","System.Drawing.dll","System.Windows.Forms.dll","System.xml.dll") |
        ForEach-Object { "/reference:$($_)" }

& $csc /nologo /target:winexe /codepage:65001 /optimize+ `
    "/out:$exePath" `
    "/resource:$zipPath,InstallerLisp.Payload.zip" `
    $refs `
    $appSource
if ($LASTEXITCODE -ne 0) { throw "Bien dich installer that bai (csc exit $LASTEXITCODE)." }

$exeKb = [math]::Round((Get-Item -LiteralPath $exePath).Length / 1KB, 1)

Write-Host ""
Write-Host "=== HOAN TAT ===" -ForegroundColor Green
Write-Host ("  File phat hanh : {0}" -f $exePath)
Write-Host ("  Dung luong     : {0} KB" -f $exeKb)
Write-Host ("  LISP           : {0} module" -f $lsp.Count)
Write-Host ("  .NET bundle    : {0}" -f ($(if ($dllOk) { "co" } else { "khong" })))
Write-Host ""
Write-Host "Kiem tra nhanh : & '$exePath' --check"
Write-Host "Gui bo phan test: chi can file EXE nay."
