# TÀI LIỆU BÀN GIAO — Dự án MTOPro

**Đề tài:** R&D-CAD-QTO-01 — Bóc tách khối lượng M&E trên AutoCAD
**Phiên bản bàn giao:** 1.0.0 · **Ngày:** 19/09/2026
**Đơn vị thực hiện:** VNTECH · **Người nhận:** _(điền khi bàn giao)_

---

## 1. Tóm tắt bàn giao

| Hạng mục | Nội dung |
|---|---|
| **Sản phẩm** | MTOPro — bộ công cụ bóc tách khối lượng cho hệ Điện / Nước / Điện nhẹ (ELV) |
| **Nền tảng** | AutoCAD 2023 (xác thực), Windows 10/11 64-bit |
| **Kiến trúc** | LISP-first (18 module AutoLISP) + .NET UI (net48) |
| **Hình thức giao** | **1 file cài duy nhất** `MTOPro.Setup-1.0.0.exe` (~1.1 MB) |
| **Trạng thái** | ✅ 19/19 mục MASTER GOAL core · ✅ 10/10 task module UPDATE |
| **Chất lượng** | **700/700 test PASS** · LINT 44/44 file OK |

---

## 2. Phạm vi bàn giao

### 2.1 Trong phạm vi

| # | Nội dung |
|---|---|
| 1 | Bộ công cụ bóc tách khối lượng (27 lệnh) cho 3 hệ: Điện, Nước, Điện nhẹ/ELV |
| 2 | Nhận dạng tự động: văn bản theo tiền tố, block, hình học |
| 3 | Tính khối lượng: đếm, đo chiều dài/diện tích, công thức tùy chỉnh |
| 4 | Xuất kết quả: bảng trong DWG, CSV/Excel |
| 5 | Công cụ kiểm tra chất lượng: mồ côi, truy vết, kiểm tra chéo |
| 6 | Giao diện .NET: panel quét, Rule Editor, xuất Excel |
| 7 | Nhập danh mục vật tư từ Excel → bộ quy tắc |
| 8 | Cấu hình theo bản vẽ (file `.mtocfg` + NOD trong DWG) |
| 9 | **Hệ thống cập nhật tự động** (nguồn GitHub, SHA256, backup, rollback) |
| 10 | Bộ tài liệu (20 file) + bộ test (18 file, 700 test) |

### 2.2 Ngoài phạm vi (không bàn giao)

| # | Nội dung | Ghi chú |
|---|---|---|
| 1 | Bản quyền thương mại / licensing | Chưa triển khai theo yêu cầu |
| 2 | Server quản lý tập trung / license server | Không cần — mỗi máy cài độc lập |
| 3 | Bộ quy tắc thật của công ty | ⚠️ **Công ty tự nhập** từ `DANH_MUC_VAT_TU.xlsx` |
| 4 | Hỗ trợ AutoCAD 2018–2022 | Chỉ **xác thực trên 2023**; các bản khác cần build lại DLL |
| 5 | Dynamic block nâng cao (EffectiveName), block lồng | Đã ghi nhận là hạn chế |
| 6 | Báo cáo PDF/HTML | Chỉ CSV/Excel + bảng DWG |
| 7 | So sánh chênh lệch giữa 2 lần bóc tách | Chưa có |

---

## 3. Danh mục thành phần bàn giao

### 3.1 Phần mềm

| # | Thành phần | Vị trí | Ghi chú |
|---|---|---|---|
| 1 | **Bộ cài 1 file** | `MTOPlugin/output/MTOPro.Setup-1.0.0.exe` | Giao cho người dùng cuối |
| 2 | Module AutoLISP (18) | `MTOPlugin/lisp/*.lsp` | Mã nguồn |
| 3 | Bộ nạp | `MTOPlugin/lisp/mto-loader.lsp` | Tự nạp module + đọc version |
| 4 | Module cập nhật | `MTOPlugin/lisp/mto-selfup.lsp` | Logic cập nhật |
| 5 | Công cụ updater | `MTOPlugin/installer/updater/UpdaterApp.cs` | C# — **phải build lại** (xem §3.4) |
| 6 | Nhánh .NET | `MTOPlugin/src/MTOPlugin*` | 4 project |
| 7 | Bộ quy tắc mẫu | `MTOPlugin/config/rules.sample.json` | 110 quy tắc / 11 hệ thống |
| 8 | Template vật tư | `MTOPlugin/config/DANH_MUC_VAT_TU.xlsx` | Kỹ sư điền vào đây |
| 9 | Cấu hình cập nhật | `MTOPlugin/config/update.sample.json` | Nguồn GitHub điền sẵn |

