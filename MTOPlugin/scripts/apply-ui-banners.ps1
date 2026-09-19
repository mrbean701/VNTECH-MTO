$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$lisp = Join-Path $root "lisp"

$map = [ordered]@{
  '(princ "\n=== MTO Interactive Selection (TASK-001) ===")'      = @("MTOSEL",     "Chon vung + loc theo layer / loai doi tuong")
  '(princ "\n=== MTO Text Prefix Recognition (TASK-002) ===")'    = @("MTOTEXT",    "Nhan dang TEXT / MTEXT theo prefix")
  '(princ "\n=== MTO Block Counting (TASK-003) ===")'             = @("MTOBLK",     "Dem block theo ten")
  '(princ "\n=== MTO Manual Adjustment (TASK-003) ===")'          = @("MTOBLKMAN",  "Dieu chinh so luong thu cong")
  '(princ "\n=== MTO Geometry Quantity (TASK-004) ===")'          = @("MTOGEO",     "Do chieu dai cap / ong / tray")
  '(princ "\n=== MTO Result List (TASK-006) ===")'                = @("MTOLIST",    "Bang ket qua khoi luong")
  '(princ "\n=== MTO CSV Export (TASK-007) ===")'                 = @("MTOCSV",     "Xuat ket qua ra file CSV")
  '(princ "\n=== MTO Orphan Detection (TASK-008) ===")'           = @("MTOORPHAN",  "Kiem tra du lieu mo coi")
  '(princ "\n=== MTO AutoCAD Table (TASK-009) ===")'              = @("MTOTABLE",   "Ve bang khoi luong len ban ve")
  '(princ "\n=== TU KIEM TRA BANG NATIVE (ActiveX Table) ===")'   = @("MTOTESTNATIVE", "Tu kiem tra bang NATIVE co du lieu")
  '(princ "\n=== MTO Find / Zoom Back (TASK-010) ===")'           = @("MTOFIND",    "Tim doi tuong theo STT / tu khoa")
  '(princ "\n=== MTO Batch Update (TASK-011) ===")'               = @("MTOUPDATE",  "Cap nhat TEXT / MTEXT + ghi XData")
  '(princ "\n=== MTO Snapshot (TASK-012) ===")'                   = @("MTOSNAP",    "Chup anh du lieu truoc khi sua")
  '(princ "\n=== MTO Undo / Restore (TASK-012) ===")'             = @("MTOUNDO",    "Khoi phuc du lieu tu anh chup")
  '(princ "\n=== MTO Custom Formula (TASK-013) ===")'             = @("MTOFORMULA", "Cong thuc tinh tuy chinh")
  '(princ "\n=== MTO Subtotal & Grouping (TASK-014) ===")'        = @("MTOSUB",     "Subtotal / gom nhom theo khoa")
  '(princ "\n=== MTO Deduction (khau tru) (TASK-014) ===")'       = @("MTODED",     "Khau tru khoi luong")
  '(princ "\n=== MTO Floor / Zone / Area (TASK-015) ===")'        = @("MTOFLOOR",   "Gan tang / khu vuc / dien tich")
  '(princ "\n=== MTO Per-Drawing Configuration (TASK-016) ===")'  = @("MTOCFG",     "Cau hinh theo tung ban ve")
}

$total = 0
foreach ($f in Get-ChildItem -Path $lisp -Filter "*.lsp" -File) {
    $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $orig = $text
    $cnt = 0
    foreach ($old in $map.Keys) {
        if ($text.Contains($old)) {
            $cmd  = $map[$old][0]
            $desc = $map[$old][1]
            $new  = '(mto-ui-start "' + $cmd + '" "' + $desc + '")'
            $text = $text.Replace($old, $new)
            $cnt++
        }
    }
    if ($text -ne $orig) {
        [IO.File]::WriteAllText($f.FullName, $text, (New-Object Text.UTF8Encoding($false)))
        Write-Host ("  {0,-22} {1} banner" -f $f.Name, $cnt)
        $total += $cnt
    }
}
Write-Host ""
Write-Host ("Tong so banner da thay: {0}" -f $total)