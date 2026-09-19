# DEV ONBOARDING — Hướng dẫn cho lập trình viên mới

**Dự án:** MTOPro (VNTECH-MTO) · **Phiên bản:** 1.0.0 · **Cập nhật:** 19/09/2026
**Đọc trước:** `docs/MO_TA_HE_THONG.md` (hiểu hệ thống) → rồi quay lại file này.

---

## 1. Ba điều phải hiểu TRƯỚC KHI viết dòng code đầu tiên

### 1.1 Triết lý: LISP-first

```
LISP-first  →  LISP + AutoCAD Table  →  .NET chỉ khi thật cần
```

**Ưu tiên khi phân vân chọn giải pháp:**
```
Độ tin cậy → Độ chính xác → Đơn giản → Dễ bảo trì → Mở rộng
```

⛔ **KHÔNG chuyển logic nhận dạng/đếm/tính sang .NET "cho tiện".**
Lý do: logic LISP chạy được trên mọi bản AutoCAD, test được headless,
không phải build lại khi đổi bản AutoCAD. .NET API **đổi giữa các bản** (xem B20 bên dưới).

### 1.2 Yêu cầu chất lượng: 3 cổng bắt buộc

**Không bao giờ báo "xong" khi chưa qua đủ 3 cổng:**

| Cổng | Lệnh | Đạt khi |
|---|---|---|
| ① LINT | `check-lisp-syntax.ps1` | `xx file OK` |
| ② LOAD-CHECK | `run-tests.ps1` (nạp qua `mto-qload`) | không có file load lỗi |
| ③ TEST | `run-all-tests.ps1` | `700/700 PASS` |

> **Bài học thật (B16):** từng có file LISP **lỗi cú pháp ở dòng cuối** nhưng test
> vẫn PASS (vì harness cũ không lint). Từ đó mới thêm cổng ① và ②.
> **Đừng tin test nếu chưa lint.**

### 1.3 Không giả PASS

- Test phải **assert giá trị thật**, không chỉ đếm số.
- Test không chạy được → ghi **BLOCKED + lý do**, không đánh dấu PASS.
- Bug phát hiện phải ghi vào `FINAL_AUDIT.md` (đang có **28 bug B1–B28**).

---

## 2. Cấu trúc repository

```
quantity take-off/                    ← workspace root (git repo)
├─ AGENTS.md                          ← GOAL của workspace (đọc đầu phiên)
├─ UPGRADE_MASTER_GOAL.md             ← GOAL module update
├─ UPGRADE_MASTER_PROMPT_OPTIMIZED.md ← prompt triển khai chi tiết
├─ .gitignore
└─ MTOPlugin/                         ← DỰ ÁN
   ├─ version.json                    ⭐ NGUỒN PHIÊN BẢN DUY NHẤT
   ├─ SPEC.md                         đặc tả gốc (~700 dòng)
   ├─ README.md  QUICKSTART.md
   │
   ├─ lisp/                           ⭐ LÕI — 18 module + loader
   │  ├─ mto-ui.lsp        (nạp đầu)  banner, tiến trình, DIESEL
   │  ├─ mto-core.lsp                 tiện ích nền, data model
   │  ├─ mto-select.lsp               chọn đối tượng
   │  ├─ mto-text.lsp                 nhận dạng tiền tố text
   │  ├─ mto-block.lsp                đếm block
   │  ├─ mto-geometry.lsp             đo hình học + đơn vị
   │  ├─ mto-result.lsp               danh sách kết quả
   │  ├─ mto-csv.lsp                  xuất CSV
   │  ├─ mto-orphan.lsp               phát hiện mồ côi
   │  ├─ mto-table.lsp                bảng khối lượng
   │  ├─ mto-find.lsp                 tìm & zoom
   │  ├─ mto-update.lsp               cập nhật hàng loạt
   │  ├─ mto-undo.lsp                 snapshot/khôi phục
   │  ├─ mto-formula.lsp              công thức
   │  ├─ mto-subtotal.lsp             tổng phụ/khấu trừ
   │  ├─ mto-floor.lsp                tầng/khu vực
   │  ├─ mto-config.lsp               cấu hình theo bản vẽ
   │  ├─ mto-selfup.lsp               cập nhật tự động
   │  ├─ mto-loader.lsp               ⭐ BỘ NẠP (đọc version + nạp module)
   │  └─ tests/                       18 test + harness
   │     ├─ framework.lsp             assert helpers
   │     ├─ run-tests.ps1             chạy 1 suite
   │     ├─ run-all-tests.ps1         chạy tất cả
   │     ├─ check-lisp-syntax.ps1     LINT
   │     └─ test-*.lsp                18 file test
   │
   ├─ src/                            .NET (net48) — UI, KHÔNG chứa logic
   │  ├─ MTOPlugin/                   host, commands, scanner
   │  ├─ MTOPlugin.Core/              model, rule matcher, phân loại (thuần, testable)
   │  ├─ MTOPlugin.UI/                panel WPF, Rule Editor
   │  └─ MTOPlugin.Logging/
   │
   ├─ config/                         ⛔ USER DATA — không ghi đè
   │  ├─ rules.sample.json            bộ mẫu (110 quy tắc / 11 hệ)
   │  ├─ rules.json                   bộ thật (sinh từ Excel)
   │  ├─ DANH_MUC_VAT_TU.xlsx         template cho kỹ sư
   │  └─ update.sample.json           cấu hình cập nhật mẫu
   │
   ├─ scripts/                        18 script vận hành (PowerShell)
   ├─ installer/                      bộ cài (SetupApp + updater + bundles)
   ├─ release/                        ⭐ NGUỒN CẬP NHẬT (push lên GitHub)
   │  ├─ manifest.json
   │  └─ 1.0.0/{package.zip, manifest.json}
   ├─ docs/                           20 tài liệu (+ update/ + agent-progress/)
   ├─ tests/                          project test .NET (NUnit)
   └─ output/                         build artifact (gitignored)
```

