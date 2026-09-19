# GIỚI THIỆU DỰ ÁN — MTOPro

**Tên đề tài:** Nghiên cứu và phát triển thử nghiệm plugin bóc tách khối lượng M&E trên AutoCAD
**Mã đề tài:** R&D-CAD-QTO-01 · **Đơn vị chủ trì:** Phòng Dự án
**Phiên bản:** 1.0 · **Ngày:** 18/09/2026

---

## 1. Tóm tắt

**MTOPro** là bộ công cụ bóc tách khối lượng (Quantity Take-Off) chạy **trực tiếp trong AutoCAD**,
phục vụ 3 hệ: **Điện — Nước — Điện nhẹ (ELV)**.

Mục tiêu: giảm thao tác thủ công của kỹ sư M&E / QS khi đếm thiết bị, đo chiều dài tuyến,
tổng hợp khối lượng và đối chiếu ngược về bản vẽ.

| Chỉ số | Giá trị |
|---|---|
| Số lệnh | **22** |
| Module LISP | **17** (~3.545 dòng) |
| Test tự động | **617 test — PASS toàn bộ** |
| Bộ quy tắc mẫu | **110 quy tắc / 11 hệ** |
| Bug thật đã phát hiện & sửa | **22** |
| Bộ cài | **1 file EXE** (850 KB) — cài LISP + .NET + cấu hình + tài liệu |

---

## 2. Kiến trúc công nghệ

### 2.1 Nguyên tắc kiến trúc

```
LISP-first  →  LISP + AutoCAD Table  →  .NET extension (chỉ khi cần)
```

**Lý do chọn LISP làm lõi:**
1. **Tương thích rộng** — một bộ LISP chạy được trên nhiều phiên bản AutoCAD, không phải build lại theo nhóm TFM (net48 / net8).
2. **Không cần biên dịch** — sửa/nghiệm thu nhanh, không cần .NET SDK.
3. **Đúng bản chất công cụ CAD** — thao tác chọn vùng, đọc DXF, sửa entity là sở trường của AutoLISP.
4. **Yêu cầu đề tài**: không chuyển logic sang .NET nếu AutoLISP làm tốt.

.NET chỉ đảm nhận phần **giao diện** (palette WPF) và **xuất Excel nâng cao** — không chứa logic nhận dạng/đếm.

### 2.2 Sơ đồ thành phần

