# UPDATE_TROUBLESHOOTING.md — Xử lý sự cố cập nhật

**Module:** Offline Package + Online Update · **Phiên bản tài liệu:** 1.0

---

## 1. Log ở đâu — đọc trước tiên

| Log | Nội dung |
|---|---|
| `%LOCALAPPDATA%\MTOPro\logs\update.log` | Mọi thao tác cập nhật (LISP + UpdaterApp) |
| `%LOCALAPPDATA%\MTOPro\logs\<ngày>_startup.log` | Plugin nạp, nạp LISP |
| `%LOCALAPPDATA%\MTOPro\logs\<ngày>_mainpanel.log` | Panel quét/phân loại |

**Mẫu dòng log:**
```
2026-09-19 10:15:22 | 1.0.0 | CHECK | local=1.0.0 remote=1.1.0 src=https://***@update.local/mto
2026-09-19 10:15:30 | UPDATER | INSTALL-BEGIN | local=1.0.0 src=...
2026-09-19 10:15:35 | UPDATER | INSTALL-OK | 1.0.0 -> 1.1.0
```

> Log **không bao giờ** chứa mật khẩu/token — URL có credential bị thay bằng `***@`.

---

## 2. Bảng sự cố nhanh

| Hiện tượng | Nguyên nhân thường gặp | Xử lý |
|---|---|---|
| `Chua cau hinh nguon cap nhat` | `update.json` → `updateSource` trống | Điền nguồn (mục 3) |
| `NGUON KHONG HOP LE` | Dùng `http://` (không phải localhost) | Đổi sang **HTTPS** hoặc đường dẫn mạng |
| `Khong lay duoc manifest` | Sai đường dẫn nguồn / không có `manifest.json` | Kiểm tra nguồn có `manifest.json` ở gốc |
| `SHA256 KHONG KHOP` | Tải lỗi / gói hỏng / bị sửa | Tải lại; kiểm tra gói trên nguồn |
| `Payload khong hop le` | Gói thiếu `lisp/` hoặc `version.json` | Publish lại đúng quy trình |
| `ZIP-SLIP chan` | Gói chứa đường dẫn `..` (bất thường) | **Không cài** — báo kỹ thuật |
| `Khong the ghi DLL` / lỗi truy cập | **AutoCAD đang mở** → file bị khoá | Đóng AutoCAD rồi chạy lại |
| Bản mới không có tác dụng | Chưa mở lại AutoCAD | Đóng + mở lại AutoCAD |
| `MTOVERSION` báo sai version | `version.json` lệch với thực tế | Chạy lại cài/rollback |
| `vl-rmdir` / hàm không tồn tại | Dùng hàm không có trong AutoLISP | Báo kỹ thuật (đã gặp, đã sửa) |

---

## 3. `updateSource` không hoạt động

**Kiểm tra 1 — nguồn có manifest chưa?**

```powershell
# Thư mục mạng
dir \\server\share\MTOPro\manifest.json

# HTTPS
curl.exe -I https://update.congty.local/mto/manifest.json
```

Phải thấy `manifest.json`. Nếu không → publish chưa copy lên (xem RELEASE_PROCESS bước 5).

**Kiểm tra 2 — quyền truy cập**

```powershell
dir \\server\share\MTOPro
```
Nếu bị từ chối → cần quyền đọc share (liên hệ IT).

**Kiểm tra 3 — cú pháp JSON**

`manifest.json` phải là **object phẳng, mỗi field 1 dòng**. Kiểm tra nhanh:
```powershell
Get-Content \\server\share\MTOPro\manifest.json | Select-Object -First 4
```

---

## 4. Tải thất bại

### 4.1 Từ thư mục mạng / NAS
```powershell
# Thử copy tay
Copy-Item \\server\share\MTOPro\1.1.0\package.zip $env:TEMP\test.zip
```
Nếu copy tay được mà updater không → kiểm tra log.

### 4.2 Từ HTTPS nội bộ
- Đảm bảo dùng **HTTPS** (HTTP bị từ chối, trừ `localhost`).
- Kiểm tra máy có ra được server không:
  ```powershell
  Test-NetConnection update.congty.local -Port 443
  ```
- Nếu công ty dùng **proxy** → cấu hình proxy cho Windows/IE (UpdaterApp dùng
  `WebClient` theo cấu hình hệ thống).

### 4.3 Tải tay làm phương án dự phòng
```powershell
# Tải tay rồi trỏ updater vào thư mục cục bộ
Invoke-WebRequest https://update.congty.local/mto/1.1.0/package.zip -OutFile D:\MTOPro-Release\1.1.0\package.zip
# (copy cả manifest.json vào cùng)
.\UpdaterApp.exe --install --source D:\MTOPro-Release\1.1.0
```

---

## 5. SHA256 không khớp

**Nguyên nhân có thể:**

| # | Nguyên nhân | Cách xác định |
|---|---|---|
| 1 | Tải về bị cắt (mạng chập) | So `size_bytes` trong manifest với kích thước file thật |
| 2 | Gói trên nguồn bị sửa sau khi publish | Băm lại file trên nguồn, so với manifest |
| 3 | Manifest nguồn là của phiên bản khác | Kiểm tra `version` trong manifest |
| 4 | Tải qua proxy có chèn nội dung | Thử tải qua đường khác |

**Kiểm tra thủ công:**
```powershell
$f = "$env:TEMP\package.zip"
(Get-FileHash $f -Algorithm SHA256).Hash.ToLower()
# So với "sha256" trong manifest.json
```

> ⛔ **KHÔNG cài** khi SHA256 lệch — đây là cơ chế bảo vệ chống gói hỏng/giả mạo.