### 3.2 Script vận hành (18 script)

| Nhóm | Script |
|---|---|
| **Build** | `build-lisp-installer.ps1` · `build-updater.ps1` · `build-installer.ps1` · `build.ps1` |
| **Test** | `run-tests.ps1` · `run-field-test.ps1` · `check-lisp-syntax.ps1` · `test-panel-render.ps1` |
| **Nghiệp vụ** | `import-materials.ps1` · `create-material-template.ps1` · `export-excel.ps1` |
| **Phát hành** | `publish-update.ps1` · `verify-package.ps1` |
| **Khác** | `deploy-bundle.ps1` · `check-docx.ps1` · `create-word-guide.ps1` |

### 3.3 Tài liệu (20 file)

**Dành cho người dùng cuối:**
- `docs/HUONG_DAN_NGUOI_MOI.md` — lộ trình 30 phút đầu
- `docs/HUONG_DAN_SU_DUNG.md` — hướng dẫn đầy đủ
- `docs/HUONG_DAN_DO_CAP_VA_IN_BANG.md` — đo cáp & in bảng
- `docs/HUONG_DAN_NHAP_DANH_MUC_VAT_TU.md` — nhập danh mục vật tư
- `docs/GIAI_THICH_RULE_EDITOR.md` — dùng giao diện Rule Editor

**Dành cho kỹ thuật:**
- `docs/MO_TA_HE_THONG.md` — mô tả hệ thống
- `docs/BAN_GIAO.md` — file này
- `docs/DEV_ONBOARDING.md` — onboarding dev mới
- `docs/update/*` (6 file) — kiến trúc, phát hành, cài đặt, rollback, sự cố, test
- `docs/ARCHITECTURE.md` · `BUILD.md` · `INSTALL.md` · `TESTING.md` · `RULES.md` · `CHECKLIST.md`

**Lịch sử dự án:**
- `docs/agent-progress/MASTER_STATUS.md` — nguồn sự thật trạng thái
- `docs/agent-progress/TASK-INDEX.md` + `TASK-000..027.md`
- `docs/agent-progress/FINAL_AUDIT.md` — đối chiếu MASTER GOAL

### 3.4 ⚠️ Lưu ý quan trọng khi nhận source

**Repo KHÔNG chứa file `.exe`** (đã `.gitignore`). Sau khi clone, **bắt buộc build lại**:

```powershell
cd MTOPlugin
powershell -ExecutionPolicy Bypass -File .\scripts\build-updater.ps1
```

Không có bước này → `UpdaterApp.exe` không tồn tại → tính năng cập nhật không chạy.

---

## 4. Checklist nghiệm thu

### 4.1 Kiểm tra cài đặt