---

## 3. Môi trường phát triển

### 3.1 Cần gì

| Thành phần | Ghi chú |
|---|---|
| **AutoCAD 2023** | Bắt buộc (để test headless qua `accoreconsole.exe`) |
| Windows 10/11 64-bit | |
| PowerShell 5.1 | Có sẵn |
| `csc.exe` | Có sẵn tại `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe` |
| .NET SDK 8 | **Chỉ khi** build nhánh .NET (không cần cho LISP) |
| Git | |
| **KHÔNG cần:** Python, Node, Java, Visual Studio | |

### 3.2 Clone và bước ĐẦU TIÊN

```powershell
git clone https://github.com/mrbean701/VNTECH-MTO.git
cd "quantity take-off\MTOPlugin"

# ⚠️ BẮT BUỘC: build lại UpdaterApp.exe (repo không chứa .exe)
powershell -ExecutionPolicy Bypass -File .\scripts\build-updater.ps1
```

### 3.3 Đường dẫn accoreconsole

```powershell
D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe
```

> Trên máy khác, sửa `$acad` trong `lisp/tests/run-tests.ps1`.

---

## 4. Chạy test

### 4.1 Toàn bộ (dùng hằng ngày)

```powershell
cd MTOPlugin
powershell -ExecutionPolicy Bypass -File .\lisp\tests\run-all-tests.ps1
```
→ Mong đợi: `TONG: 700/700 test PASSED` · `KET LUAN: TAT CA PASS`

### 4.2 Một suite

```powershell
powershell -ExecutionPolicy Bypass -File .\lisp\tests\run-tests.ps1 -TestFile test-selfup.lsp
```

### 4.3 LINT riêng

```powershell
powershell -ExecutionPolicy Bypass -File .\lisp\tests\check-lisp-syntax.ps1
```

> ⚠️ **Luôn dùng `-ExecutionPolicy Bypass`** — policy mặc định chặn script.

---

## 5. Quy ước code (BẮT BUỘC)

### 5.1 Ngôn ngữ

| Loại | Quy ước |
|---|---|
| **Code + comment LISP** | Tiếng Việt **KHÔNG DẤU** (tránh lỗi encoding) |
| **Tài liệu `.md` / `.docx`** | Tiếng Việt **có dấu** |
| **Script `.ps1`** | Tiếng Việt không dấu; **phải lưu UTF-8 BOM** nếu có tiếng Việt |
| **Commit message** | ASCII, mô tả task + kết quả test |

### 5.2 Đặt tên

| Đối tượng | Quy ước | Ví dụ |
|---|---|---|
| Lệnh người dùng | `c:MTO*` (chữ HOA) | `(defun c:MTOBLK ...)` |
| Hàm nội bộ | `mto-<module>-<việc>` | `mto-tbl-add-native` |
| Biến toàn cục | `*MTO-<TÊN>*` | `*MTO-DATA*`, `*MTO-HOME*` |
| File module | `mto-<tên>.lsp` | `mto-geometry.lsp` |
| File test | `test-<tên>.lsp` | `test-geometry.lsp` |

