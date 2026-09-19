# ROLLBACK.md — Quay về bản cũ

**Module:** Offline Package + Online Update · **Phiên bản tài liệu:** 1.0

---

## 1. Khi nào cần rollback

| Tình huống | Mức |
|---|---|
| Bản mới làm AutoCAD lỗi / không nạp được | 🔴 Khẩn |
| Bản mới có lỗi chức năng ảnh hưởng công việc | 🔴 Khẩn |
| Bản mới chạy chậm / khó dùng hơn bản cũ | 🟠 Nên |
| Kích hoạt thất bại giữa chừng | 🔴 Khẩn (updater tự rollback) |
| Muốn thử bản mới nhưng chưa chắc | 🟡 Tùy |

---

## 2. Cơ chế backup của MTOPro

**Trước mỗi lần kích hoạt**, updater **tự động** copy toàn bộ application files
hiện tại vào `backup\<version-đang-chạy>\`.

```
%LOCALAPPDATA%\MTOPro\
├─ lisp\  docs\  tools\  dll\  version.json   ← đang chạy
├─ backup\
│  ├─ 1.0.0\    ← bản cũ (đầy đủ, khôi phục được)
│  ├─ 1.0.1\
│  └─ 1.0.2\    ← giữ TỐI ĐA 3 bản (KEEP_BACKUPS=3)
└─ staging\      ← bản mới đang chờ / đang lỗi
```

**Backup chỉ chứa application files** — ⛔ **KHÔNG** chứa `config\`
(cấu hình người dùng luôn được giữ nguyên qua mọi lần cập nhật/rollback).

> Khi có bản thứ 4, bản **cũ nhất** tự bị xóa.

---

## 3. Ba cách rollback

### Cách 1 — UpdaterApp (khuyến nghị)

**Đóng AutoCAD trước** (DLL bị khoá khi AutoCAD đang mở):

```powershell
cd %LOCALAPPDATA%\MTOPro\tools

# Xem có bản backup nào
.\UpdaterApp.exe --status

# Quay về bản gần nhất (khác bản đang chạy)
.\UpdaterApp.exe --rollback

# Hoặc chỉ định đúng phiên bản
.\UpdaterApp.exe --rollback 1.0.0
```

Kết quả:
```
Rollback ve: 1.0.0
ROLLBACK XONG. Phien ban: 1.0.0
Hay KHOI DONG LAI AutoCAD.
```

→ Mở lại AutoCAD.

### Cách 2 — Chạy bộ cài bản cũ

Nếu còn file `MTOPro.Setup-<version-cu>.exe`:

```
1. Đóng AutoCAD
2. Double-click MTOPro.Setup-1.0.0.exe
3. Mở lại AutoCAD
```

> Bộ cài **không ghi đè** `config\` → cấu hình và bộ quy tắc vẫn giữ nguyên.

### Cách 3 — Copy tay (khi updater không chạy được)

```powershell
$root = "$env:LOCALAPPDATA\MTOPro"

# Đóng AutoCAD TRƯỚC khi làm bước này!
Copy-Item "$root\backup\1.0.0\*" $root -Recurse -Force
```

Sau đó sửa `$root\version.json` cho khớp phiên bản đã khôi phục (nếu cần),
rồi mở lại AutoCAD.

---

## 4. Rollback chỉ LISP (không cần đóng AutoCAD)

Nếu **chỉ** module LISP có vấn đề (DLL không đổi), có thể rollback nóng:

```lisp
;; Trong AutoCAD, gõ:
(command "_.SHELL" "copy /Y \"%LOCALAPPDATA%\\MTOPro\\backup\\1.0.0\\lisp\\*.lsp\" \"%LOCALAPPDATA%\\MTOPro\\lisp\\\"")
(load (strcat (getenv "LOCALAPPDATA") "/MTOPro/lisp/mto-loader.lsp"))
```

Hoặc đơn giản hơn — nạp lại bản cũ bằng lệnh của module cũ nếu có.

> **Hạn chế:** cách này **không** khôi phục được DLL. Nếu bản lỗi liên quan DLL,
> phải dùng Cách 1/2/3 (đóng AutoCAD).

---

## 5. Kiểm tra sau khi rollback

```
1. Mở AutoCAD
2. Gõ:  MTOVERSION     → "Phien ban dang chay" phải là bản cũ
3. Gõ:  MTOHELP        → danh sách lệnh hiện ra
4. Kiểm tra dữ liệu:   config\rules.json còn nguyên (số quy tắc không đổi)
                       DANH_MUC_VAT_TU.xlsx còn nguyên
```

Dòng đầu khi mở AutoCAD phải hiện:
```
MTOPro v<version-cu> : da nap 19/19 module.
```

---

## 6. Rollback tự động (khi kích hoạt lỗi)

Updater tự rollback nếu bước **Activate** thất bại:

```
Kich hoat loi -> ROLLBACK...
Log: INSTALL-ROLLBACK | activate failed
```

Sau đó nó khôi phục từ backup vừa tạo. Kiểm tra `logs\update.log` để xác nhận.

**Nếu tự rollback cũng lỗi** → dùng Cách 3 (copy tay).

---

## 7. Xóa bản backup (giải phóng dung lượng)

Mỗi backup ~500 KB (chỉ LISP) hoặc ~1 MB (có DLL). Không đáng lo.

Nếu muốn xóa bớt:
```powershell
Remove-Item "$env:LOCALAPPDATA\MTOPro\backup\1.0.0" -Recurse -Force
```

> ⚠️ Xóa hết backup = **mất khả năng rollback**. Nên giữ ít nhất 1 bản.

---

## 8. Ghi chú an toàn

| Điều | Cam kết |
|---|---|
| Dữ liệu người dùng (`config\`, DWG, `.mtocfg`, template) | ⛔ **KHÔNG BAO GIỜ** bị chạm trong mọi lần cập nhật/rollback |
| Bản vẽ đang mở | Không bị ảnh hưởng |
| Bộ quy tắc đã tùy chỉnh | Giữ nguyên |
| Số backup tối đa | 3 (tự dọn bản cũ nhất) |

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — module UPDATE SYSTEM.*
