# ============================================================
# create-material-template.ps1 -- Tao TEMPLATE Excel danh muc vat tu
# Cot bat buoc: Ma vat tu, Ten vat tu, Don vi
# Cot dieu kien: Ten block (mau), Layer (mau) -- it nhat 1 trong 2
# ============================================================

param([string]$Out = "")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ($Out -eq "") { $Out = Join-Path $root "config\DANH_MUC_VAT_TU.xlsx" }
$Out = [IO.Path]::GetFullPath($Out)

$headers = @("STT","Ma vat tu (*)","Ten vat tu (*)","Quy cach","Don vi (*)","He",
             "Ten block (mau)","Layer (mau)","Cach tinh","He so","Uu tien","Trang thai","Ghi chu")

# Moi dong: cac o phan cach bang dau |
$sampleLines = @(
 '1|VL-CCTV-001|Camera Dome IP|2MP, PoE|cai|HE-ELV|SE.DOME*|CCTV|Count|1.0|100|Active|Camera dome trong nha',
 '2|VL-CCTV-002|Camera Bullet IP|4MP, PoE|cai|HE-ELV|*BULLET*|CCTV|Count|1.0|100|Active|Camera ngoai troi',
 '3|VL-ELV-010|Cap mang CAT6|UTP CAT6|m|HE-ELV||Camera Cable;ELV-LINE-LT|SumLength|1.05|90|Active|He so 1.05 = hao hut 5%',
 '4|VL-ELV-020|May ghi hinh NVR|32 kenh|bo|HE-ELV|*NVR*|ELV-EQP|Count|1.0|100|Active|',
 '5|VL-ELV-030|Man hinh giam sat|32 inch|cai|HE-ELV|*MONITOR*|ELV-EQP|Count|1.0|100|Active|',
 '6|VL-DIEN-001|Ong PVC day 20mm|PVC D20|m|HE-DIEN||EL-COND-WALL-DN20;EL-COND-WALL-*|SumLength|1.0|100|Active|',
 '7|VL-DIEN-002|Day dien Cu/PVC 2.5|Cu/PVC 2x2.5|m|HE-DIEN||EL-CABLE-*|SumLength|1.02|90|Active|'
)

$systemLines = @(
 'HE-DIEN|He thong Dien',
 'HE-NUOC|He thong Cap thoat nuoc',
 'HE-ELV|He thong Dien nhe / ELV',
 'HE-PCCC|He thong Phong chay chua chay',
 'HE-DHKK|He thong Dieu hoa khong khi',
 'HE-THONG-GIO|He thong Thong gio'
)