### 5.3 ⛔ KHÔNG đặt biến local tên `t`

```lisp
;; ❌ SAI - loi "incorrect object to bind: T"
(defun f (lst / t) (foreach t lst ...))

;; ✅ DUNG
(defun f (lst / item) (foreach item lst ...))
```

`t` là hằng số `T` (true) trong AutoLISP — không dùng làm tên biến.

### 5.4 Data model

Dùng **association list phẳng** (xem `MO_TA_HE_THONG.md` §4.1), không tự phát minh
cấu trúc mới. Mọi module đọc/ghi qua hàm của `mto-core.lsp`.

---

## 6. AutoLISP gotchas — 9 điều đã kiểm chứng bằng thực nghiệm

> Đây là **kiến thức trả giá bằng bug thật**. Đọc kỹ, đừng tự thử lại.

| # | Điều | Chi tiết |
|---|---|---|
| 1 | `(strcase s)` = **HOA**; `(strcase s T)` = **thường** | Tham số 2 là `downcase-p`, không phải "upper" |
| 2 | ⛔ **Không đặt biến local tên `t`** | Lỗi `incorrect object to bind: T` |
| 3 | `(car alist)` trả **DOTTED PAIR**, không phải khoá | Dùng `(car (car alist))` / `caar` |
| 4 | Giá trị `entmake` **không** dùng được làm ename | Dùng `(entlast)` |
| 5 | `handent` **vẫn resolve** entity đã `entdel` | Kiểm thêm `(entget (handent h))` = nil |
| 6 | `"\n"` trong AutoLISP sinh **CR+LF (2 ký tự)** | `vl-string-translate` sẽ thay 2 lần |
| 7 | `ssget "_X"` **không đảm bảo thứ tự** | Đừng giả định thứ tự = thứ tự tạo |
| 8 | `entmake` MTEXT cần đủ **DXF subclass** | `(100 . "AcDbEntity")` + `(100 . "AcDbMText")` |
| 9 | AutoCAD `SECURELOAD=1` **chặn `load`** ngoài TrustedPaths | Test phải `(setvar "SECURELOAD" 0)` |

### 6.1 Gotcha bổ sung (phát hiện ở module update)

| # | Điều | Chi tiết |
|---|---|---|
| 10 | ⛔ **AutoLISP KHÔNG có `let`** | Kiểm chứng thực nghiệm; dùng `(defun f ( / a b) ...)` |
| 11 | ⛔ **`vl-rmdir` KHÔNG tồn tại** | Dùng `vl-file-delete` (xóa được thư mục rỗng) |
| 12 | `findfile` **không** resolve đường dẫn tuyệt đối | Dùng `vl-file-size` + `*MTO-HOME*` |
| 13 | `(vl-filename-directory nil)` lỗi | `bad argument type: stringp nil` — kiểm nil trước |
| 14 | `(vl-sort l '<)` — dùng `'<` không `'(<)` | |
| 15 | ⛔ **Không có JSON parser** | Đọc object **phẳng, mỗi field 1 dòng** |
| 16 | Không có HTTP, không có SHA256 | Dùng `certutil.exe` qua `startapp` |

---

## 7. Việc thường làm

### 7.1 Thêm một module mới

```powershell
# 1. Tạo file  lisp\mto-<ten>.lsp  theo khuôn:
```

```lisp
;;; ============================================================
;;; mto-<ten>.lsp -- <mo ta ngan>
;;; ============================================================

;; ... cac ham noi bo: mto-<ten>-<viec>

(defun c:MTO<LENH> ( / ...)
  (mto-ui-start "MTO<LENH>" "<mo ta>")
  ;; ... cong viec ...
  (mto-ui-end "MTO<LENH>"))

(princ "\nmto-<ten>.lsp loaded.")
(princ)
```

```powershell
# 2. Them vao *MTO-MODULES* trong lisp\mto-loader.lsp (DUNG THU TU phu thuoc!)
# 3. Cap nhat so module trong lisp\tests\test-loader.lsp
# 4. Tao lisp\tests\test-<ten>.lsp
# 5. Them suite vao run-all-tests.ps1
# 6. Chay 3 cong
```

⚠️ **Thứ tự trong `*MTO-MODULES*` quan trọng:** module dùng hàm của module khác
phải nạp SAU. `mto-ui.lsp` nạp đầu (mọi module gọi `mto-ui-start`),
`mto-core.lsp` nạp thứ 2.

### 7.2 Thêm một lệnh vào module có sẵn