```
┌──────────────────────────────────────────────────────────────────┐
│                        AutoCAD 2023                              │
│                                                                  │
│  ┌──────────────────── LÕI LISP (chính) ────────────────────┐    │
│  │  mto-loader ──► nạp 16 module                            │    │
│  │                                                          │    │
│  │  mto-core      data model 24 khoá · tiện ích chuỗi/số    │    │
│  │  mto-select    ssget W/C/WP/CP/F · lọc layer/loại        │    │
│  │  mto-text      TEXT/MTEXT · prefix (46) · wcmatch        │    │
│  │  mto-block     đếm block · AUTO + MANUAL                 │    │
│  │  mto-geometry  vlax-curve · SumLength · INSUNITS         │    │
│  │  mto-result    bảng kết quả · thống kê                   │    │
│  │  mto-csv       xuất CSV (RFC4180 escape)                 │    │
│  │  mto-orphan    handent + entget · prune                  │    │
│  │  mto-table     AutoCAD Table · 2 backend                 │    │
│  │  mto-find      ZOOM _O · sssetfirst · tra handle         │    │
│  │  mto-update    entmod TEXT/MTEXT · XData (XRecord)       │    │
│  │  mto-undo      snapshot HANDLE→OLD VALUE                 │    │
│  │  mto-formula   công thức (không dùng eval)               │    │
│  │  mto-subtotal  group/subtotal/deduction                   │    │
│  │  mto-floor     Floor/Zone/Area · gán theo layer/vùng     │    │
│  │  mto-config    cấu hình theo DWG (file + NOD)            │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────── .NET (phụ trợ) ──────────────────────────┐    │
│  │  MTOPlugin.dll     lệnh .NET (MTO panel, MTOZOOM…)       │    │
│  │  MTOPlugin.UI.dll  palette WPF + Rule Editor             │    │
│  │  MTOPlugin.Core    engine C# (rule, classify, Excel)     │    │
│  │  MTOPlugin.Logging nhật ký phiên                         │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Chức năng chi tiết

### 3.1 Nạp & nhận dạng dữ liệu

| Chức năng | Lệnh | Cách hoạt động |
|---|---|---|
| **Chọn vùng** | `MTOSEL` | `ssget` với 5 chế độ: Window, Crossing, WindowPolygon, CrossPolygon, Fence. Lọc theo entity type (DXF 0) + layer (DXF 8, hỗ trợ wildcard `*`, `?`) |
| **Nhận dạng chữ** | `MTOTEXT` | Đọc DXF 1 của TEXT/MTEXT, **bóc mã định dạng MTEXT** (`{\fArial\|b0;…}`, `\A1;`, `\P`, `\~`), tách **prefix** theo bảng 46 mục + kiểm tra **ranh giới** |
| **Đếm block** | `MTOBLK` | Chọn block mẫu → `ssget "_X"` theo DXF 2 → đếm. Tự loại block ẩn danh (`*U`, `*D`) |
| **Đo chiều dài** | `MTOGEO` | `vlax-curve-getDistAtParam` cho LINE/LWPOLYLINE/POLYLINE/ARC/CIRCLE/SPLINE/ELLIPSE — đúng cả với cung (bulge) |

**Điểm kỹ thuật đáng chú ý — nhận dạng prefix:**
- Ưu tiên **prefix dài nhất**: `MCCB 100A` → `MCCB` (không phải `MCB`)
- Kiểm **ranh giới**: `DBX 100` → **không** khớp `DB`
- Không phân biệt hoa/thường

### 3.2 Đếm tự động + điều chỉnh thủ công

```
FinalCount = AutoCount + ManualCount
NetQty     = FinalCount − Deduction    (clamp ≥ 0)
```

Ba trường được lưu **riêng biệt** (`AUTOQTY`, `MANQTY`, `QTY`) để truy vết được
số nào do máy đếm, số nào do người nhập.

### 3.3 Mô hình dữ liệu

Mỗi dòng kết quả là một **association list 24 khoá**:

| Nhóm | Khoá |
|---|---|
| Định danh | `CATEGORY` `TYPE` `NAME` `SPEC` `DESCRIPTION` `PREFIX` |
| Số liệu | `QTY` `AUTOQTY` `MANQTY` `DEDUCTION` `NETQTY` `LENGTH` `UNIT` |
| Nguồn | `LAYER` `HANDLES` `SOURCETYPE` `SOURCEOBJECT` |
| Phân loại | `FLOOR` `ZONE` `AREA` `NOTES` |
| Tính toán | `FORMULA` `LABEL1..3` |

**Gộp nhóm** theo khoá `CATEGORY|TYPE|NAME|SPEC|UNIT` — cùng nhóm thì cộng số liệu
và **gộp danh sách handle** (để truy vết ngược).

### 3.4 Xuất kết quả

| Kênh | Chi tiết |
|---|---|
| **CSV** (`MTOCSV`) | 15 cột · escape theo RFC4180 (bọc `"`, nhân đôi `"` nội bộ) · tên file `<DWG>_MTO_<ngày>_<giờ>.csv` |
| **AutoCAD Table** (`MTOTABLE`) | 9 cột · STT · subtotal theo Category · grand total · **2 backend** (xem 3.7) |
| **Excel .NET** | `MTOPlugin.Core/Export/ExcelExporter.cs` — 5 sheet (TỔNG HỢP, CHI TIẾT, CHƯA PHÂN LOẠI, CẢNH BÁO LỖI, THÔNG TIN LẦN QUÉT) |

### 3.5 Đối chiếu ngược về bản vẽ

```
Bảng kết quả  →  STT/từ khoá  →  handle  →  ZOOM _O + sssetfirst  →  đối tượng trên bản vẽ
```

Không dùng ActiveX (để chạy được cả ở môi trường không có COM).

### 3.6 Tính toán

| Chức năng | Cách làm |
|---|---|
| **Công thức** | Chỉ chấp nhận `<toán-hạng> <phép-toán> <toán-hạng>` — **không dùng `eval`/`read`** trên chuỗi người dùng (tránh thực thi mã). Biến: `SL`, `QTY`, `NETQTY`, `LEN`, `DED`, `PRICE`. Lưu `FORMULA`, `FORMULA-VALUE`, `FORMULA-EXPLAIN` |
| **Subtotal** | Gom nhóm **generic theo khoá** (CATEGORY/TYPE/LAYER/FLOOR/…) — không hard-code |
| **Deduction** | Có **clamp** `0 ≤ DED ≤ QTY` ⇒ `NETQTY` không bao giờ âm |

### 3.7 Quyết định kỹ thuật: 2 backend cho AutoCAD Table

| Backend | Công nghệ | Môi trường | Kiểm thử tự động |
|---|---|---|---|
| **NATIVE** | `vla-AddTable` (ActiveX) | AutoCAD đầy đủ | ✗ (accoreconsole không có ActiveX) |
| **GRID** | `entmake` TEXT + LINE | mọi nơi | ✓ |

Module **tự dò** ActiveX và chọn backend; nếu NATIVE lỗi thì **tự động fallback** sang GRID.
Cách này đảm bảo luôn có kết quả và vẫn test được logic.

---

## 4. Kiểm thử & bảo đảm chất lượng

### 4.1 Ba cổng bắt buộc

```
[0] LINT      cân bằng ngoặc + string cho MỌI file .lsp
[1] LOAD-CHECK mto-qload phát hiện file không load sạch
[2] TEST      accoreconsole chạy thật, kết quả ghi ra file
```

> **Vì sao cần cổng [0] và [1]?** Đã từng xảy ra lỗi thật: một file LISP có **lỗi cú pháp ở
> cuối file** nhưng test **vẫn PASS**, vì các `defun` phía trước đã được định nghĩa.
> Test PASS **không** chứng minh file nguồn hợp lệ — nên phải có lớp lint/load-check.

### 4.2 Kết quả

| Suite | Test | Nội dung |
|---|---|---|
| test-core | 45 | data model, chuỗi, số, gộp nhóm |
| test-select | 32 | ssget thật, lọc layer/loại |
| test-text | 40 | bóc MTEXT, prefix, ranh giới |
| test-block | 41 | block definition + INSERT thật |
| test-geometry | 31 | đo π·r, 2π·r, đơn vị INSUNITS |
| test-result | 30 | bảng, căn cột, thống kê |
| test-csv | 26 | ghi file thật + đọc lại |
| test-orphan | 27 | tạo rồi xoá entity thật |
| test-loader | 41 | nạp 16 module, 22 lệnh |
| test-table | 38 | vẽ grid thật + đếm entity |
| test-find | 32 | zoom/chọn thật |
| test-update | 34 | sửa TEXT/MTEXT + XData roundtrip |
| test-undo | 28 | sửa rồi khôi phục, đọc lại |
| test-formula | 62 | parse/eval công thức |
| test-subtotal | 33 | group/deduction/clamp |
| test-floor | 43 | wcmatch, gán theo vùng |
| test-config | 34 | file + NOD roundtrip |
| **TỔNG** | **617** | **PASS toàn bộ** |

### 4.3 Môi trường test tự động

| Thành phần | Giá trị |
|---|---|
| Công cụ | `accoreconsole.exe` (AutoCAD Core Console) — chạy headless |
| Phiên bản | AutoCAD 2023 (**R24.2**) |
| Cách chạy | `lisp/tests/run-all-tests.ps1` |

---

## 5. Danh sách module (17)

| # | Module | Dòng | Nhiệm vụ |
|---|---|---|---|
| 1 | `mto-core.lsp` | 284 | Data model + tiện ích |
| 2 | `mto-select.lsp` | 203 | Chọn vùng + lọc |
| 3 | `mto-text.lsp` | 250 | Nhận dạng chữ theo prefix |
| 4 | `mto-block.lsp` | 251 | Đếm block + manual |
| 5 | `mto-geometry.lsp` | 196 | Đo chiều dài |
| 6 | `mto-result.lsp` | 120 | Bảng kết quả |
| 7 | `mto-csv.lsp` | 132 | Xuất CSV |
| 8 | `mto-orphan.lsp` | 130 | Dữ liệu mồ côi |
| 9 | `mto-table.lsp` | 291 | AutoCAD Table |
| 10 | `mto-find.lsp` | 203 | Tìm/zoom ngược |
| 11 | `mto-update.lsp` | 189 | Cập nhật vào bản vẽ |
| 12 | `mto-undo.lsp` | 157 | Snapshot/restore |
| 13 | `mto-formula.lsp` | 222 | Công thức |
| 14 | `mto-subtotal.lsp` | 185 | Subtotal/deduction |
| 15 | `mto-floor.lsp` | 210 | Floor/Zone/Area |
| 16 | `mto-config.lsp` | 223 | Cấu hình theo DWG |
| 17 | `mto-loader.lsp` | 99 | Nạp module + trợ giúp |
| | **Tổng** | **~3.545** | |

---

## 6. Lộ trình đã thực hiện

| Giai đoạn | Nội dung | Trạng thái |
|---|---|---|
| **PHASE 1** | Chọn vùng · Text prefix · Đếm block · Đo chiều dài · Data model · Kết quả · CSV · Orphan | ✅ |
| **PHASE 2** | AutoCAD Table · Zoom back · Batch update · Undo/Restore | ✅ |
| **PHASE 3** | Custom formula · Subtotal · Deduction | ✅ |
| **PHASE 4** | Floor/Zone/Area · Cấu hình theo DWG | ✅ |
| **PHASE 5** | .NET extension (palette, Excel) | ✅ |

---

## 7. Bug thật đã phát hiện & sửa (20)

Đây là bằng chứng giá trị của việc **test trên môi trường thật** — nhiều lỗi chỉ lộ khi chạy:

| Nhóm | Lỗi tiêu biểu |
|---|---|
| **Semantics AutoLISP** | `(strcase s T)` trả **chữ thường** (không phải hoa) · không được đặt biến local tên `t` · `(car alist)` trả **dotted pair** · `(last list)` trả **phần tử cuối** · **không có `let`** · `'(<)` là **list** chứ không phải hàm |
| **DXF / entmake** | MTEXT thiếu subclass → `entmake` trả `nil` · APPID thiếu subclass · giá trị trả về của `entmake` **không dùng được** làm ename |
| **Hành vi AutoCAD** | **`handent` vẫn resolve entity đã `entdel`** → phát hiện orphan phải kiểm thêm `entget` · `ssget "_X"` **không đảm bảo thứ tự** · **`SECURELOAD=1` chặn `load`** ngoài Trusted Paths |
| **Logic / thiết kế** | Hàm mô tả ≠ hàm vẽ · bỏ qua kết quả của hàm immutable · sắp xếp phân biệt hoa/thường |
| **Phương pháp test** | File lỗi cú pháp cuối nhưng test vẫn PASS → **gia cố harness thêm 2 cổng** |
| **Đóng gói (test end-to-end bắt được)** | `mto-loader.lsp` chỉ *định nghĩa* hàm mà **không tự nạp** các module con → cài xong nhưng `MTOBLK` không tồn tại · `findfile` **không resolve đường dẫn tuyệt đối** nên không nạp được file ở `%LOCALAPPDATA%` · `(vl-filename-directory nil)` lỗi `stringp nil` |