---

## 6. DLL bị khoá (AutoCAD đang mở)

**Triệu chứng:** updater báo lỗi ghi file DLL, hoặc kích hoạt thất bại.

**Nguyên nhân:** AutoCAD đã nạp `MTOPlugin.dll` → Windows khoá file.

**Xử lý:**
```
1. Đóng HOÀN TOÀN AutoCAD (kiểm tra Task Manager không còn acad.exe)
2. Chạy lại UpdaterApp
```

**Kiểm tra còn AutoCAD không:**
```powershell
Get-Process acad -ErrorAction SilentlyContinue
```
Không có kết quả = đã đóng hết.

> Nếu chỉ cập nhật **LISP** (không có DLL) → không cần đóng AutoCAD: dùng
> `MTOUPGRADE` trong AutoCAD hoặc nạp lại `mto-loader.lsp` sau khi swap.

---

## 7. `update.json` hỏng

**Triệu chứng:** `MTOVERSION` không hiện nguồn/kênh, hoặc hiện giá trị lạ.

**Nguyên nhân:** JSON sai định dạng (viết 1 dòng, lồng object, thiếu dấu phẩy).

**Xử lý:** khôi phục từ file mẫu
```powershell
Copy-Item "$env:LOCALAPPDATA\MTOPro\config\update.sample.json" `
          "$env:LOCALAPPDATA\MTOPro\config\update.json" -Force
```
Rồi sửa lại từ đầu (mục 4 tài liệu INSTALLATION).

**Kiểm tra cú pháp:**
```powershell
Get-Content "$env:LOCALAPPDATA\MTOPro\config\update.json" -Raw | ConvertFrom-Json
```
Không báo lỗi = JSON hợp lệ.

---

## 8. Bản mới không có tác dụng

| Kiểm tra | Lệnh / cách làm |
|---|---|
| Đã mở lại AutoCAD? | Đóng hẳn + mở lại |
| Đúng version chưa? | Gõ `MTOVERSION` |
| LISP có nạp không? | Dòng đầu khi mở AutoCAD: `da nap 19/19 module` |
| `version.json` khớp? | `Get-Content "$env:LOCALAPPDATA\MTOPro\version.json"` |
| LISP trong thư mục đã đổi? | So ngày sửa: `dir "$env:LOCALAPPDATA\MTOPro\lisp"` |

**Nạp lại LISP thủ công:** trong AutoCAD gõ
```
(load (strcat (getenv "LOCALAPPDATA") "/MTOPro/lisp/mto-loader.lsp"))
```

---

## 9. Rollback thất bại

| Hiện tượng | Xử lý |
|---|---|
| `Khong co ban backup nao` | Chưa từng cập nhật → dùng bộ cài cũ (xem ROLLBACK Cách 2) |
| `Khong thay backup: <ver>` | Tên version sai → `--status` xem danh sách thật |
| Lỗi ghi file | AutoCAD đang mở → đóng rồi thử lại |
| Vẫn lỗi | Copy tay (xem ROLLBACK Cách 3) |

---

## 10. Lệnh MTO* không chạy sau cập nhật

**Kiểm tra theo thứ tự:**

1. `MTOHELP` có ra danh sách không?
   - **Có** → lệnh hoạt động, vấn đề ở nơi khác
   - **Không** → LISP chưa nạp

2. Dòng đầu khi mở AutoCAD có `da nap 19/19 module` không?
   - Không thấy dòng đó → Startup Suite chưa ghi → xem INSTALLATION mục 3

3. `SECURELOAD` — kiểm tra Trusted Locations:
   ```
   OPTIONS → Files → Trusted Locations → phải có %LOCALAPPDATA%\MTOPro\lisp
   ```

4. Nạp thủ công:
   ```
   APPLOAD → Browse → %LOCALAPPDATA%\MTOPro\lisp\mto-loader.lsp → Load
   ```

---

## 11. Thu thập thông tin để báo kỹ thuật

Khi báo lỗi, gửi kèm **5 thứ**:

```
1. Nội dung %LOCALAPPDATA%\MTOPro\logs\update.log  (30 dòng cuối)
2. Nội dung %LOCALAPPDATA%\MTOPro\version.json
3. Nội dung %LOCALAPPDATA%\MTOPro\config\update.json
4. Kết quả: UpdaterApp.exe --status
5. Ảnh màn hình thông báo lỗi (nếu có)
```

**Lệnh gom nhanh:**
```powershell
$r = "$env:LOCALAPPDATA\MTOPro"
Get-Content "$r\logs\update.log" -Tail 30
Get-Content "$r\version.json"
Get-Content "$r\config\update.json"
& "$r\tools\UpdaterApp.exe" --status
```

---

## 12. Ghi chú kỹ thuật cho người sửa lỗi

| Điểm | Ghi chú |
|---|---|
| Parser JSON | AutoLISP/C# đọc **object phẳng, mỗi field 1 dòng** — không hỗ trợ lồng/mảng |
| `vl-rmdir` | **KHÔNG tồn tại** trong AutoLISP → dùng `vl-file-delete` (xóa được thư mục rỗng) |
| `vl-filename-directory nil` | Lỗi `bad argument type: stringp nil` → phải kiểm `nil` trước |
| `findfile` | **Không** resolve đường dẫn tuyệt đối → dùng `vl-file-size` để kiểm file |
| `certutil` | Có sẵn mọi Windows: `-urlcache -f` để tải, `-hashfile SHA256` để băm |
| Kích hoạt | Chỉ ghi **app files**: `lisp` `docs` `tools` `dll` `version.json` — **không** `config` |

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — module UPDATE SYSTEM.*