```lisp
(defun c:MTOLENHMOI ( / ...)
  (mto-ui-start "MTOLENHMOI" "...")
  ...
  (mto-ui-end "MTOLENHMOI"))
```

**Trước khi thêm lệnh mới — BẮT BUỘC grep kiểm tra trùng:**
```powershell
Select-String -Path .\lisp\*.lsp -Pattern '\(defun c:MTOLENHMOI'
```
Nếu đã có → chọn tên khác.
*(Thực tế đã gặp: `MTOUPDATE` bị chiếm bởi module cập nhật hàng loạt → module
update phải dùng `MTOUPGRADE`.)*

### 7.3 Thêm test

```lisp
;; Trong lisp\tests\test-<ten>.lsp
(defun mto-run-tests (out-path / ...)
  (mto-test-reset)
  (mto-assert-true "ten-test: mo ta" <bieu thuc>)
  (mto-assert-equal "ten-test: gia tri" <mong doi> <thuc te>)
  (mto-write-results out-path)
  (princ))
```

Harness gọi `(mto-run-tests *MTO-RESULT-PATH*)` — tên hàm **cố định**.

### 7.4 Debug — cách đúng

❌ **Console `accoreconsole` xuất UTF-16LE** → khó parse trực tiếp.

✅ **Cách đúng:** LISP ghi kết quả ra FILE, PowerShell đọc file.

```lisp
(setq f (open "C:/temp/debug.txt" "w"))
(write-line (strcat "GIA TRI = " (vl-princ-to-string ket-qua)) f)
(close f)
```

Xem ví dụ thật trong `lisp/tests/survey.lsp`, `fieldtest.lsp`.

⚠️ **Trong script `.scr`**: ghi file bằng `[IO.File]::WriteAllLines` (không dùng
`Set-Content` với chuỗi ghép — dễ sinh `\n` literal làm hỏng đường dẫn).

---

## 8. Quy trình Git

### 8.1 Hai nhánh (chiến lược đã chốt)

| Nhánh | Vai trò |
|---|---|
| **`unity`** | **DEV** — làm việc hằng ngày |
| **`main`** | **RELEASE** — máy user tải về |

### 8.2 Làm việc hằng ngày

```powershell
git checkout unity
# ... sua code ...
powershell -ExecutionPolicy Bypass -File .\lisp\tests\run-all-tests.ps1   # PHAI PASS
git add -A
git commit -m "Mo ta ngan: viec da lam (700/700 PASS)"
git push origin unity
```

### 8.3 Phát hành (khi cần đẩy cho user)

```powershell
# 1. Tang version trong version.json
# 2. Dong goi
powershell -ExecutionPolicy Bypass -File .\scripts\publish-update.ps1 -Notes "..."
# 3. Push dev
git add -A; git commit -m "Release 1.1.0"; git push origin unity
# 4. Dong bo sang release
git checkout main
git merge unity
git push origin main
git checkout unity
```

Chi tiết: `docs/update/RELEASE_PROCESS.md`.

> ⚠️ Mạng tới `github.com` **hay chập** (`Could not resolve host` tạm thời)
> → push lỗi thì chờ vài giây, thử lại.

---

## 9. Nhánh .NET — lưu ý sống còn

### 9.1 B20 — bài học lớn nhất

`MtoCompat.cs` từng viết **NGƯỢC**: giả định "net48 = API cũ" → **SAI**.

**Thực tế: AutoCAD 2023 dùng API GIỐNG AutoCAD 2025:**

| API | Thực tế trên 2023 |
|---|---|
| `Extents3d` | ở `DatabaseServices` |
| `GetCenter` / `IsValid` / `EffectiveName` | **KHÔNG có** |
| `ViewTableRecord` | ở `DatabaseServices` |
| `Handle` | `long` |
| `GetDynamicBlockProperties` | **không có** → dùng `DynamicBlockReferencePropertyCollection` |
| `PaletteSet` | cần `Guid` |

**Giải pháp:** dùng **CHUNG một implementation** cho cả net48 và net8, **bỏ `#if` ngược**.

### 9.2 Build nhánh .NET

```powershell
dotnet build src\MTOPlugin\MTOPlugin.csproj -f net48 `
    /p:AcadDirectory="D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023" /p:MtoNet8=false