---

## 8. Đóng gói phát hành

### 8.1 Bộ cài 1 file

**`output/MTOPro.Setup-1.0.0.exe`** (850 KB) — nhúng sẵn toàn bộ nội dung:

| Thành phần | Số lượng |
|---|---|
| Module LISP | 17 file |
| Bộ quy tắc mẫu | `rules.sample.json` (110 quy tắc) |
| Tài liệu | 2 file (hướng dẫn sử dụng + giới thiệu dự án) |
| DLL .NET (net48) | 6 file |

**Bộ cài tự động làm 6 việc:**
1. Giải nén payload
2. Cài 17 module LISP → `%LOCALAPPDATA%\MTOPro\lisp`
3. Cài bộ quy tắc → `%LOCALAPPDATA%\MTOPro\config\rules.json` (chỉ lần đầu)
4. Cài tài liệu → `%LOCALAPPDATA%\MTOPro\docs`
5. Cài bundle .NET → `%APPDATA%\Autodesk\ApplicationPlugins\MTOPro.2023.bundle` (kèm LISP để plugin tự nạp)
6. Ghi **Startup Suite** của AutoCAD → tự nạp LISP mỗi lần mở AutoCAD

**Cơ chế tự nạp LISP (2 lớp, đề phòng):**
- **Lớp 1 (chính):** plugin .NET khi khởi động → thêm thư mục LISP vào `TRUSTEDPATHS` → gửi lệnh `load mto-loader.lsp` (kèm `*MTO-HOME*`)
- **Lớp 2 (dự phòng):** Startup Suite của AutoCAD trỏ thẳng `mto-loader.lsp`

