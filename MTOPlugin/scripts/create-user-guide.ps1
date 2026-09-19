$ErrorActionPreference = 'Stop'

# ============================================================
# Tao tai lieu Word: HUONG DAN SU DUNG MTOPlugin
# Chay:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-user-guide.ps1
# (Neu goi qua Invoke-Expression thi dat Current Directory = thu muc du an)
# ============================================================

$projectRoot = $null
if ($PSCommandPath) {
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
if (-not $projectRoot) {
    $projectRoot = (Get-Location).Path
}
$outputPath = Join-Path $projectRoot ('docs' + '\' + 'HƯỚNG DẪN SỬ DỤNG MTOPlugin.docx')

# ---- tu hang so Word ----
$CS_NORMAL   = -1   # wdStyleNormal
$CS_H1       = -2   # wdStyleHeading1
$CS_H2       = -3   # wdStyleHeading2
$CS_H3       = -4   # wdStyleHeading3
$ALIGN_LEFT  = 0
$ALIGN_CENTER = 1
$ALIGN_RIGHT = 2
$ALIGN_JUSTIFY = 3
$LINE_1PT5   = 1    # wdLineSpace1pt5
$ARG_ROW_STORY = 6  # wdStory
$FOOTER_PRIMARY = 1
$SAVE_DOCX   = 16   # wdFormatXMLDocument
$WD_PAGEBREAK = 7

$word = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    $doc = $word.Documents.Add()
    $ps  = $doc.PageSetup
    $ps.PageWidth  = 595.3
    $ps.PageHeight = 841.9
    $ps.TopMargin    = 56.7
    $ps.BottomMargin = 56.7
    $ps.LeftMargin   = 85.05
    $ps.RightMargin  = 56.7

    # ---- styles ----
    $stNormal = $doc.Styles.Item($CS_NORMAL)
    $stNormal.Font.Name = 'Times New Roman'
    $stNormal.Font.Size = 13
    $stNormal.Font.Color = 0
    $stNormal.ParagraphFormat.LineSpacingRule = $LINE_1PT5
    $stNormal.ParagraphFormat.SpaceAfter = 6

    function Set-HeadFont([int]$s, [int]$size) {
        $st = $doc.Styles.Item($s)
        $st.Font.Name = 'Times New Roman'
        $st.Font.Size = $size
        $st.Font.Bold = 1
        $st.Font.Color = 0
        $st.ParagraphFormat.LineSpacingRule = 0
        $st.ParagraphFormat.SpaceBefore = 12
        $st.ParagraphFormat.SpaceAfter = 6
    }
    Set-HeadFont $CS_H1 16
    Set-HeadFont $CS_H2 14
    Set-HeadFont $CS_H3 13

    $sel = $word.Selection

    function Move-ToEnd { $sel.EndKey($ARG_ROW_STORY) | Out-Null; $sel.Collapse(0) | Out-Null }

    function Add-Body([string]$text, [int]$align = 3) {
        Move-ToEnd
        $sel.Style = $doc.Styles.Item($CS_NORMAL)
        $sel.ParagraphFormat.Alignment = $align
        $sel.TypeText($text) | Out-Null
        $sel.TypeParagraph() | Out-Null
    }

    function Add-Bullet([string]$text) {
        Move-ToEnd
        $sel.ParagraphFormat.Alignment = 3
        $sel.TypeText('- ' + $text) | Out-Null
        $sel.TypeParagraph() | Out-Null
    }

    function Add-Space([int]$n = 1) {
        for ($i = 0; $i -lt $n; $i++) { Move-ToEnd; $sel.TypeParagraph() | Out-Null }
    }

    function Add-Head([int]$level, [string]$text) {
        Move-ToEnd
        $styleId = 0
        if ($level -eq 1) { $styleId = $CS_H1 }
        elseif ($level -eq 2) { $styleId = $CS_H2 }
        else { $styleId = $CS_H3 }
        $sel.Style = $doc.Styles.Item($styleId)
        $sel.TypeText($text) | Out-Null
        $sel.TypeParagraph() | Out-Null
        $sel.Style = $doc.Styles.Item($CS_NORMAL)
    }

    function Add-Table([object[]]$data) {
        Move-ToEnd
        $rows = $data.Count
        $cols = $data[0].Count
        $rng = $sel.Range
        $tbl = $doc.Tables.Add($rng, $rows, $cols)
        $tbl.Borders.Enable = 1
        $tbl.Range.Font.Name = 'Times New Roman'
        $tbl.Range.Font.Size = 12
        $tbl.Rows.Item(1).Range.Font.Bold = 1
        $tbl.Rows.Item(1).Range.ParagraphFormat.Alignment = 1
        for ($r = 0; $r -lt $rows; $r++) {
            for ($c = 0; $c -lt $cols; $c++) {
                $tbl.Cell(($r + 1), ($c + 1)).Range.Text = $data[$r][$c].ToString()
            }
        }
        $tbl.AutoFitBehavior(2) | Out-Null
        Move-ToEnd
        $sel.TypeParagraph() | Out-Null
    }

    # ======================= TRANG BIA =======================
    Add-Space 3
    $sel.ParagraphFormat.Alignment = $ALIGN_CENTER
    $sel.Font.Name = 'Times New Roman'; $sel.Font.Size = 14; $sel.Font.Bold = 0
    $sel.TypeText('PHÒNG DỰ ÁN') | Out-Null; $sel.TypeParagraph()
    Add-Space 1
    $sel.Font.Bold = 1; $sel.Font.Size = 18
    $sel.TypeText('HƯỚNG DẪN SỬ DỤNG') | Out-Null; $sel.TypeParagraph()
    $sel.TypeText('PLUGIN BÓC TÁCH KHỐI LƯỢNG M&E TRÊN AUTOCAD') | Out-Null; $sel.TypeParagraph()
    Add-Space 2
    $sel.Font.Bold = 0; $sel.Font.Size = 13
    $sel.TypeText('Mã đề tài: R&D-CAD-QTO-01') | Out-Null; $sel.TypeParagraph()
    $sel.TypeText('Phiên bản phần mềm: 0.1.0 (developer preview)') | Out-Null; $sel.TypeParagraph()
    Add-Space 2
    $sel.Font.Bold = 1; $sel.Font.Size = 13; $sel.ParagraphFormat.Alignment = 0
    $sel.TypeText('Thông tin tài liệu') | Out-Null; $sel.TypeParagraph()
    Add-Table @(
        @('Mục', 'Nội dung'),
        @('Tên tài liệu', 'Hướng dẫn sử dụng plugin bóc tách khối lượng M&E trên AutoCAD'),
        @('Đối tượng sử dụng', 'Kỹ sư M&E, cán bộ định lượng (QS), người quản trị quy trình'),
        @('Người soạn', '......................................  Ngày ...............  Ký ..................'),
        @('Người duyệt', '......................................  Ngày ...............  Ký ..................'),
        @('Tài liệu liên quan', 'Đề cương đề tài; BIOS: BUILD.md, INSTALL.md, RULES.md, ARCHITECTURE.md, TESTING.md')
    )
    $doc.ActiveWindow.Selection.InsertBreak($WD_PAGEBREAK) | Out-Null

    # ======================= MUC LUC =======================
    $sel.EndKey($ARG_ROW_STORY) | Out-Null
    $sel.Collapse(0) | Out-Null
    $sel.Style = $doc.Styles.Item($CS_H1)
    $sel.TypeText('MỤC LỤC') | Out-Null
    $sel.TypeParagraph() | Out-Null
    $sel.Style = $doc.Styles.Item($CS_NORMAL)
    $toc = $null
    try {
        $tocRng = $sel.Range
        $toc = $doc.TablesOfContents.Add($tocRng, $true, 1, 2, $false, '', $true, $true, '', $true, $false, $true)
    } catch {
        try { $f = $doc.Fields.Add($sel.Range, -1, 'TOC \o "1-2" \h \z \u', $false); $f.Update() | Out-Null } catch { }
    }
    Move-ToEnd
    $doc.ActiveWindow.Selection.InsertBreak($WD_PAGEBREAK) | Out-Null

    # ======================= 1. GIOI THIEU =======================
    Add-Head 1 '1. GIỚI THIỆU'
    Add-Head 2 '1.1. Mục đích'
    Add-Body 'Plugin MTOPlugin tự động quét bản vẽ AutoCAD (DWG), phân loại đối tượng M&E theo bộ quy tắc do kỹ sư M&E phê duyệt, và xuất bảng khối lượng (bóc tách) sang Excel. Mục tiêu là chuẩn hóa quy trình bóc tách, giảm sai sót do thủ công, tăng tốc độ và minh bạch trong đối chiếu với bản vẽ.'
    Add-Head 2 '1.2. Nguyên tắc an toàn'
    Add-Bullet 'CHỈ ĐỌC bản vẽ (OpenMode.ForRead) - không ghi, không sửa file DWG gốc.'
    Add-Bullet 'Không dùng AI tự suy đoán: nếu đối tượng không khớp quy tắc, đưa vào sheet CHUA_PHAN_LOAI để kỹ sư quyết định.'
    Add-Bullet 'Lưu đồng thời giá trị gốc (theo đơn vị vẽ) và giá trị quy đổi - có thể dò ngược khi có thắc mắc.'
    Add-Head 2 '1.3. Phạm vi áp dụng'
    Add-Body 'Chỉ dùng cho công tác bóc tách khối lượng công trình M&E (điện, nước, HVAC, PCCC...) do Phòng Dự án quản lý. AutoLISP chỉ là công cụ phụ trợ; chức năng chính chạy trên AutoCAD .NET API.'
    Add-Head 2 '1.4. Luồng làm việc 2 bước'
    Add-Body 'Panel MTO hoạt động theo luồng 2 bước: (Bước 1) Quét bản vẽ + Phân loại theo bộ quy tắc; (Bước 2) đánh dấu các dòng muốn xuất trong bảng kết quả, rồi Xuất Excel các mục đã chọn (hoặc Xuất TOÀN BỘ). Có thể truy vết từng đối tượng bằng cách nhấp đúp vào dòng để zoom tới đối tượng trên bản vẽ.'
    Add-Head 2 '1.5. Cài đặt trong 30 giây'
    Add-Body 'Người dùng chỉ nhận MỘT file duy nhất MTOPlugin.Setup-0.1.0.exe. Double-click là bộ cài tự động nhận diện AutoCAD 2018-2026 đã cài, sao chép plugin và đăng ký. Chi tiết tại mục 3.'

    # ======================= 2. YEU CAU HE THONG =======================
    Add-Head 1 '2. YÊU CẦU HỆ THỐNG'
    Add-Table @(
        @('Hạng mục', 'Yêu cầu'),
        @('Hệ điều hành', 'Windows 10/11 64-bit'),
        @('Phần mềm', 'AutoCAD đầy đủ (full, x64) từ 2018 đến 2026. KHÔNG hỗ trợ AutoCAD LT'),
        @('.NET Framework', '4.8 (AutoCAD 2018-2024 có sẵn)'),
        @('.NET 8', 'AutoCAD 2025/2026 chạy .NET 8 Desktop Runtime (AutoCAD cài sẵn, người dùng không cần cài thêm)'),
        @('Excel', '2010 trở lên (để mở file kết quả)'),
        @('Quyền', 'Không cần quyền Admin cho bộ cài one-click (cài cho người dùng hiện tại)')
    )
    Add-Head 2 '2.1. Nhóm phiên bản AutoCAD'
    Add-Body 'Do mỗi nhóm phiên bản AutoCAD dùng bộ assembly API khác nhau (AutoCAD 2025+ chuyển sang .NET 8), plugin phải build riêng DLL theo nhóm. Bộ cài EXE tự cài CẢ BA nhóm; mỗi AutoCAD chỉ tự nạp đúng nhóm của nó (nhờ khai báo trong PackageContents.xml nên không xung đột):'
    Add-Table @(
        @('Nhóm', 'Bundle', 'AutoCAD', 'Target .NET', 'Ghi chú'),
        @('A', 'MTOPlugin.2018-2022.bundle', '2018-2022 (R22.0-R24.1)', 'net48', 'Chưa xác minh trên máy thật'),
        @('B', 'MTOPlugin.2023-2024.bundle', '2023-2024 (R24.2-R24.3)', 'net48', 'Chưa xác minh trên máy thật'),
        @('C', 'MTOPlugin.2025-2026.bundle', '2025-2026 (R25.0-R26.0)', 'net8.0-windows', 'Build + cài đặt EXE đã xác minh; chờ load/đo kiểm trong AutoCAD')
    )
    Add-Body 'Nhóm nào chưa qua vòng kiểm thử nghiệm thu sẽ ghi rõ "Chưa xác minh". Với bản cài thủ công (không dùng EXE), phải cài đúng nhóm phiên bản; tuyệt đối không dùng DLL bản net48 trên AutoCAD 2025/2026.'

    # ======================= 3. CAI DAT =======================
    Add-Head 1 '3. CÀI ĐẶT'
    Add-Head 2 '3.1. Cách 1 - Bộ cài One-click (khuyên dùng)'
    Add-Body 'Người dùng cuối không cần thao tác kỹ thuật. Chỉ cần:'
    Add-Body 'B1. Nhận file MTOPlugin.Setup-0.1.0.exe từ bộ phận phát triển.'
    Add-Body 'B2. Đảm bảo AutoCAD đã cài sẵn trên máy (đang tắt hoặc mở đều được).'
    Add-Body 'B3. DOUBLE-CLICK file EXE. Màn hình hiện tiến trình và xác nhận hoàn tất.'
    Add-Body 'B4. Đóng rồi MỞ LẠI AutoCAD (nếu đang chạy).'
    Add-Body 'B5. Gõ lệnh MTO để mở panel bóc tách khối lượng.'
    Add-Bullet 'Bộ cài tự động: nhận diện mọi AutoCAD 2018-2026, cài CẢ BA nhóm plugin vào %APPDATA%\Autodesk\ApplicationPlugins, tự chọn đúng nhóm khi AutoCAD nạp, cài bộ quy tắc mẫu lần đầu, ghi nhật ký tại %LOCALAPPDATA%\MTOPlugin\logs\setup.log.'
    Add-Bullet 'Gỡ cài: chạy lệnh MTOPlugin.Setup-0.1.0.exe --uninstall-silent, hoặc xóa thư mục MTOPlugin.*.bundle trong %APPDATA%\Autodesk\ApplicationPlugins.'
    Add-Bullet 'Không cần quyền Admin, không thay đổi file DWG, không sửa cấu hình AutoCAD.'
    Add-Head 2 '3.2. Cách 2 - Cài thủ công bằng NETLOAD (cho kiểm thử nhanh)'
    Add-Body 'Phù hợp với bộ phận kỹ thuật/kiểm thử tại chỗ, không phải người dùng cuối:'
    Add-Body 'B1. Build đúng nhóm AutoCAD đang dùng: AutoCAD 2025+ dùng thư mục src\MTOPlugin\bin\Release\net8.0-windows; AutoCAD 2018-2024 dùng thư mục net48.'
    Add-Body 'B2. Sao chép toàn bộ file sau vào CÙNG một thư mục: MTOPlugin.dll, MTOPlugin.Core.dll, MTOPlugin.UI.dll, MTOPlugin.Logging.dll, EPPlus.dll, Newtonsoft.Json.dll.'
    Add-Body 'B3. Mở AutoCAD, gõ lệnh NETLOAD, chọn MTOPlugin.dll (đúng nhóm phiên bản).'
    Add-Body 'B4. Gõ lệnh MTO.'
    Add-Bullet 'Hạn chế: phải NETLOAD lại mỗi lần mở AutoCAD; không được APPLOAD quản lý.'
    Add-Head 2 '3.3. Cách 3 - Cài thủ công bằng bundle (không bắt buộc)'
    Add-Body 'Trường hợp không dùng EXE: copy nguyên thư mục bundle đúng nhóm vào %APPDATA%\Autodesk\ApplicationPlugins\ rồi mở lại AutoCAD. MTOPlugin.2025-2026.bundle dành cho 2025-2026 (bản .NET 8); MTOPlugin.2023-2024.bundle dành cho 2023-2024; MTOPlugin.2018-2022.bundle dành cho 2018-2022. Có thể cài đủ cả ba.'
    Add-Head 2 '3.4. Cách 4 - Tự tạo bộ cài EXE (chỉ dành cho bộ phận phát triển)'
    Add-Body 'Chạy trên máy có .NET SDK 8 (đã build được nhóm DLL):'
    Add-Body '  1) scripts\build.ps1 -AcadVersion 2025; scripts\build.ps1 -AcadVersion 2023; scripts\build.ps1 -AcadVersion 2020'
    Add-Body '  2) scripts\deploy-bundle.ps1 -AcadVersion 2025; scripts\deploy-bundle.ps1 -AcadVersion 2023; scripts\deploy-bundle.ps1 -AcadVersion 2020'
    Add-Body '  3) scripts\build-installer.ps1'
    Add-Body 'Sinh ra file duy nhất output\MTOPlugin.Setup-0.1.0.exe (payload nhúng sẵn trong file). Chi tiết xem BUILD.md, INSTALL.md.'

    # ======================= 4. CAU HINH BAN DAU =======================
    Add-Head 1 '4. CẤU HÌNH BAN ĐẦU'
    Add-Head 2 '4.1. Bộ quy tắc (rules.json)'
    Add-Body 'Plugin phân loại theo file JSON. File mẫu được cài tự động lần đầu tại %LOCALAPPDATA%\MTOPlugin\config\rules.json (chỉ cài khi chưa tồn tại - không ghi đè khi đã chỉnh sửa). Bộ quy tắc do kỹ sư M&E phê duyệt, bao gồm:'
    Add-Table @(
        @('Trường', 'Ý nghĩa'),
        @('systemCode / systemName', 'Hệ thống: DIEN, NUOC, HVAC, PCCC...'),
        @('materialCode / materialName', 'Mã và tên vật tư / công việc'),
        @('unit', 'Đơn vị xuất (cái, m, m2, kg...)'),
        @('calculation', 'Cách tính: CountBlocks, CountAttributes, SumLength, SumArea, SumAttributeValue'),
        @('conditions', 'Điều kiện khớp: layer, block name (wildcard/regex), attribute, entity kind'),
        @('priority', 'Ưu tiên khi nhiều quy tắc cùng khớp (số cao thắng)'),
        @('status', 'Active/Inactive')
    )
    Add-Head 2 '4.2. Đơn vị vẽ'
    Add-Body 'Plugin tự đọc đơn vị bản vẽ (DWGUNITS/Insunits) và cho chọn đơn vị xuất (mm, cm, m, ft, in). Nên kiểm tra đơn vị xuất trước khi bấm quét để file Excel đúng đơn vị mong muốn.'

    # ======================= 5. SU DUNG =======================
    Add-Head 1 '5. SỬ DỤNG PLUGIN'
    Add-Head 2 '5.1. Mở panel'
    Add-Body 'Trong AutoCAD gõ lệnh MTO. Bảng điều khiển MTOPlugin hiện ra gồm 2 bước và bảng kết quả:'
    Add-Table @(
        @('Điều khiển', 'Chức năng'),
        @('Chọn phạm vi quét', 'Vùng chọn / Toàn bộ Model / Model + Layout hiện tại / Toàn bộ Layout / Model + Tất cả Layout'),
        @('Chế độ Xref', 'Ignore (bỏ qua xref); UniqueBySource (quét, khử trùng 1 lần/nguồn); PerInsertion (tính theo từng lần chèn)'),
        @('File bộ quy tắc', 'Nút ... để chọn rules.json'),
        @('Đơn vị', 'Đơn vị gốc (tự nhận dạng) và đơn vị xuất (mm/cm/m/ft/in)'),
        @('BƯỚC 1 - Quét + Phân loại', 'Quét theo phạm vi đã chọn, phân loại đối tượng theo bộ quy tắc, hiện bảng kết quả'),
        @('BƯỚC 2 - Xuất Excel các mục đã chọn', 'Chỉ xuất các dòng được đánh dấu trong bảng kết quả (TONG_HOP tính lại theo các dòng đã chọn)'),
        @('Xuất Excel TOÀN BỘ', 'Xuất toàn bộ kết quả của lần quét hiện tại'),
        @('Chọn tất cả / Bỏ chọn', 'Đánh dấu hoặc bỏ hết các dòng kết quả'),
        @('Bảng kết quả', 'Danh sách đối tượng: hệ thống, mã/tên vật tư, layer, tầng/layout, khối lượng, trạng thái; nhấp đúp 1 dòng để zoom tới đối tượng trên bản vẽ'),
        @('Kết quả nhanh', 'Số đối tượng quét / đã phân loại / chưa phân loại / số cảnh báo'),
        @('Khung log', 'Nhật ký chi tiết phiên')
    )
    Add-Head 2 '5.2. Các bước thao tác chuẩn (luồng 2 bước)'
    Add-Body 'B1. Mở đúng file DWG (bản vẽ mẹ hoặc phối hợp).'
    Add-Body 'B2. Chọn phạm vi quét và chế độ xref phù hợp với yêu cầu khối lượng.'
    Add-Body 'B3. Chọn bộ quy tắc đã được kỹ sư M&E phê duyệt; kiểm tra đơn vị xuất.'
    Add-Body 'B4. Bấm BƯỚC 1 (Quét + Phân loại). Chờ bảng kết quả hiện ra; kiểm tra số liệu nhanh trên panel.'
    Add-Body 'B5. Đánh dấu (tích) các dòng cần xuất, hoặc bấm Chọn tất cả. Nhấp đúp 1 dòng để zoom xác minh đối tượng trên bản vẽ.'
    Add-Body 'B6. Bấm BƯỚC 2 (Xuất Excel các mục đã chọn) hoặc Xuất Excel TOÀN BỘ. Chọn nơi lưu file .xlsx.'
    Add-Body 'B7. Mở file Excel kiểm tra. Nếu CHUA_PHAN_LOAI dày, rà lại quy tắc hoặc gửi kỹ sư xác nhận rồi bổ sung quy tắc.'
    Add-Head 2 '5.3. Lệnh hỗ trợ'
    Add-Table @(
        @('Lệnh', 'Chức năng'),
        @('MTO', 'Mở/đóng panel bóc tách khối lượng'),
        @('MTOZOOM <handle>', 'Phóng đến đúng đối tượng theo Handle (dạng hex) để đối chiếu kết quả'),
        @('MTOBANG', 'Tạo bảng tổng hợp khối lượng ngay trên BẢN VẼ MỚI (không sửa bản vẽ gốc); dữ liệu lấy từ lần quét gần nhất trong phiên')
    )

    # ======================= 6. KET QUA XUAT EXCEL =======================
    Add-Head 1 '6. KẾT QUẢ XUẤT EXCEL'
    Add-Body 'File kết quả gồm 05 sheet:'
    Add-Table @(
        @('Sheet', 'Nội dung'),
        @('TONG_HOP', 'Tổng khối lượng theo hệ thống/mã vật tư - dùng để trình báo cáo. Khi Xuất các mục đã chọn, tổng được tính lại theo đúng các dòng đã chọn'),
        @('CHI_TIET', 'Chi tiết từng đối tượng (chỉ các mục đã chọn khi dùng BƯỚC 2): tên, layout/tầng, layer, xref nguồn, kích thước gốc và quy đổi'),
        @('CHUA_PHAN_LOAI', 'Đối tượng chưa khớp bộ quy tắc (chỉ ghi các mục đã chọn khi dùng BƯỚC 2) - CẦN xử lý của kỹ sư'),
        @('CANH_BAO_LOI', 'Cảnh báo/sai quy chuẩn: layer lạ, block lạ, xref thiếu, file lỗi'),
        @('THONG_TIN_LAN_QUET', 'Meta phiên: file, phạm vi, đơn vị, bộ quy tắc, "Kieu xuat" (toan bo / da chon), "So muc da xuat", tổng số, thời gian')
    )
    Add-Body 'Lưu ý: khi Xuất các mục đã chọn mà không có dòng nào được đánh dấu, plugin sẽ từ chối và yêu cầu chọn trước. Plugin TỪ CHỐI xuất file khi bản vẽ rỗng trong phạm vi (không muốn sinh file 0m vô nghĩa).'

    # ======================= 7. QUAN LY BO QUY TAC =======================
    Add-Head 1 '7. QUẢN LÝ BỘ QUY TẮC'
    Add-Body 'Bộ quy tắc là trái tim của plugin. Quy trình: kỹ sư M&E soạn/xác nhận quy tắc trên mẫu, kiểm tra bằng dữ liệu chuẩn, lưu rules.json, đưa vào bản cài/cấu hình. Khi bản vẽ thay đổi quy ước đặt tên layer/block, phải cập nhật quy tắc và nghiệm thu lại.'
    Add-Bullet 'Các đối tượng nằm trong model và các layout được quét theo từng layout riêng để cột Tầng/Layout rõ ràng.'
    Add-Bullet 'Độ ưu tiên quy tắc: số cao hơn thắng khi nhiều quy tắc cùng trùng điều kiện.'

    # ======================= 8. XU LY SU CO =======================
    Add-Head 1 '8. XỬ LÝ SỰ CỐ THƯỜNG GẶP'
    Add-Table @(
        @('Sự cố', 'Nguyên nhân', 'Giải pháp'),
        @('EXE báo không thấy nội dung cài đặt (payload)', 'File EXE được build trên máy chưa có nhóm DLL', 'Bộ phận phát triển chạy lại scripts\build-installer.ps1 sau khi build+deploy đủ nhóm'),
        @('Cài xong nhưng gõ MTO báo không có lệnh', 'Load lỗi lúc khởi động / nhóm phiên bản sai', 'Xem log %LOCALAPPDATA%\MTOPlugin\logs; cài lại với phiên bản EXE mới nhất'),
        @('Không tải được assembly / dependency is not present', 'Thiếu DLL đi kèm (chỉ gặp khi cài thủ công)', 'Dùng bộ cài EXE; nếu cài tay phải đủ Core/UI/Logging/EPPlus/LSJSON cùng thư mục'),
        @('BadImageFormat / CS1705 lúc build', 'Nhầm x86/x64; hoặc dùng DLL net48 trên AutoCAD 2025+', 'Dùng bộ cài EXE (tự chọn nhóm); cài tay/build phải đúng nhóm (net8.0-windows cho 2025+)'),
        @('Bundle không tự nạp', 'AppAutoLoad tắt hoặc cài sai thư mục', 'Xác nhận %APPDATA%\Autodesk\ApplicationPlugins có MTOPlugin.*.bundle; bật auto-load trong APPLOAD'),
        @('Export báo không có dữ liệu', 'Bản vẽ rỗng trong phạm vi / phạm vi sai / chưa chọn dòng nào khi dùng BƯỚC 2', 'Bảo vệ có chủ đích; chọn lại phạm vi có dữ liệu; đánh dấu ít nhất 1 dòng trước khi Xuất các mục đã chọn'),
        @('Sai đơn vị khối lượng', 'Đơn vị xuất không đúng / bản vẽ trộn đơn vị', 'Chọn lại đơn vị xuất; báo bộ phận phát triển nếu file vẽ trộn đơn vị')
    )

    # ======================= 9. NHAT KY =======================
    Add-Head 1 '9. NHẬT KÝ PHIÊN VÀ LƯU TRỮ'
    Add-Table @(
        @('Nội dung', 'Đường dẫn'),
        @('Nhật ký bộ cài EXE', '%LOCALAPPDATA%\MTOPlugin\logs\setup.log'),
        @('Nhật ký phiên plugin', '%LOCALAPPDATA%\MTOPlugin\logs (*.log)'),
        @('Bộ quy tắc đang dùng', '%LOCALAPPDATA%\MTOPlugin\config\rules.json'),
        @('Bundle đã cài', '%APPDATA%\Autodesk\ApplicationPlugins\MTOPlugin.*.bundle'),
        @('Bộ quy tắc mẫu', 'config\rules.sample.json trong dự án (kho quy tắc chuẩn)')
    )
    Add-Body 'Nhật ký ghi theo thời gian: lỗi, cảnh báo, thông tin, hành động của người dùng, file xref bị thiếu... phục vụ truy vết và nghiệm thu.'

    # ======================= 10. PHU LUC =======================
    Add-Head 1 '10. PHỤ LỤC'
    Add-Head 2 '10.1. Bảng ký hiệu - thuật ngữ'
    Add-Table @(
        @('Thuật ngữ', 'Ý nghĩa'),
        @('Xref', 'Bản vẽ tham chiếu ngoài (External Reference)'),
        @('Block reference', 'Đối tượng chèn từ định nghĩa block (INSERT)'),
        @('Dynamic block', 'Block có thể thay đổi kích thước/hình dạng khi chèn'),
        @('Handle', 'Mã định danh duy nhất của thực thể trong DWG (hệ hex)'),
        @('DWGUNITS / Insunits', 'Đơn vị đo lường của bản vẽ'),
        @('Model / Layout', 'Không gian vẽ thực / không gian in (giấy)'),
        @('Payload', 'Phần nội dung plugin nhúng sẵn bên trong file EXE cài đặt')
    )
    Add-Head 2 '10.2. Cấu trúc thư mục cài đặt (bundle)'
    Add-Body 'MTOPlugin.<nhóm>.bundle -> PackageContents.xml + Contents\Windows\MTOPlugin.dll (+ các DLL đi kèm). Có 3 nhóm: 2018-2022, 2023-2024, 2025-2026.'

    # ---- header & footer ----
    $headerRange = $doc.Sections.Item(1).Headers.Item($FOOTER_PRIMARY).Range
    $headerRange.Text = 'MTOPlugin - Hướng dẫn sử dụng' + [char]32 + [char]32 + 'Mã đề tài: R&D-CAD-QTO-01'
    $headerRange.Font.Name = 'Times New Roman'; $headerRange.Font.Size = 9
    $headerRange.ParagraphFormat.Alignment = 1

    $footerRange = $doc.Sections.Item(1).Footers.Item($FOOTER_PRIMARY).Range
    $footerRange.Text = ''
    $footerRange.ParagraphFormat.Alignment = 1
    $fld = $doc.Fields.Add($footerRange, -1, 'PAGE', $false)

    # ---- luu ----
    $doc.SaveAs([string]$outputPath, [int]$SAVE_DOCX)

    # ---- hoan thien MUC LUC: cap nhat + repaginate, luu lai ----
    try {
        if ($toc) { $toc.Update() | Out-Null }
        $doc.Fields.Update() | Out-Null
        $doc.Repaginate() | Out-Null
        $doc.SaveAs([string]$outputPath, [int]$SAVE_DOCX)
        Write-Output 'TOC da duoc cap nhat va trang lai.'
    } catch {
        Write-Output ('Canh bao: chua cap nhat TOC tu dong duoc (' + $_.Exception.Message + '). Mo file an F9 neu can.')
    }

    $doc.Close(0, $false, $false) | Out-Null
    Write-Output ('OK: ' + $outputPath)
}
finally {
    if ($word) {
        $word.Quit() | Out-Null
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    }
}