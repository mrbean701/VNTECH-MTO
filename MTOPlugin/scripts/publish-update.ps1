# ============================================================
# publish-update.ps1 -- Dong goi 1 RELEASE hoan chinh cho MTOPro
#
# Bien bo source thanh:
#   release\<version>\package.zip      (payload)
#   release\<version>\manifest.json    (mo ta)
#   release\manifest.json              (ban moi nhat - UpdateSource tro vao)
#
# Cach dung:
#   .\publish-update.ps1
#   .\publish-update.ps1 -Version 1.1.0 -Mandatory -Notes "sua loi bang NATIVE"
#   .\publish-update.ps1 -SkipDll
# ============================================================

param(
    [string]$Version = "",
    [switch]$Mandatory,
    [string]$Notes = "",
    [switch]$SkipDll,
    [int]$MinVersion = 0,
    [string]$MinAutoCad = "24.0"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

# ---------- 1. PHIEN BAN (tu version.json) ----------
$verFile = Join-Path $root "version.json"
$prodName = "MTOPro"
$versionJson = $null
if (Test-Path -LiteralPath $verFile) {
    $versionJson = Get-Content -LiteralPath $verFile -Raw -Encoding UTF8 | ConvertFrom-Json
}
if ($Version -eq "") {
    if ($versionJson -and $versionJson.version) { $Version = $versionJson.version }
    else { throw "Khong doc duoc version tu version.json va khong truyen -Version" }
}
if ($versionJson -and $versionJson.product) { $prodName = $versionJson.product }
if ($versionJson -and $versionJson.minimum_autocad) { $MinAutoCad = $versionJson.minimum_autocad }

# Kiem tra semver
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version phai dang MAJOR.MINOR.PATCH (nhan: $Version)" }

Write-Host "=== PUBLISH RELEASE $prodName v$Version ===" -ForegroundColor Cyan

# minimum_version: mac dinh = chinh version (khong nang cap tuan tu)
$minVer = if ($MinVersion -gt 0) { "$MinVersion.0.0" } else { "1.0.0" }
if ($versionJson -and $versionJson.minimum_version) { $minVer = $versionJson.minimum_version }

# ---------- 2. DUNG PAYLOAD ----------
$temp = Join-Path $env:TEMP ("mtopro-release-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $temp | Out-Null

function Copy-Payload {
    param([string]$Src, [string]$DstName)
    if (-not (Test-Path -LiteralPath $Src)) { return 0 }
    $d = Join-Path $temp $DstName
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    Copy-Item "$Src\*" -Destination $d -Recurse -Force
    return (Get-ChildItem $d -Recurse -File | Measure-Object).Count
}

$nLisp = Copy-Payload (Join-Path $root "lisp") "lisp"
# Loai bo thu muc tests/ va out/ khoi payload phat hanh
$lispDst = Join-Path $temp "lisp"
foreach ($junk in @("tests", "staging")) {
    $j = Join-Path $lispDst $junk
    if (Test-Path -LiteralPath $j) { Remove-Item $j -Recurse -Force }
}
$nLisp = (Get-ChildItem $lispDst -File -Filter "*.lsp" | Measure-Object).Count

$nDocs  = Copy-Payload (Join-Path $root "docs") "docs"
$nTools = Copy-Payload (Join-Path $root "scripts") "tools"
if (-not $SkipDll) {
    $dllSrc = Join-Path $root "src\MTOPlugin\bin\Release\net48"
    if (-not (Test-Path -LiteralPath (Join-Path $dllSrc "MTOPlugin.dll"))) {
        $dllSrc = Join-Path $root "src\MTOPlugin\bin\Debug\net48"
    }
    if (Test-Path -LiteralPath (Join-Path $dllSrc "MTOPlugin.dll")) {
        $dd = Join-Path $temp "dll"
        New-Item -ItemType Directory -Force -Path $dd | Out-Null
        foreach ($n in @("MTOPlugin.dll","MTOPlugin.Core.dll","MTOPlugin.UI.dll","MTOPlugin.Logging.dll")) {
            $p = Join-Path $dllSrc $n
            if (Test-Path -LiteralPath $p) { Copy-Item $p -Destination $dd }
        }
    } else { Write-Warning "Khong thay DLL net48 -> dong goi chi LISP" }
}

# version.json vao payload
# BUG DA GAP: neu -Version khac version.json goc thi payload van mang version CU
# -> UpdaterApp.VerifyPayload se TU CHOI (version.json khong khop manifest).
# => Phai ghi lai version.json TRONG PAYLOAD theo dung version dang phat hanh
#    (khong sua file version.json goc trong repo).
$dstVer = Join-Path $temp "version.json"
if (Test-Path -LiteralPath $verFile) { Copy-Item $verFile -Destination $dstVer -Force }
if ($versionJson) {
    $vc = [ordered]@{}
    $vc["product"]         = $prodName
    $vc["version"]         = $Version
    $vc["release_date"]    = (Get-Date -Format "yyyy-MM-dd")
    $vc["minimum_autocad"] = $MinAutoCad
    if ($versionJson.channel) { $vc["channel"] = $versionJson.channel }
    if ($versionJson.autocad_series) { $vc["autocad_series"] = $versionJson.autocad_series }
    $sbv = New-Object Text.StringBuilder
    [void]$sbv.AppendLine("{")
    $vk = @($vc.Keys)
    for ($i = 0; $i -lt $vk.Count; $i++) {
        $comma = if ($i -lt $vk.Count - 1) { "," } else { "" }
        [void]$sbv.AppendLine(('  "{0}": "{1}"{2}' -f $vk[$i], $vc[$vk[$i]], $comma))
    }
    [void]$sbv.AppendLine("}")
    [IO.File]::WriteAllText($dstVer, $sbv.ToString(), (New-Object Text.UTF8Encoding($false)))
}

Write-Host ("  Payload: {0} lisp | {1} docs | {2} tools" -f $nLisp, $nDocs, $nTools)

# ---------- 3. NEN ----------
$relRoot = Join-Path $root "release"
$relVer  = Join-Path $relRoot $Version
New-Item -ItemType Directory -Force -Path $relVer | Out-Null

$zipPath = Join-Path $relVer "package.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $zipPath,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)

$zipLen = (Get-Item -LiteralPath $zipPath).Length
$sha = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("  package.zip: {0} KB | sha256={1}..." -f [math]::Round($zipLen/1KB,1), $sha.Substring(0,16))

# ---------- 4. MANIFEST ----------
if ($Notes -eq "") { $Notes = "Ban phat hanh $Version" }
# release_notes phai 1 dong (rang buoc parser phang)
$Notes = ($Notes -replace "[\r\n]+", " ").Trim()

$manifest = [ordered]@{
    product         = $prodName
    version         = $Version
    release_date    = (Get-Date -Format "yyyy-MM-dd")
    package         = "package.zip"
    sha256          = $sha
    size_bytes      = $zipLen
    minimum_version = $minVer
    minimum_autocad = $MinAutoCad
    mandatory       = $(if ($Mandatory) { "true" } else { "false" })
    release_notes   = $Notes
}

function Write-Manifest([string]$path) {
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine("{")
    $keys = @($manifest.Keys)
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $k = $keys[$i]
        $v = $manifest[$k]
        $comma = if ($i -lt $keys.Count - 1) { "," } else { "" }
        if ($v -is [int] -or $v -is [long] -or $v -is [double]) {
            [void]$sb.AppendLine(('  "{0}": {1}{2}' -f $k, $v, $comma))
        } else {
            $s = ([string]$v) -replace '\\', '\\' -replace '"', '\"'
            [void]$sb.AppendLine(('  "{0}": "{1}"{2}' -f $k, $s, $comma))
        }
    }
    [void]$sb.AppendLine("}")
    [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
}

$manVer = Join-Path $relVer "manifest.json"
Write-Manifest $manVer
Write-Manifest (Join-Path $relRoot "manifest.json")   # ban moi nhat

# ---------- 5. KIEM TRA (TEST-15) ----------
Write-Host ""
Write-Host "--- KIEM TRA TINH NHAT QUAN (TEST-15) ---"
$chk = Get-Content -LiteralPath (Join-Path $relRoot "manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$shaReal = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$ok1 = ($chk.sha256 -eq $shaReal)
$ok2 = ($chk.version -eq $Version)
$ok3 = ($chk.package -eq "package.zip")
$ok4 = (Test-Path -LiteralPath (Join-Path $relVer "package.zip"))
$ok5 = ((Get-Item -LiteralPath $zipPath).Length -eq $chk.size_bytes)
# version.json TRONG PAYLOAD phai khop manifest version
$tmpChk = Join-Path $env:TEMP ("mtopro-chk-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpChk | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tmpChk)
$payloadVersion = $null
$pvPath = Join-Path $tmpChk "version.json"
if (Test-Path -LiteralPath $pvPath) {
    $pvTxt = Get-Content -LiteralPath $pvPath -Raw -Encoding UTF8
    if ($pvTxt -match '"version"\s*:\s*"([^"]+)"') { $payloadVersion = $Matches[1] }
}
$ok6 = ($payloadVersion -eq $Version)
Remove-Item -LiteralPath $tmpChk -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("  sha256 khop      : {0}" -f $(if ($ok1) { "OK" } else { "*** SAI ***" }))
Write-Host ("  version khop     : {0}" -f $(if ($ok2) { "OK" } else { "*** SAI ***" }))
Write-Host ("  package khop     : {0}" -f $(if ($ok3) { "OK" } else { "*** SAI ***" }))
Write-Host ("  file ton tai     : {0}" -f $(if ($ok4) { "OK" } else { "*** THIEU ***" }))
Write-Host ("  size khop        : {0}" -f $(if ($ok5) { "OK" } else { "*** SAI ***" }))
Write-Host ("  payload version  : {0} (manifest={1})" -f $payloadVersion, $Version)

# Don temp
Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($ok1 -and $ok2 -and $ok3 -and $ok4 -and $ok5 -and $ok6) {
    Write-Host "=== PUBLISH THANH CONG ===" -ForegroundColor Green
    Write-Host ("  release\{0}\package.zip" -f $Version)
    Write-Host ("  release\{0}\manifest.json" -f $Version)
    Write-Host "  release\manifest.json   (ban moi nhat -> tro UpdateSource vao day)"
    exit 0
} else {
    Write-Host "=== PUBLISH LOI: manifest khong nhat quan ===" -ForegroundColor Red
    exit 1
}