### 8.2 Chế độ dòng lệnh (cho IT)

```powershell
MTOPro.Setup-1.0.0.exe --check              # kiểm tra, không cài
MTOPro.Setup-1.0.0.exe --install-silent     # cài không giao diện
MTOPro.Setup-1.0.0.exe --uninstall-silent   # gỡ cài
```

### 8.3 Bộ cài đã được kiểm chứng end-to-end

| Bước kiểm tra | Kết quả |
|---|---|
| Build installer từ payload | ✅ 850 KB, nhúng đủ 17 LISP + 6 DLL + 2 docs |
| `--check` | ✅ Báo đúng đường dẫn, phát hiện AutoCAD R24.2 |
| `--install-silent` | ✅ Cài 17 LISP, rules.json, docs, bundle, Startup Suite 1 profile |
| Nạp LISP **từ thư mục đã cài** | ✅ `MTOPro v0.6.0-lisp : da nap 16/16 module` |
| Kiểm tra lệnh sau khi cài | ✅ `CHECK-MTOBLK=YES`, `CHECK-MTOCFG=YES`, `CHECK-LOADED=16/16` |
| NETLOAD DLL từ bundle | ✅ Command .NET `MTOZOOM` phản hồi đúng |

Script kiểm chứng: `scripts/verify-package.ps1`

