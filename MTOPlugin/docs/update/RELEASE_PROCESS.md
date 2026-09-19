# RELEASE_PROCESS.md — Quy trình phát hành bản mới

**Module:** Offline Package + Online Update · **Phiên bản tài liệu:** 1.0

---

## 1. Tóm tắt 6 bước

```
1. Hoàn tất + test code (3 cổng: LINT → LOAD-CHECK → TEST)
2. Tăng version trong version.json
3. Chạy publish-update.ps1
4. Kiểm tra kết quả (TEST-15 tự chạy 6 điểm)
5. Copy lên nguồn cập nhật (NAS / HTTP nội bộ)
6. Thông báo cho người dùng
```

---

## 2. Chi tiết từng bước

### Bước 1 — Test trước khi phát hành (**bắt buộc**)

```powershell
cd MTOPlugin
powershell -ExecutionPolicy Bypass -File .\lisp\tests\run-all-tests.ps1
```

**Điều kiện phát hành:** `KET LUAN: TAT CA PASS` và LINT `xx file OK`.

> ⛔ **KHÔNG phát hành nếu còn test FAIL.** Test fail = bản mới hỏng.

### Bước 2 — Tăng phiên bản

Sửa **duy nhất** `MTOPlugin\version.json`:

```json
{
  "product": "MTOPro",
  "version": "1.1.0",          ← TĂNG Ở ĐÂY
  "release_date": "2026-10-01",
  "minimum_autocad": "24.0",
  ...
}
```

**Quy tắc tăng version** (semantic versioning):

| Loại thay đổi | Tăng | Ví dụ |
|---|---|---|
| Sửa lỗi | PATCH | `1.0.0` → `1.0.1` |
| Thêm chức năng (tương thích) | MINOR | `1.0.1` → `1.1.0` |
| Thay đổi phá vỡ tương thích | MAJOR | `1.1.0` → `2.0.0` |

> Chỉ sửa 1 file này. Loader, build script, bundle, mto.iss đều đọc từ đây
> (hoặc được script đồng bộ).

### Bước 3 — Đóng gói release

```powershell
cd MTOPlugin
powershell -ExecutionPolicy Bypass -File .\scripts\publish-update.ps1 `
    -Notes "Sua loi bang NATIVE rong; them canh bao don vi"
```

**Tham số:**

| Tham số | Ý nghĩa | Mặc định |
|---|---|---|
| `-Version` | Ghi đè version (không khuyến nghị) | đọc `version.json` |
| `-Notes "..."` | Ghi chú phát hành (1 dòng) | `"Ban phat hanh <ver>"` |
| `-Mandatory` | Bắt buộc cập nhật | `false` (tùy chọn) |
| `-SkipDll` | Chỉ đóng gói LISP, không kèm DLL | kèm DLL nếu có |
| `-MinVersion` | Version tối thiểu để cập nhật | `1.0.0` |

**Kết quả:**

```
release\
├─ manifest.json              ← bản mới nhất (UpdateSource trỏ vào ĐÂY)
└─ 1.1.0\
   ├─ package.zip             ← payload (lisp + docs + tools + dll + version.json)
   └─ manifest.json           ← manifest của riêng phiên bản này
```

### Bước 4 — Kiểm tra kết quả

Script **tự chạy TEST-15** (6 điểm) và in:

```
--- KIEM TRA TINH NHAT QUAN (TEST-15) ---
  sha256 khop      : OK
  version khop     : OK
  package khop     : OK
  file ton tai     : OK
  size khop        : OK
  payload version  : 1.1.0 (manifest=1.1.0)

=== PUBLISH THANH CONG ===
```

**Nếu có dòng `*** SAI ***` hoặc `*** THIEU ***`** → publish chưa hợp lệ, **không phát hành**.

> Điểm kiểm thứ 6 (`payload version`) là quan trọng nhất: nếu `version.json`
> **trong gói** không khớp `manifest.version` thì updater sẽ **từ chối cài**.

### Bước 5 — Đưa lên nguồn cập nhật

Copy **cả cây `release\`** lên nguồn:

| Loại nguồn | Cách làm | `updateSource` |
|---|---|---|
| **Thư mục mạng / NAS** | Copy `release\*` vào `\\server\share\MTOPro\` | `\\server\share\MTOPro` |
| **HTTP nội bộ** | Copy vào web root (vd `https://update.congty.local/mto/`) | `https://update.congty.local/mto` |
| **Thư mục cục bộ** (máy ngoại tuyến) | Copy vào `D:\MTOPro-Release\` | `D:\MTOPro-Release` |

> **Quan trọng:** phải copy **cả** `manifest.json` (bản mới nhất) **và** thư mục
> phiên bản. Updater đọc `manifest.json` ở gốc nguồn, rồi tải `package` theo tên.

### Bước 6 — Thông báo

Gửi cho người dùng: số phiên bản, thay đổi chính, cách cập nhật
(`MTOUPGRADE` trong AutoCAD, hoặc chạy `UpdaterApp.exe --install --source ...`).

---

## 3. Checklist phát hành

- [ ] Tất cả test PASS (`run-all-tests.ps1`)
- [ ] LINT không lỗi
- [ ] `version.json` đã tăng version đúng loại
- [ ] `publish-update.ps1` báo **PUBLISH THANH CONG**
- [ ] TEST-15: 6/6 OK (đặc biệt `payload version` khớp)
- [ ] Đã copy **cả** `manifest.json` + thư mục phiên bản lên nguồn
- [ ] Thử `UpdaterApp.exe --check --source <nguồn>` từ 1 máy → báo **CO BAN MOI**
- [ ] Đã thông báo người dùng

---

## 4. Đóng gói OFFLINE (máy không có mạng)

Với máy ngoại tuyến, dùng **bộ cài 1 file**:

```powershell
cd MTOPlugin
powershell -ExecutionPolicy Bypass -File .\scripts\build-lisp-installer.ps1
```

→ `output\MTOPro.Setup-<version>.exe` (1 file, ~1.1 MB)

Copy file này vào USB, sang máy ngoại tuyến, double-click để cài.
Người dùng không cần mạng.

> Bộ cài **đã nhúng sẵn** `UpdaterApp.exe` trong `tools/` → sau khi cài,
> máy đó có thể cập nhật từ nguồn nội bộ (nếu có).

---

## 5. Xử lý sự cố khi phát hành

| Hiện tượng | Nguyên nhân | Xử lý |
|---|---|---|
| `sha256 khop: *** SAI ***` | File zip đổi sau khi băm | Chạy lại publish (đừng sửa tay file zip) |
| `payload version: *** SAI ***` | `version.json` trong gói ≠ version phát hành | Đã sửa ở TASK-024; nếu vẫn lỗi, báo lỗi kỹ thuật |
| `Khong doc duoc version tu version.json` | File JSON hỏng | Kiểm tra cú pháp: object phẳng, mỗi field 1 dòng |
| Test FAIL trước phát hành | Code lỗi | Sửa code, **không** phát hành |

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — module UPDATE SYSTEM.*
