$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $root "src\MTOPlugin.UI\bin\Debug\net48"
$core = Join-Path $root "src\MTOPlugin.Core\bin\Debug\netstandard2.0\MTOPlugin.Core.dll"
if (-not (Test-Path $core)) { $core = Join-Path $root "src\MTOPlugin.Core\bin\Debug\net48\MTOPlugin.Core.dll" }

[Reflection.Assembly]::LoadFrom($core) | Out-Null
[Reflection.Assembly]::LoadFrom((Join-Path $bin "MTOPlugin.Logging.dll")) | Out-Null
[Reflection.Assembly]::LoadFrom((Join-Path $bin "MTOPlugin.UI.dll")) | Out-Null

Write-Host "=== TAO RuleEditorWindow ==="
try {
  $w = New-Object MTOPlugin.UI.RuleEditorWindow
  Write-Host "  Tao thanh cong."
} catch {
  Write-Host ("  LOI khi tao: {0}" -f $_.Exception.Message) -ForegroundColor Red
  Write-Host ("  Inner: {0}" -f $_.Exception.InnerException.Message)
  exit 1
}

# Test 2: tao voi RuleSet rong
try {
  $rs = New-Object MTOPlugin.Core.Rules.RuleSet
  $w2 = New-Object MTOPlugin.UI.RuleEditorWindow -ArgumentList $rs, "C:\test\rules.json"
  Write-Host "  Tao voi RuleSet: thanh cong."
} catch {
  Write-Host ("  LOI khi tao voi RuleSet: {0}" -f $_.Exception.Message) -ForegroundColor Red
}

# Render cua so nay (khong ShowDialog, chi Measure/Arrange)
$ww = 900; $hh = 680
$w.Width = $ww; $w.Height = $hh
try {
  $w.Measure((New-Object System.Windows.Size($ww, $hh)))
  $w.Arrange((New-Object System.Windows.Rect(0,0,$ww,$hh)))
  $w.UpdateLayout()
  $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($ww, $hh, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
  $rtb.Render($w)
  $outDir = Join-Path $root "output"
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  $png = Join-Path $outDir "ruleeditor-render.png"
  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
  $fs = [IO.File]::Create($png); $enc.Save($fs); $fs.Close()
  Write-Host ("  Render OK -> {0} ({1} KB)" -f $png, [math]::Round((Get-Item $png).Length/1KB,1))

  # Doc pixel nen
  $stride = $ww * 4
  $buf = New-Object byte[] ($stride * $hh)
  $rtb.CopyPixels($buf, $stride, 0)
  $i = (5 * $stride) + (5 * 4)
  Write-Host ("  Nen (5,5) = RGB({0},{1},{2})" -f $buf[$i+2], $buf[$i+1], $buf[$i])
} catch {
  Write-Host ("  LOI khi render: {0}" -f $_.Exception.Message) -ForegroundColor Red
}

# Kiem tra Owner logic
Write-Host ""
Write-Host "=== KIEM TRA Window.GetWindow tren control khong co parent ==="
$panel = New-Object MTOPlugin.UI.MainPanel
$ow = [System.Windows.Window]::GetWindow($panel)
Write-Host ("  Window.GetWindow(panel) = {0}" -f $(if ($ow) { "CO gia tri: " + $ow.GetType().Name } else { "NULL" }))