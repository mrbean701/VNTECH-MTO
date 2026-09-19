# INSTALLATION.md — Cài đặt MTOPro

**Module:** Offline Package + Online Update · **Phiên bản tài liệu:** 1.0

---

## 1. Yêu cầu hệ thống

| Thành phần | Yêu cầu |
|---|---|
| AutoCAD | **2023** (ACADVER 24.2) — đã kiểm chứng |
| Windows | 10 / 11 (64-bit) |
| Quyền | **Không cần Admin** (cài cho người dùng hiện tại) |
| .NET Framework | 4.8 (có sẵn trên Windows 10/11) |
| Khác | Không cần .NET SDK · không cần Excel · không cần Python |

---

## 2. Cài đặt lần đầu (1 file EXE)

### 2.1 Các bước

```
1. Đóng AutoCAD (nếu đang mở)
2. Double-click:  MTOPro.Setup-<version>.exe
3. Làm theo hướng dẫn trên màn hình
4. Mở lại AutoCAD
5. Gõ:  MTOHELP   → kiểm tra danh sách lệnh
```

### 2.2 Bộ cài tự động làm gì

| # | Việc | Vị trí |
|---|---|---|
| 1 | Cài module LISP | `%LOCALAPPDATA%\MTOPro\lisp\` |
| 2 | Cài bộ quy tắc mẫu | `%LOCALAPPDATA%\MTOPro\config\rules.json` (chỉ lần đầu) |
| 3 | Cài template danh mục vật tư | `%LOCALAPPDATA%\MTOPro\config\DANH_MUC_VAT_TU.xlsx` (chỉ lần đầu) |
| 4 | Cài cấu hình cập nhật | `config\update.sample.json` + **seed `update.json`** (chỉ lần đầu) |
| 5 | Cài tài liệu | `%LOCALAPPDATA%\MTOPro\docs\` |
| 6 | Cài công cụ | `%LOCALAPPDATA%\MTOPro\tools\` (gồm **UpdaterApp.exe**) |
| 7 | Cài `version.json` | `%LOCALAPPDATA%\MTOPro\version.json` |
| 8 | Cài bundle .NET | `%APPDATA%\Autodesk\ApplicationPlugins\MTOPro.2023.bundle\` |
| 9 | Ghi **Startup Suite** | Registry AutoCAD → tự nạp LISP mỗi lần mở |

### 2.3 Cấu trúc sau khi cài

```
%LOCALAPPDATA%\MTOPro\
├─ lisp\                  19 module LISP
├─ docs\                  tài liệu
├─ tools\                 UpdaterApp.exe + script import
├─ dll\                   (nếu có) DLL .NET net48
├─ config\                ⛔ USER DATA — bộ cài KHÔNG ghi đè
│  ├─ rules.json
│  ├─ update.json         ← cấu hình cập nhật (sửa file này)
│  ├─ update.sample.json  ← file mẫu (đừng sửa)
│  └─ DANH_MUC_VAT_TU.xlsx
├─ version.json           phiên bản đang chạy
├─ logs\                  update.log + log phiên
├─ staging\               (chỉ khi có bản chờ kích hoạt)
└─ backup\                bản cũ (giữ tối đa 3)
```

---

## 3. ⚠️ SECURELOAD — bắt buộc xử lý

AutoCAD mặc định `SECURELOAD=1` → **chặn** `(load ...)` với file ngoài
**Trusted Locations**. Triệu chứng: `File load canceled`.

Bộ cài đã tự thêm thư mục LISP vào Trusted Locations, nhưng **kiểm tra lại**:

```
AutoCAD → gõ OPTIONS → tab Files → Trusted Locations
→ phải có dòng:  %LOCALAPPDATA%\MTOPro\lisp
```

**Nếu thiếu** (hoặc lệnh MTO* không chạy):

```
Cách 1: OPTIONS → Files → Trusted Locations → Add → chọn thư mục lisp
Cách 2: gõ APPLOAD → Browse → chọn mto-loader.lsp → Load
        (để tự nạp mọi lần: APPLOAD → Startup Suite → Contents → Add)
