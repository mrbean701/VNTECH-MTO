param([string]$Path = "")
$ErrorActionPreference = "Continue"
if (-not $Path -or $Path -eq "") { $Path = Join-Path (Split-Path -Parent $PSScriptRoot) "docs\HUONG_DAN_SU_DUNG.docx" }
$path = [IO.Path]::GetFullPath($Path)

if (-not (Test-Path -LiteralPath $path)) { Write-Host "KHONG TIM THAY: $path"; exit 1 }

$w = New-Object -ComObject Word.Application
$w.Visible = $false
$w.DisplayAlerts = 0
try {
    $d = $w.Documents.Open($path, $false, $true)   # readonly

    Write-Host "=== KIEM TRA FILE WORD ==="
    Write-Host ("Paragraphs        : {0}" -f $d.Paragraphs.Count)
    Write-Host ("Tables            : {0}" -f $d.Tables.Count)
    Write-Host ("TablesOfContents  : {0}" -f $d.TablesOfContents.Count)
    Write-Host ("Sections          : {0}" -f $d.Sections.Count)
    Write-Host ("Pages (uoc tinh)  : {0}" -f $d.ComputeStatistics(2))   # wdStatisticPages
    Write-Host ("Words             : {0}" -f $d.ComputeStatistics(0))

    # dem heading theo style
    $h1 = 0; $h2 = 0; $h3 = 0
    foreach ($p in $d.Paragraphs) {
        $s = ""
        try { $s = $p.Style.NameLocal } catch { }
        if ($s -like "Heading 1*" -or $s -like "Tiêu đề 1*") { $h1++ }
        elseif ($s -like "Heading 2*" -or $s -like "Tiêu đề 2*") { $h2++ }
        elseif ($s -like "Heading 3*" -or $s -like "Tiêu đề 3*") { $h3++ }
    }
    Write-Host ("Heading 1 / 2 / 3 : {0} / {1} / {2}" -f $h1, $h2, $h3)

    Write-Host ("Page width (pt)   : {0}" -f [math]::Round($d.PageSetup.PageWidth,1))
    Write-Host ("Normal font       : {0} {1}pt" -f $d.Styles.Item("Normal").Font.Name, $d.Styles.Item("Normal").Font.Size)

    # kiem tieng Viet: tim mot so tu khoa
    $txt = $d.Content.Text
    foreach ($kw in @("HƯỚNG DẪN", "MỤC LỤC", "MTOCSV", "MTOTABLE", "Xử lý sự cố")) {
        $found = $txt.Contains($kw)
        Write-Host ("  keyword [{0}] : {1}" -f $kw, $(if ($found) { "OK" } else { "THIEU" }))
    }

    # header / footer
    Write-Host ("Header            : {0}" -f $d.Sections.Item(1).Headers.Item(1).Range.Text.Trim())
    Write-Host ("Footer            : {0}" -f $d.Sections.Item(1).Footers.Item(1).Range.Text.Trim())

    $d.Close(0)
}
finally {
    $w.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($w)
}