| # | Kiểm tra | Cách làm | Tiêu chí đạt | ☐ |
|---|---|---|---|---|
| 1 | Bộ cài chạy | Double-click `MTOPro.Setup-1.0.0.exe` | Cài xong, không lỗi | ☐ |
| 2 | LISP nạp đúng | Mở AutoCAD | Thấy `da nap 18/18 module` | ☐ |
| 3 | Lệnh hoạt động | Gõ `MTOHELP` | Hiện bảng 27 lệnh | ☐ |
| 4 | Version đúng | Gõ `MTOVERSION` | Hiện `1.0.0` + nguồn GitHub | ☐ |
| 5 | Cấu trúc file | Kiểm tra `%LOCALAPPDATA%\MTOPro\` | Đủ `lisp\` `config\` `docs\` `tools\` | ☐ |
| 6 | Template có sẵn | Kiểm tra `config\DANH_MUC_VAT_TU.xlsx` | File tồn tại, mở được | ☐ |

### 4.2 Kiểm tra nghiệp vụ (bóc tách thật)

| # | Kiểm tra | Cách làm | Tiêu chí đạt | ☐ |
|---|---|---|---|---|
| 7 | Chọn đối tượng | `MTOSEL` → `All` | Báo số đối tượng > 0 | ☐ |
| 8 | Nhận dạng text | `MTOTEXT` | Báo nhận dạng được | ☐ |
| 9 | Đếm block | `MTOBLK` | Báo số block đếm được | ☐ |
| 10 | Xem kết quả | `MTOLIST` | Bảng 6 cột có dữ liệu | ☐ |
| 11 | **Kiểm tra mồ côi** | `MTOORPHAN` | Chạy không lỗi, có danh sách/báo trống | ☐ |
| 12 | **Truy vết** | `MTOFIND` → chọn mã | AutoCAD zoom tới đối tượng | ☐ |
| 13 | Xuất CSV | `MTOCSV` | File CSV mở được bằng Excel, 15 cột | ☐ |
| 14 | Bảng trong DWG | `MTOTABLE` | Bảng 9 cột hiện trong bản vẽ | ☐ |
| 15 | Lưu cấu hình | `MTOCFG` | Lưu được, mở lại còn | ☐ |

### 4.3 Kiểm tra giao diện .NET

| # | Kiểm tra | Cách làm | Tiêu chí đạt | ☐ |
|---|---|---|---|---|
| 16 | Panel mở được | Gõ `MTO` | Panel hiện, nền trắng, chữ đen đọc được | ☐ |
| 17 | Rule Editor | Mở từ panel | Không crash; sửa/xem quy tắc được | ☐ |
| 18 | Xuất Excel | Từ panel | File `.xlsx` mở được | ☐ |

### 4.4 Kiểm tra cập nhật

| # | Kiểm tra | Cách làm | Tiêu chí đạt | ☐ |
|---|---|---|---|---|
| 19 | Kiểm tra bản mới | `MTOUPGRADECHECK` | Báo rõ có/không có bản mới | ☐ |
| 20 | Updater chạy | `%LOCALAPPDATA%\MTOPro\tools\UpdaterApp.exe --status` | Hiện phiên bản `1.0.0` | ☐ |
| 21 | Đọc nguồn GitHub | `UpdaterApp.exe --check --source <nguồn>` | Báo `DA LA BAN MOI NHAT` | ☐ |

### 4.5 Kiểm tra chất lượng mã

| # | Kiểm tra | Cách làm | Tiêu chí đạt | ☐ |
|---|---|---|---|---|
| 22 | LINT | `check-lisp-syntax.ps1` | `44 file OK` | ☐ |
| 23 | Test suite | `run-all-tests.ps1` | `700/700 PASS`, `TAT CA PASS` | ☐ |

> **Điều kiện nghiệm thu:** tất cả 23 mục ☑.
> Mục nào không đạt → ghi vào biên bản, không tự ý bỏ qua.

---

## 5. Môi trường & hạ tầng

| Thành phần | Giá trị |
|---|---|
| AutoCAD | 2023, `ACADVER 24.2` (đã xác thực) |
| .NET Framework | 4.8 |
| Thư mục cài | `%LOCALAPPDATA%\MTOPro\` |
| Bundle .NET | `%APPDATA%\Autodesk\ApplicationPlugins\MTOPro.2023.bundle\` |
| Quyền cần | **Không cần Admin** |
| Yêu cầu mạng | **Chỉ khi cập nhật** (bóc tách chạy offline hoàn toàn) |

### Nguồn cập nhật

```
https://raw.githubusercontent.com/mrbean701/VNTECH-MTO/main/MTOPlugin/release
```

| Thuộc tính | Giá trị |
|---|---|
| Repo | `https://github.com/mrbean701/VNTECH-MTO` (**public**) |
| Nhánh `main` | **RELEASE** — máy user tải về |
| Nhánh `unity` | **DEV** — phát triển |
| Xác thực | Không cần token (repo public) |
| Giao thức | **HTTPS bắt buộc** (TLS 1.2+) |

### Phân quyền đề xuất khi tiếp nhận

| Vai trò | Quyền cần |
|---|---|
| Người dùng cuối | Cài đặt trên máy cá nhân (không cần admin) |
| Kỹ thuật viên | Quyền ghi thư mục `%LOCALAPPDATA%\MTOPro` |
| Quản trị quy tắc | Sửa `DANH_MUC_VAT_TU.xlsx` → chạy `import-materials.ps1` |
| Quản trị phát hành | Quyền push repo GitHub + chạy `publish-update.ps1` |

---

## 6. Hướng dẫn tiếp nhận (cho bên nhận)

### Bước 1 — Nhận source
```powershell
git clone https://github.com/mrbean701/VNTECH-MTO.git
cd VNTECH-MTO
git checkout main        # bản RELEASE
```

### Bước 2 — Build lại công cụ
```powershell
cd MTOPlugin
powershell -ExecutionPolicy Bypass -File .\scripts\build-updater.ps1
```