---

## 8. Giới hạn đã biết (ghi rõ để bàn giao)

| # | Giới hạn | Mức |
|---|---|---|
| 1 | Giao diện palette WPF chưa kiểm chứng trong AutoCAD đầy đủ (chỉ có môi trường headless) | Trung bình |
| 2 | `SECURELOAD=1` mặc định của AutoCAD chặn `load` ngoài Trusted Locations — bộ cài tự thêm, nhưng cần xác nhận trên máy đích | **Cao** |
| 3 | Backend AutoCAD Table gốc (ActiveX) chưa kiểm chứng (đã có chế độ lưới dự phòng) | Trung bình |
| 4 | Chưa xử lý handle trong **Xref** (database riêng) | Trung bình |
| 5 | Chưa hỗ trợ **dynamic block / block lồng** khi quét | Trung bình |
| 6 | Chưa hỗ trợ **AutoCAD 2018–2022** (không có máy kiểm chứng) | Trung bình |
| 7 | CSV chưa có **BOM UTF-8** (Excel có thể lệch dấu tiếng Việt) | Trung bình |
| 8 | Bộ quy tắc 110 mục là **mẫu**, chưa khớp quy ước layer/block thực tế công ty | Trung bình |
| 9 | `mto-db-merge-item` độ phức tạp O(n²) nếu dữ liệu rất lớn | Thấp |
| 10 | Xuất Excel "active cell" (đổ vào ô đang chọn) chưa làm | Thấp |

---

## 9. Hồ sơ kỹ thuật kèm theo

| Tài liệu | Nội dung |
|---|---|
| `docs/HUONG_DAN_SU_DUNG.md` | Hướng dẫn sử dụng cho người dùng cuối |
| `docs/GIOI_THIEU_DU_AN.md` | Tài liệu này |
| `docs/agent-progress/MASTER_STATUS.md` | Trạng thái tổng dự án |
| `docs/agent-progress/TASK_INDEX.md` | Danh mục 18 task |
| `docs/agent-progress/TASK-000..017.md` | Checkpoint chi tiết từng task |
| `docs/agent-progress/FINAL_AUDIT.md` | Audit cuối đối chiếu 19 mục yêu cầu |
| `docs/ARCHITECTURE.md` | Kiến trúc (nhánh .NET) |
| `docs/RULES.md` | Định dạng bộ quy tắc |

---

## 10. Khuyến nghị bước tiếp theo

1. **Test trên bản vẽ thật của công ty** (5 bộ DWG theo kế hoạch khảo sát) và đối chiếu kết quả với cách đếm thủ công.
2. **Phòng Dự án rà soát bộ quy tắc** cho khớp quy ước layer/block thực tế.
3. **Ghi nhận thời gian** đếm thủ công vs dùng công cụ (mục tiêu đề tài: giảm ≥50%).
4. Sau khi ổn định → đóng gói bản phát hành chính thức.
