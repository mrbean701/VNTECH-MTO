# ============================================================
# create-word-guide.ps1 -- Chuyen tai lieu Markdown -> Word (.docx) chuan form
#
# Dung Microsoft Word COM (Word phai duoc cai). Tao ra file .docx THAT voi:
#   - Kho A4, le chuan, font Times New Roman 13
#   - Trang bia
#   - Muc luc tu dong (Table of Contents)
#   - Heading 1/2/3 theo style chuan cua Word
#   - Bang Word that (co header row)
#   - Code block: font Consolas + nen xam
#   - Header/Footer co so trang
#
# Cach dung:
#   .\create-word-guide.ps1
#   .\create-word-guide.ps1 -Md "docs\HUONG_DAN_SU_DUNG.md" -Out "docs\HUONG_DAN_SU_DUNG.docx"
# ============================================================

param(
    [string]$Md  = "",
    [string]$Out = "",
    [string]$Title = "HƯỚNG DẪN SỬ DỤNG",
    [string]$Subtitle = "MTOPro — Bóc tách khối lượng M&E trên AutoCAD",
    [string]$Project = "Đề tài: R&D-CAD-QTO-01 · Phòng Dự án",
    [string]$Version = "Phiên bản 1.0 — 18/09/2026"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if ($Md  -eq "") { $Md  = Join-Path $root "docs\HUONG_DAN_SU_DUNG.md" }
if ($Out -eq "") { $Out = [IO.Path]::ChangeExtension($Md, ".docx") }

# Word COM yeu cau DUONG DAN TUYET DOI khi SaveAs2
$Md  = [IO.Path]::GetFullPath($Md)
$Out = [IO.Path]::GetFullPath($Out)

if (-not (Test-Path -LiteralPath $Md)) { throw "Khong tim thay file Markdown: $Md" }

$baseFont = "Times New Roman"
$baseSize = 13
$codeFont = "Consolas"
$codeSize = 10

function New-WordApp {
    $w = New-Object -ComObject Word.Application
    $w.Visible = $false
    $w.DisplayAlerts = 0
    return $w
}

# ---- Ghi text co xu ly **bold** va `code` inline ----
function Write-Inline {
    param($Sel, [string]$Text)
    $sel = $Sel
    $pattern = '(\*\*[^*]+\*\*|`[^`]+`)'
    $parts = [regex]::Split($Text, $pattern)
    foreach ($p in $parts) {
        if ($p -eq "") { continue }
        if ($p -match '^\*\*(.+)\*\*$') {
            $sel.Font.Name = $baseFont; $sel.Font.Size = $baseSize; $sel.Font.Bold = 1
            $sel.TypeText($Matches[1])
            $sel.Font.Bold = 0
        }
        elseif ($p -match '^`(.+)`$') {
            $sel.Font.Name = $codeFont; $sel.Font.Size = $codeSize; $sel.Font.Bold = 0
            $sel.TypeText($Matches[1])
            $sel.Font.Name = $baseFont; $sel.Font.Size = $baseSize
        }
        else {
            $sel.Font.Name = $baseFont; $sel.Font.Size = $baseSize; $sel.Font.Bold = 0
            $sel.TypeText($p)
        }
    }
}

function Set-Para {
    param($Sel, [string]$Style = "", [double]$SpaceAfter = 6, [double]$LineSpacing = 1.35, [int]$Align = 0)
    if ($Style -ne "") { $Sel.Style = $Style }
    $Sel.ParagraphFormat.SpaceAfter = $SpaceAfter
    $Sel.ParagraphFormat.LineSpacingRule = 5      # wdLineSpaceMultiple
    $Sel.ParagraphFormat.LineSpacing = $LineSpacing * 12
    if ($Align -ne 0) { $Sel.ParagraphFormat.Alignment = $Align }
}

# ============================================================
$word = New-WordApp
try {
    $doc = $word.Documents.Add()

    # ---- Kho giay A4 + le ----
    $doc.PageSetup.PageWidth  = 595.3
    $doc.PageSetup.PageHeight = 841.9
    $doc.PageSetup.TopMargin    = 56.7
    $doc.PageSetup.BottomMargin = 56.7
    $doc.PageSetup.LeftMargin   = 85.0
    $doc.PageSetup.RightMargin  = 56.7

    # ---- Font mac dinh ----
    $doc.Styles.Item("Normal").Font.Name = $baseFont
    $doc.Styles.Item("Normal").Font.Size = $baseSize

    $sel = $word.Selection

    # ================= TRANG BIA =================
    $sel.ParagraphFormat.Alignment = 1     # center
    $sel.Font.Name = $baseFont
    $sel.Font.Size = 16; $sel.Font.Bold = 1
    $sel.TypeText("CÔNG TY XÂY LẮP")
    $sel.TypeParagraph()
    $sel.Font.Size = 14
    $sel.TypeText("PHÒNG DỰ ÁN")
    $sel.TypeParagraph()
    $sel.TypeParagraph()

    $sel.Font.Size = 13; $sel.Font.Bold = 0
    $sel.TypeText($Project)
    $sel.TypeParagraph()
    $sel.TypeParagraph()
    $sel.TypeParagraph()

    $sel.Font.Size = 26; $sel.Font.Bold = 1; $sel.Font.Color = 6299648   # xanh dam
    $sel.TypeText($Title)
    $sel.TypeParagraph()

    $sel.Font.Size = 15; $sel.Font.Bold = 0; $sel.Font.Color = 0
    $sel.TypeText($Subtitle)
    $sel.TypeParagraph()
    $sel.TypeParagraph()
    $sel.Font.Size = 12
    $sel.TypeText($Version)
    $sel.TypeParagraph()

    # ngat trang
    $sel.InsertBreak(7)   # wdPageBreak

    # ================= MUC LUC =================
    $sel.ParagraphFormat.Alignment = 0
    $sel.Font.Size = 18; $sel.Font.Bold = 1; $sel.Font.Color = 6299648
    $sel.TypeText("MỤC LỤC")
    $sel.TypeParagraph()
    $sel.Font.Color = 0

    # TOC tu dong (Heading 1..3)
    $toc = $doc.TablesOfContents.Add($sel.Range, $true, 1, 3)
    $sel.EndKey(6) | Out-Null      # wdStory
    $sel.InsertBreak(7)

    # ================= NOI DUNG =================
    $lines = Get-Content -LiteralPath $Md -Encoding UTF8
    $i = 0
    $total = $lines.Count

    while ($i -lt $total) {
        $line = $lines[$i]

        # ---- Code block ``` ----
        if ($line -match '^\s*```') {
            $i++
            $codeLines = @()
            while ($i -lt $total -and $lines[$i] -notmatch '^\s*```') {
                $codeLines += $lines[$i]; $i++
            }
            $i++   # bo dong ``` ket thuc
            if ($codeLines.Count -gt 0) {
                $sel.Style = $doc.Styles.Item("Normal")
                $sel.ParagraphFormat.Alignment = 0
                $sel.ParagraphFormat.LeftIndent = 18
                $sel.ParagraphFormat.SpaceAfter = 4
                $sel.Font.Name = $codeFont; $sel.Font.Size = $codeSize; $sel.Font.Bold = 0
                foreach ($cl in $codeLines) {
                    $sel.TypeText($cl)
                    if ($cl -ne $codeLines[-1]) { $sel.TypeParagraph() }
                }
                $sel.TypeParagraph()
                $sel.Font.Name = $baseFont; $sel.Font.Size = $baseSize
                $sel.ParagraphFormat.LeftIndent = 0
            }
            continue
        }

        # ---- Bang markdown ----
        if ($line -match '^\s*\|') {
            $tableLines = @()
            while ($i -lt $total -and $lines[$i] -match '^\s*\|') {
                $tableLines += $lines[$i]; $i++
            }
            # bo dong phan cach |---|---|
            $rows = @()
            foreach ($tl in $tableLines) {
                if ($tl -match '^\s*\|[\s:\-\|]+\|\s*$') { continue }
                $cells = $tl.Trim().Trim('|') -split '\|'
                $rows += ,($cells | ForEach-Object { $_.Trim() })
            }
            if ($rows.Count -gt 0) {
                $nRows = $rows.Count
                $nCols = $rows[0].Count
                $tbl = $doc.Tables.Add($sel.Range, $nRows, $nCols)
                $tbl.Borders.Enable = 1
                for ($r = 0; $r -lt $nRows; $r++) {
                    for ($c = 0; $c -lt $nCols; $c++) {
                        $txt = ""
                        if ($c -lt $rows[$r].Count) { $txt = $rows[$r][$c] }
                        $txt = $txt -replace '\*\*','' -replace '`',''
                        $cell = $tbl.Cell($r + 1, $c + 1)
                        $cell.Range.Text = $txt
                        $cell.Range.Font.Name = $baseFont
                        $cell.Range.Font.Size = 11
                        $cell.Range.Font.Bold = 0
                        if ($r -eq 0) { $cell.Range.Font.Bold = 1 }
                    }
                }
                $tbl.Rows.Item(1).HeadingFormat = $true
                $sel.EndKey(6) | Out-Null
                $sel.TypeParagraph()
            }
            continue
        }

        # ---- Heading ----
        if ($line -match '^####\s+(.*)$') {
            $sel.Style = $doc.Styles.Item("Heading 4"); $sel.Font.Color = 0
            Write-Inline $sel $Matches[1]; $sel.TypeParagraph()
            $sel.Style = $doc.Styles.Item("Normal")
            $i++; continue
        }
        if ($line -match '^###\s+(.*)$') {
            $sel.Style = $doc.Styles.Item("Heading 3"); $sel.Font.Color = 0
            Write-Inline $sel $Matches[1]; $sel.TypeParagraph()
            $sel.Style = $doc.Styles.Item("Normal")
            $i++; continue
        }
        if ($line -match '^##\s+(.*)$') {
            $sel.Style = $doc.Styles.Item("Heading 2"); $sel.Font.Color = 0
            Write-Inline $sel $Matches[1]; $sel.TypeParagraph()
            $sel.Style = $doc.Styles.Item("Normal")
            $i++; continue
        }
        if ($line -match '^#\s+(.*)$') {
            $sel.Style = $doc.Styles.Item("Heading 1"); $sel.Font.Color = 0
            Write-Inline $sel $Matches[1]; $sel.TypeParagraph()
            $sel.Style = $doc.Styles.Item("Normal")
            $i++; continue
        }

        # ---- Duong ke ngang ----
        if ($line -match '^---+\s*$') {
            $sel.Style = $doc.Styles.Item("Normal")
            $sel.ParagraphFormat.Alignment = 1
            $sel.Font.Size = 11; $sel.Font.Bold = 0
            $sel.TypeText("* * *")
            $sel.TypeParagraph()
            $sel.ParagraphFormat.Alignment = 0
            $i++; continue
        }

        # ---- Danh sach ----
        if ($line -match '^\s*[-*]\s+(.*)$') {
            $sel.Style = $doc.Styles.Item("List Bullet")
            $sel.ParagraphFormat.SpaceAfter = 4
            $sel.ParagraphFormat.LineSpacingRule = 5
            $sel.ParagraphFormat.LineSpacing = 15
            $sel.Font.Size = $baseSize
            Write-Inline $sel $Matches[1]
            $sel.TypeParagraph()
            $sel.Style = $doc.Styles.Item("Normal")
            $i++; continue
        }
        if ($line -match '^\s*\d+\.\s+(.*)$') {
            $sel.Style = $doc.Styles.Item("List Number")
            $sel.ParagraphFormat.SpaceAfter = 4
            $sel.Font.Size = $baseSize
            Write-Inline $sel $Matches[1]
            $sel.TypeParagraph()
            $sel.Style = $doc.Styles.Item("Normal")
            $i++; continue
        }

        # ---- Trich dan ----
        if ($line -match '^>\s*(.*)$') {
            $sel.Style = $doc.Styles.Item("Quote")
            $sel.Font.Size = 12
            Write-Inline $sel $Matches[1]
            $sel.TypeParagraph()
            $sel.Style = $doc.Styles.Item("Normal")
            $sel.Font.Size = $baseSize
            $i++; continue
        }

        # ---- Dong trong ----
        if ($line -match '^\s*$') {
            $i++; continue
        }

        # ---- Doan van thuong ----
        $sel.Style = $doc.Styles.Item("Normal")
        Set-Para $sel "" 6 1.35 3    # canh deu 2 ben
        Write-Inline $sel $line
        $sel.TypeParagraph()
        $i++
    }

    # ================= HEADER / FOOTER =================
    $doc.Sections.Item(1).Headers.Item(1).Range.Text = "MTOPro — " + $Title
    $doc.Sections.Item(1).Headers.Item(1).Range.Font.Size = 9
    $doc.Sections.Item(1).Headers.Item(1).Range.Font.Name = $baseFont

    $ftr = $doc.Sections.Item(1).Footers.Item(1)
    $ftr.Range.Text = ""
    $ftr.Range.Font.Size = 9
    $ftr.Range.Font.Name = $baseFont
    $ftr.Range.ParagraphFormat.Alignment = 1     # center
    $ftr.Range.InsertAfter("Trang ")
    $ftr.Range.Collapse(0) | Out-Null
    $ftr.Range.Fields.Add($ftr.Range, -1, "PAGE") | Out-Null
    $ftr.Range.InsertAfter(" / ")
    $ftr.Range.Collapse(0) | Out-Null
    $ftr.Range.Fields.Add($ftr.Range, -1, "NUMPAGES") | Out-Null

    # ---- Cap nhat muc luc + field (Fields.Update() toan cuc KHONG phu header/footer) ----
    if ($doc.TablesOfContents.Count -gt 0) { $doc.TablesOfContents.Item(1).Update() }
    $doc.Fields.Update() | Out-Null
    foreach ($sec in $doc.Sections) {
        foreach ($h in $sec.Headers) { $h.Range.Fields.Update() | Out-Null }
        foreach ($f in $sec.Footers) { $f.Range.Fields.Update() | Out-Null }
    }

    # Ghi file: neu file dang bi Word khac giu (lock), bao ro thay vi crash kho hieu
    if (Test-Path -LiteralPath $Out) {
        try { Remove-Item -LiteralPath $Out -Force -ErrorAction Stop }
        catch {
            $msg = "[LOI] Khong ghi duoc file (dang bi chuong trinh khac giu): $Out"
            $msg += " -- Hay dong Word dang mo file nay roi chay lai."
            throw $msg
        }
    }
    $doc.SaveAs2($Out, 16)
    $doc.Close(0)

    $kb = [math]::Round((Get-Item -LiteralPath $Out).Length / 1KB, 1)
    Write-Host ""
    Write-Host "=== TAO WORD XONG ===" -ForegroundColor Green
    Write-Host ("  File    : {0}" -f $Out)
    Write-Host ("  Dung luong: {0} KB" -f $kb)
    Write-Host ("  Nguon   : {0}" -f $Md)
}
finally {
    # Don sach COM: tranh de lai tien trinh WINWORD giu file (da tung gay loi lock)
    try { $word.Quit() } catch { }
    try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word) } catch { }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 400
}