### Bước 3 — Chạy test xác nhận
```powershell
powershell -ExecutionPolicy Bypass -File .\lisp\tests\check-lisp-syntax.ps1
powershell -ExecutionPolicy Bypass -File .\lisp\tests\run-all-tests.ps1
```
→ Mong đợi: `44 file OK` và `700/700 test PASSED`.

### Bước 4 — Đóng gói bộ cài
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-lisp-installer.ps1
```
→ `output\MTOPro.Setup-1.0.0.exe`

### Bước 5 — Cài thử + chạy checklist mục 4

### Bước 6 — Nạp bộ quy tắc thật của công ty
```powershell
# 1. Kỹ sư điền config\DANH_MUC_VAT_TU.xlsx
# 2. Chuyển thành rules.json
powershell -ExecutionPolicy Bypass -File .\scripts\import-materials.ps1
```

---

## 7. Hỗ trợ & bảo hành

| Hạng mục | Nội dung |
|---|---|
| Tài liệu sự cố | `docs/update/UPDATE_TROUBLESHOOTING.md` (12 mục) |
| Log để chẩn đoán | `%LOCALAPPDATA%\MTOPro\logs\` (3 loại log) |
| Thông tin cần gửi khi báo lỗi | 5 thứ — xem mục 11 tài liệu sự cố |
| Rollback | `UpdaterApp.exe --rollback` hoặc `docs/update/ROLLBACK.md` |
| Khôi phục bản vẽ | `MTOUNDO` / `MTOSNAPSHOW` |

---

## 8. Rủi ro & lưu ý khi vận hành

| # | Rủi ro | Mức | Giảm thiểu |
|---|---|---|---|
| 1 | Bộ quy tắc chưa đủ → bỏ sót vật tư | 🔴 Cao | **Luôn chạy `MTOORPHAN`** trước khi xuất báo cáo |
| 2 | Bản vẽ khai sai đơn vị (`INSUNITS`) | 🟠 TB | Hệ thống tự cảnh báo; kiểm tra `MTOGEO` |
| 3 | Người dùng nâng cấp AutoCAD khác bản | 🟠 TB | Cần build lại DLL net48 cho đúng bản |
| 4 | `SECURELOAD` chặn nạp LISP | 🟠 TB | Thêm Trusted Location (đã hướng dẫn) |
| 5 | Máy đã cài bản cũ có updater TLS 1.0 | 🟠 TB | **Cài lại bộ cài mới 1 lần** |
| 6 | Mất mạng khi cập nhật | 🟡 Thấp | Có rollback; bóc tách vẫn chạy offline |
| 7 | Kỹ sư sửa JSON sai định dạng | 🟡 Thấp | Định dạng bắt buộc: object phẳng, 1 field/dòng |

---

## 9. Hạn chế đã biết (không tô hồng)

| # | Hạn chế |
|---|---|
| L1 | Chưa hỗ trợ đầy đủ dynamic block (`EffectiveName`) và block lồng |
| L2 | Chỉ xác thực trên AutoCAD 2023; 2018–2022 chưa kiểm thử |
| L3 | Chưa có báo cáo PDF/HTML (chỉ CSV/Excel/bảng DWG) |
| L4 | Chưa có so sánh chênh lệch giữa 2 lần bóc tách |
| L5 | Module update: `--install` chưa chạy thật end-to-end (chỉ `--check`/`--status`) |
| L6 | Module update: chưa test nguồn HTTPS nội bộ thật (mới test GitHub + local) |
| L7 | `UpdaterApp.exe` không nằm trong repo → phải build lại sau khi clone |

---

## 10. Cam kết chất lượng

| Cam kết | Bằng chứng |
|---|---|
| Không có test giả | **700/700 test PASS** chạy thật trên `accoreconsole.exe` |
| Lỗi được sửa có ghi vết | **28 bug thật** (B1–B28) ghi trong `FINAL_AUDIT.md` |
| Dữ liệu người dùng được bảo vệ | `config\`, DWG, template **không bao giờ** bị cập nhật ghi đè |
| Có đường lùi | Rollback 1 lệnh, giữ 3 bản backup |
| Mọi hạn chế được ghi rõ | Mục 2.2 · 9 · và trong `FINAL_AUDIT.md` |

---

## 11. Biên bản bàn giao

| Nội dung | Bên giao | Bên nhận |
|---|---|---|
| Họ tên | | |
| Chức vụ | | |
| Ngày | | |
| Chữ ký | | |

**Xác nhận:** đã nhận đủ thành phần tại mục 3, đã chạy checklist mục 4 đạt
_____/23 mục. Các mục không đạt ghi rõ: _______________________

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — VNTECH.*