```

### 9.3 WPF pitfalls đã gặp

| Vấn đề | Nguyên nhân | Cách sửa |
|---|---|---|
| **Crash `Access Violation`** khi mở Rule Editor | `SelectionChanged` fires trong `InitializeComponent()` → control còn `null` | Dùng cờ `_uiReady` + null guard |
| Panel **nền đen, chữ đen không đọc được** | `UserControl` không có `Background` | Đặt màu tường minh cho mọi control |
| `Window.GetWindow(panel)` trả **NULL** | Panel nằm trong PaletteSet | Owner phải null-safe |

### 9.4 Giao thức build DLL cho bản AutoCAD khác

DLL build cho **net48 + AutoCAD 2023**. Máy dùng bản khác → phải build lại
với `AcadDirectory` trỏ đúng thư mục AutoCAD đó.

---

## 10. Quy tắc bất di bất dịch

| # | Quy tắc |
|---|---|
| 1 | **KHÔNG BAO GIỜ** để updater ghi vào `config\` (user data) |
| 2 | **KHÔNG BAO GIỜ** xóa/ghi đè DWG, `.mtocfg`, template |
| 3 | **KHÔNG** đặt `SECURELOAD=0` trên máy người dùng (dùng Trusted Location) |
| 4 | **KHÔNG** báo "xong" khi chưa qua 3 cổng test |
| 5 | **KHÔNG** sửa/xóa nhánh .NET hiện có khi làm việc với LISP |
| 6 | `version.json` là **nguồn phiên bản duy nhất** — đừng hard-code version ở nơi khác |
| 7 | Tài liệu LISP: tiếng Việt **không dấu**; `.md`: **có dấu** |
| 8 | Mọi bug phát hiện phải ghi vào `FINAL_AUDIT.md` |

---

## 11. Bản đồ tài liệu kỹ thuật

| Cần | Đọc |
|---|---|
| Hiểu hệ thống | `docs/MO_TA_HE_THONG.md` |
| Đặc tả gốc | `SPEC.md` |
| Kiến trúc | `docs/ARCHITECTURE.md` |
| Build | `docs/BUILD.md` |
| Test | `docs/TESTING.md` |
| Quy tắc | `docs/RULES.md` |
| Kiến trúc update | `docs/update/UPDATE_ARCHITECTURE.md` |
| Phát hành | `docs/update/RELEASE_PROCESS.md` |
| Sự cố AutoLISP | `docs/update/UPDATE_TROUBLESHOOTING.md` §12 |
| Lịch sử bug | `docs/agent-progress/FINAL_AUDIT.md` |
| Trạng thái hiện tại | `docs/agent-progress/MASTER_STATUS.md` |

---

## 12. Ngày đầu tiên — checklist

```
☐ Đọc docs/MO_TA_HE_THONG.md
☐ Clone repo + chạy build-updater.ps1
☐ Chạy check-lisp-syntax.ps1        → 44 file OK
☐ Chạy run-all-tests.ps1            → 700/700 PASS
☐ Mở AutoCAD, gõ MTOHELP            → thấy 27 lệnh
☐ Gõ MTOVERSION                     → thấy 1.0.0
☐ Đọc 1 module LISP đơn giản (mto-orphan.lsp)
☐ Đọc 1 test file (test-orphan.lsp)
☐ Thêm 1 test nhỏ vào suite có sẵn → chạy lại thấy PASS
☐ Đọc FINAL_AUDIT.md mục bug B1-B28
```

Xong 10 mục này → bạn đã sẵn sàng nhận task.

---

## 13. Khi gặp bế tắc

| Tình huống | Làm gì |
|---|---|
| Test PASS nhưng nghi ngờ | **Đừng tin** — kiểm giá trị thật, thêm assert |
| LISP lỗi cú pháp | Chạy LINT trước; đếm ngoặc bằng script |
| Hàm không tồn tại | Kiểm `vl-*` — nhiều hàm tưởng có mà không có (xem §6.1) |
| Không parse được console | Ghi ra file rồi đọc (`§7.4`) |
| DLL không nạp | Kiểm `AcadDirectory` + `MtoNet8` đúng chưa |
| Push lỗi DNS | Chờ vài giây, thử lại |
| Không rõ quyết định cũ | Đọc `MASTER_STATUS.md §3` (quyết định kiến trúc đã chốt) |

**Nguyên tắc gỡ lỗi:** in **giá trị thật** ra file rồi so sánh, đừng đoán.
*(Ví dụ thật: hàm đọc manifest trả `nil` — in ra thấy `JSONGET=[1.1.0]` nhưng
`JSONREAD=[nil]` → khoanh vùng đúng 1 hàm lỗi trong 30 giây.)*

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — VNTECH.*