```

> ⛔ **KHÔNG** đặt `SECURELOAD=0` — giảm bảo mật. Hãy dùng Trusted Locations.

---

## 4. Cấu hình cập nhật (`config\update.json`)

Mở `%LOCALAPPDATA%\MTOPro\config\update.json`, sửa:

```json
{
  "enabled": "true",                            ← bật kiểm tra cập nhật
  "channel": "stable",
  "checkOnStartup": "false",                    ← giữ false để không chậm AutoCAD
  "checkIntervalHours": "24",
  "updateSource": "https://raw.githubusercontent.com/mrbean701/VNTECH-MTO/main/MTOPlugin/release",
  "keepBackups": "3"
}
```

| Khoá | Ý nghĩa | Nên đặt |
|---|---|---|
| `enabled` | Có kiểm tra cập nhật không | `"true"` khi đã có nguồn |
| `channel` | Kênh phát hành | `"stable"` |
| `checkOnStartup` | Kiểm tra khi mở AutoCAD | `"false"` (khuyên dùng) |
| `checkIntervalHours` | Giãn cách kiểm tra (giờ) | `"24"` |
| `updateSource` | Nguồn: `\\server\share`, `https://...`, hoặc thư mục | nguồn nội bộ của công ty |
| `keepBackups` | Số bản backup giữ lại | `"3"` |

> ⚠️ File phải là **object phẳng, mỗi field 1 dòng** (AutoLISP không có JSON parser).
> Đừng viết 1 dòng hay lồng object.

**Kiểm tra cấu hình:** trong AutoCAD gõ `MTOVERSION` → hiện nguồn + kênh + trạng thái.

---

## 5. Cập nhật lên bản mới

### Cách 1 — Trong AutoCAD (khuyến nghị)

```
MTOUPGRADECHECK     ← kiểm tra có bản mới không (không tải)
MTOUPGRADE          ← Enter để cập nhật · ROLLBACK · STATUS
```

AutoLISP **không có HTTP/SHA256** → lệnh sẽ chỉ ra cách chạy updater.

### Cách 2 — Chạy UpdaterApp (đầy đủ chức năng)

**Đóng AutoCAD trước** (vì DLL bị khoá khi AutoCAD mở):

```powershell
cd %LOCALAPPDATA%\MTOPro\tools

.\UpdaterApp.exe --status                             # xem bản + backup
.\UpdaterApp.exe --check  --source \\server\share\MTOPro   # kiểm tra
.\UpdaterApp.exe --install --source \\server\share\MTOPro  # cài
.\UpdaterApp.exe --rollback                           # quay về bản cũ
```

Sau khi xong → **mở lại AutoCAD**.

---

## 6. Build lại từ source (dành cho kỹ thuật)

Repo **không chứa file `.exe`** (bị `.gitignore`). Sau khi clone, build lại:

```powershell
cd MTOPlugin

# 1. Build công cụ cập nhật (cần: chỉ cần Windows, csc.exe có sẵn)
powershell -ExecutionPolicy Bypass -File .\scripts\build-updater.ps1

# 2. (Tuỳ chọn) Build DLL .NET cho AutoCAD 2023
dotnet build src\MTOPlugin\MTOPlugin.csproj -f net48 `
    /p:AcadDirectory="D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023" /p:MtoNet8=false

# 3. Đóng gói bộ cài (tự gọi build-updater)
powershell -ExecutionPolicy Bypass -File .\scripts\build-lisp-installer.ps1
```

> `build-lisp-installer.ps1` **tự build** UpdaterApp trước khi đóng gói → thường
> chỉ cần chạy bước 3.

---

## 7. Gỡ cài đặt

```powershell
cd output
.\MTOPro.Setup-<version>.exe --uninstall-silent
```

Hoặc thủ công:
1. Xóa `%LOCALAPPDATA%\MTOPro`
2. Xóa `%APPDATA%\Autodesk\ApplicationPlugins\MTOPro.2023.bundle`
3. Trong AutoCAD: `APPLOAD` → Startup Suite → Remove dòng `mto-loader.lsp`

---

## 8. Kiểm tra cài đặt thành công

Trong AutoCAD gõ lần lượt:

| Lệnh | Kết quả mong đợi |
|---|---|
| `MTOHELP` | Danh sách 27 lệnh MTO* |
| `MTOVERSION` | Phiên bản + nguồn + kênh + backup |
| `MTOLIST` | (cần có dữ liệu trước) |

Dòng đầu khi mở AutoCAD phải hiện:
```
MTOPro v1.0.0 : da nap 19/19 module.
Da bat hien thi ten lenh tren thanh trang thai (go MTOTITLE de tat).
```

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — module UPDATE SYSTEM.*
