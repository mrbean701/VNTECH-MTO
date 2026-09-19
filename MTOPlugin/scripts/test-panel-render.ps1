$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $root "src\MTOPlugin.UI\bin\Debug\net48"
$core = Join-Path $root "src\MTOPlugin.Core\bin\Debug\netstandard2.0\MTOPlugin.Core.dll"
if (-not (Test-Path $core)) { $core = Join-Path $root "src\MTOPlugin.Core\bin\Debug\net48\MTOPlugin.Core.dll" }

[Reflection.Assembly]::LoadFrom($core) | Out-Null
[Reflection.Assembly]::LoadFrom((Join-Path $bin "MTOPlugin.Logging.dll")) | Out-Null
[Reflection.Assembly]::LoadFrom((Join-Path $bin "MTOPlugin.UI.dll")) | Out-Null

$w = 1000; $h = 900
$panel = New-Object MTOPlugin.UI.MainPanel
$panel.Width = $w
$panel.Height = $h

# Bat buoc phai Measure/Arrange truoc khi render
$size = New-Object System.Windows.Size($w, $h)
$panel.Measure($size)
$rect = New-Object System.Windows.Rect(0, 0, $w, $h)
$panel.Arrange($rect)
$panel.UpdateLayout()

$rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
$rtb.Render($panel)

$outDir = Join-Path $root "output"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$png = Join-Path $outDir "panel-render.png"
$enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
$fs = [IO.File]::Create($png)
$enc.Save($fs); $fs.Close()

# ---- Doc pixel de KIEM CHUNG MAU ----
$stride = $w * 4
$buf = New-Object byte[] ($stride * $h)
$rtb.CopyPixels($buf, $stride, 0)

function Get-Px($x, $y) {
  $i = $y * $stride + $x * 4
  return @{ B = $buf[$i]; G = $buf[$i+1]; R = $buf[$i+2]; A = $buf[$i+3] }
}

Write-Host "=== KIEM CHUNG MAU PANEL ==="
Write-Host ("PNG: {0} ({1} KB)" -f $png, [math]::Round((Get-Item $png).Length/1KB,1))
Write-Host ""

# Mau nen tai nhieu diem (tranh vung co control)
$pts = @( @(5,5), @(990,5), @(5,890), @(990,890), @(500,20) )
$bright = 0
foreach ($p in $pts) {
  $c = Get-Px $p[0] $p[1]
  $lum = [math]::Round(0.299*$c.R + 0.587*$c.G + 0.114*$c.B, 0)
  Write-Host ("  Nen ({0},{1}) = RGB({2},{3},{4})  do sang={5}" -f $p[0], $p[1], $c.R, $c.G, $c.B, $lum)
  if ($lum -gt 200) { $bright++ }
}

Write-Host ""
Write-Host ("So diem nen SANG (>200): {0}/{1}" -f $bright, $pts.Count)
if ($bright -eq $pts.Count) {
  Write-Host "KET QUA: NEN SANG - CHU DEN DOC DUOC" -ForegroundColor Green
} else {
  Write-Host "KET QUA: CON DIEM TOI - CAN KIEM TRA" -ForegroundColor Red
}

# Thong ke do sang toan anh
$dark = 0; $light = 0
for ($y = 0; $y -lt $h; $y += 7) {
  for ($x = 0; $x -lt $w; $x += 7) {
    $i = $y * $stride + $x * 4
    $lum = 0.299*$buf[$i+2] + 0.587*$buf[$i+1] + 0.114*$buf[$i]
    if ($lum -lt 100) { $dark++ } else { $light++ }
  }
}
$tot = $dark + $light
Write-Host ""
Write-Host ("Ty le pixel SANG: {0}%  |  TOI: {1}%" -f [math]::Round(100*$light/$tot,1), [math]::Round(100*$dark/$tot,1))