$guide = @(
 "HUONG DAN DIEN DANH MUC VAT TU",
 "",
 "MUC DICH: nhap danh muc vat tu THAT cua cong ty de MTOPro tu dong phan loai khi boc tach.",
 "",
 "CACH LAM:",
 "  1. Mo sheet DANH_MUC",
 "  2. Sua/xoa cac dong vi du, dien vat tu that cua cong ty (moi vat tu 1 dong)",
 "  3. Luu file",
 "  4. Chay:  scripts\import-materials.ps1",
 "     -> sinh ra file rules.json dung duoc ngay",
 "",
 "---- Y NGHIA TUNG COT ----",
 "",
 "Ma vat tu (*)    : Ma trong danh muc cua cong ty (vd VL-CCTV-001)",
 "Ten vat tu (*)   : Ten chuan (vd Camera Dome IP)",
 "Quy cach         : Mo ta ky thuat (vd 2MP, PoE)",
 "Don vi (*)       : cai / bo / m / m2 / kg ...",
 "He               : Dien / Nuoc / ELV ... (tu do dat)",
 "Ten block (mau)  : Cach ky su DAT TEN BLOCK tren ban ve.",
 "                   Ho tro wildcard * va nhieu mau cach nhau bang ;",
 "                   Vi du: SE.DOME*;CAMERA-DOME*",
 "Layer (mau)      : Layer chua doi tuong, ho tro * va ;  Vi du: CCTV;ELV-CCTV*",
 "Cach tinh        : Count (dem) | SumLength (cong dai) | SumArea (cong dien tich) | AttributeSum",
 "He so            : Nhan them (hao hut). Vd 1.05 = +5%",
 "Uu tien          : So lon thang khi 1 doi tuong khop nhieu vat tu",
 "Trang thai       : Active (dung) / Draft (nhap)",
 "Ghi chu          : Ghi chu noi bo",
 "",
 "---- QUY TAC BAT BUOC ----",
 "",
 "* Ma vat tu, Ten vat tu, Don vi  PHAI co",
 "* PHAI co it nhat 1 trong 2: Ten block HOAC Layer",
 "  (neu khong, he thong khong biet nhan dang vat tu do)",
 "",
 "---- MẸO ----",
 "",
 "* Dung wildcard RONG VUA DU: 'SE.DOME*' thay vi liet ke tung ten",
 "* Uu tien theo layer neu ky su ve dung quy uoc layer",
 "* Vat tu nao chua biet cach ve -> de trong block/layer, Trang thai = Draft"
)

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$wb = $null
try {
    $wb = $xl.Workbooks.Add()
    $ws = $wb.Worksheets.Item(1)
    $ws.Name = "DANH_MUC"

    for ($c = 0; $c -lt $headers.Count; $c++) { $ws.Cells.Item(1, $c + 1).Value2 = $headers[$c] }

    $r = 2
    foreach ($line in $sampleLines) {
        $cells = $line -split '\|'
        for ($c = 0; $c -lt $cells.Count; $c++) { $ws.Cells.Item($r, $c + 1).Value2 = $cells[$c] }
        $r++
    }
    $lastRow = $r - 1

    $hdr = $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item(1,$headers.Count))
    $hdr.Font.Bold = $true
    $hdr.Interior.ColorIndex = 15
    $hdr.HorizontalAlignment = -4108
    $ws.Range($ws.Cells.Item(1,1), $ws.Cells.Item($lastRow, $headers.Count)).Borders.LineStyle = 1
    $ws.Columns.AutoFit() | Out-Null
    for ($c = 1; $c -le $headers.Count; $c++) {
        if ($ws.Columns.Item($c).ColumnWidth -gt 30) { $ws.Columns.Item($c).ColumnWidth = 30 }
    }
    $ws.Application.ActiveWindow.SplitRow = 1
    $ws.Application.ActiveWindow.FreezePanes = $true

    $ws2 = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $ws)
    $ws2.Name = "HUONG_DAN"
    for ($i = 0; $i -lt $guide.Count; $i++) { $ws2.Cells.Item($i + 1, 1).Value2 = $guide[$i] }
    $ws2.Cells.Item(1,1).Font.Bold = $true
    $ws2.Cells.Item(1,1).Font.Size = 14
    $ws2.Columns.Item(1).ColumnWidth = 95

    $ws3 = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $ws2)
    $ws3.Name = "HE_THONG"
    $ws3.Cells.Item(1,1).Value2 = "Ma he"
    $ws3.Cells.Item(1,2).Value2 = "Ten he"
    $rr = 2
    foreach ($line in $systemLines) {
        $cells = $line -split '\|'
        $ws3.Cells.Item($rr, 1).Value2 = $cells[0]
        $ws3.Cells.Item($rr, 2).Value2 = $cells[1]
        $rr++
    }
    $h3 = $ws3.Range($ws3.Cells.Item(1,1), $ws3.Cells.Item(1,2))
    $h3.Font.Bold = $true
    $h3.Interior.ColorIndex = 15
    $ws3.Columns.AutoFit() | Out-Null

    $ws.Activate()
    if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Force }
    $wb.SaveAs($Out, 51)
    $wb.Close($false)
    $wb = $null

    Write-Host ""
    Write-Host "=== DA TAO TEMPLATE ===" -ForegroundColor Green
    Write-Host ("  File      : {0}" -f $Out)
    Write-Host ("  Dung luong: {0} KB" -f [math]::Round((Get-Item $Out).Length/1KB,1))
    Write-Host ("  Vi du     : {0} vat tu mau" -f $sampleLines.Count)
    Write-Host "  3 sheet   : DANH_MUC (dien vao day) | HUONG_DAN | HE_THONG"
}
finally {
    if ($wb) { try { $wb.Close($false) } catch { } }
    try { $xl.Quit() } catch { }
    try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($xl) } catch { }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}