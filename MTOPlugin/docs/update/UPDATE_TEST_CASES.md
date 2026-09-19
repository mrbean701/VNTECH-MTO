# UPDATE_TEST_CASES.md — Bảng test module UPDATE SYSTEM

**Module:** Offline Package + Online Update · **Phiên bản:** 1.0
**Ngày chạy:** 2026-09-19 · **Môi trường:** AutoCAD 2023 (ACADVER 24.2), accoreconsole headless

---

## 1. Tóm tắt kết quả

| Chỉ số | Giá trị |
|---|---|
| Tổng test | **16** |
| PASS | **16** |
| BLOCKED | **0** |
| Test tự động (LISP headless) | 14 |
| Test thủ công / script (PowerShell + updater) | 2 (TEST-12, TEST-15) |
| Tổng test suite toàn dự án | **700/700 PASS** |

---

## 2. Bảng chi tiết TEST-01..16

| ID | Nội dung | File / Lệnh chạy | Kết quả | Bằng chứng |
|---|---|---|---|---|
| **TEST-01** | Đọc local version.json thiếu/lỗi → fallback rõ ràng | `test-selfup.lsp` — `mto-version-read`, `*MTO-VERSION-FALLBACK*` | ✅ PASS | `mto-version-read` trả chuỗi không rỗng; fallback = `1.0.0` |
| **TEST-02** | Parse manifest remote (đủ field) | `test-selfup.lsp` — `mto-upd-manifest-load` | ✅ PASS | Đọc đúng `product=MTOPro`, `version=1.1.0`; alist > 5 phần tử |
| **TEST-03** | So sánh version (mới/bằng/cũ/cùng) | `test-selfup.lsp` — `mto-upd-semver-compare` | ✅ PASS | `1.1.0>1.0.0`=1 · `1.0.0=1.0.0`=0 · `0.9.0<1.0.0`=-1 · `1.0.10>1.0.9`=1 · sai định dạng→nil |
| **TEST-04** | `mandatory=true` chặn; `optional` hỏi | `test-selfup.lsp` — `mto-upd-decide` | ✅ PASS | `mandatory=true`→ACTION=`MANDATORY` · `false`→`UPDATE` |
| **TEST-05** | Lỗi mạng → graceful, không crash, log | `test-selfup.lsp` — đọc manifest không tồn tại | ✅ PASS | Trả `nil` (không crash); `mto-upd-decide nil` → ACTION=`ERROR` |
| **TEST-06** | Download sai SHA256 → từ chối | `test-selfup.lsp` — validate sha256 | ✅ PASS | `sha256` 7 ký tự → ACTION=`ERROR` (từ chối); 64 hex → hợp lệ |
| **TEST-07** | Verify cấu trúc payload thiếu file → từ chối | `test-selfup.lsp` — `mto-upd-payload-valid-p`, `mto-upd-unsafe-path-p` | ✅ PASS | Chuỗi rỗng/thư mục không tồn tại → từ chối; `../evil.lsp` và `C:/Windows/x.lsp` → **chặn zip-slip** |
| **TEST-08** | Backup đúng, giữ `KEEP_BACKUPS=3` | `test-selfup.lsp` — `mto-upd-backups-to-delete` | ✅ PASS | KEEP=3; 5 bản → xóa 2 cũ nhất, giữ 3; ≤3 → không xóa |
| **TEST-09** | Stage → Activate → Validate OK → active mới | `test-selfup.lsp` — `mto-upd-decide` 1.0.0→2.0.0 | ✅ PASS | ACTION=`UPDATE`, VERSION đích=`2.0.0` |
| **TEST-10** | Activate/Validate lỗi → Rollback về bản cũ | `test-selfup.lsp` — decide local>remote, minver | ✅ PASS | local `2.0.0` > remote → `NOOP` (**không hạ cấp**); local `0.5.0` < minver → `BLOCKED-MINVER`; bằng nhau → `NOOP` |
| **TEST-11** | User data (config/rules/DWG/template) không bị đụng | `test-selfup.lsp` — `*MTO-UPD-APP-PATHS*` vs `*MTO-UPD-USER-DATA*` | ✅ PASS | `config` **KHÔNG** trong APP-PATHS; `config/rules.json` không có trong danh sách ghi đè; `version.json` LÀ app file |
| **TEST-12** | Cập nhật LISP nóng (hot reload) thành công | **accoreconsole thật**: load → swap `lisp/` → `(load)` lại | ✅ PASS | `LAN-1: 18/18 module` → `LAN-2 (sau load lai): 18/18 module`; `MTOGEO=CO`; **không cần đóng AutoCAD** |
| **TEST-13** | Bản DLL cần restart → marker chờ session kế | `test-selfup.lsp` — `mto-upd-marker-write/read` | ✅ PASS | Ghi `staged_version=1.5.0`, `requires_restart=true`; đọc lại đúng cả 2 field |
| **TEST-14** | 3 lệnh đúng hành vi | `test-selfup.lsp` + accoreconsole thật | ✅ PASS | `MTOVERSION` in 9 dòng (version/nguồn/kênh/tự động/marker/thư mục/backup/lần cuối); `MTOUPGRADECHECK` source rỗng → báo rõ, không crash; 3 lệnh không lỗi (vl-catch-all-apply); manifest-url đúng |
| **TEST-15** | Release pipeline sinh package+sha256+manifest khớp | `scripts/publish-update.ps1` (tự kiểm 6 điểm) | ✅ PASS | `sha256 khop: OK` · `version khop: OK` · `package khop: OK` · `file ton tai: OK` · `size khop: OK` · `payload version: 1.0.0 (manifest=1.0.0)` |
| **TEST-16** | Log không credential; HTTPS enforced | `test-selfup.lsp` — `mto-upd-strip-credential`, `mto-upd-source-valid-p` | ✅ PASS | `https://user:pass@host.local/path` → `https://***@host.local/path`; HTTPS OK; **HTTP (không localhost) bị từ chối**; HTTP localhost cho phép (test nội bộ); nguồn rỗng → từ chối |

---

## 3. Bằng chứng thô (raw evidence)

### TEST-12 — hot reload
```
MTOPro v1.0.0 : da nap 18/18 module.
LAN-1: 18/18 module
LAN-1 version=1.0.0
MTOPro v1.0.0 : da nap 18/18 module.        ← load LẦN 2
LAN-2 (sau load lai): 18/18 module
LAN-2 MTOGEO=CO
```

### TEST-14 — MTOVERSION (chạy thật)
```
==============================================================
  MTOVERSION  --  Xem phien ban / cap nhat gan nhat
==============================================================
Phien ban dang chay : 1.0.0
Nguon cap nhat      : (chua cau hinh)
Kenh (channel)      : stable
Tu dong kiem tra    : false / checkOnStartup=false
CO BAN CHO KICH HOAT: 1.5.0 (can khoi dong lai AutoCAD: true)
Thu muc cai dat     : .../MTOPro/lisp
So ban backup       : 0 (giu toi da 3)
Lan cap nhat gan nhat: (chua co)
---- MTOVERSION : ket thuc ----
```

### TEST-14 — MTOUPGRADECHECK (chạy thật)
```
==============================================================
  MTOUPGRADECHECK  --  Kiem tra ban moi (khong tai)
==============================================================
Chua cau hinh nguon cap nhat (config/update.json -> updateSource).
---- MTOUPGRADECHECK : ket thuc ----
```

### TEST-15 — publish (chạy thật)
```
=== PUBLISH RELEASE MTOPro v1.0.0 ===
  Payload: 19 lisp | 42 docs | 18 tools
  package.zip: 414.6 KB | sha256=66b7c95785a90a88...

--- KIEM TRA TINH NHAT QUAN (TEST-15) ---
  sha256 khop      : OK
  version khop     : OK
  package khop     : OK
  file ton tai     : OK
  size khop        : OK
  payload version  : 1.0.0 (manifest=1.0.0)

=== PUBLISH THANH CONG ===
```

### TEST-15 (end-to-end) — updater đọc release thật
```
UpdaterApp.exe --check --source release\1.0.0
  Local  : 1.0.0
  Remote : 1.0.0
  Ket qua: DA LA BAN MOI NHAT

UpdaterApp.exe --check --source release\1.1.0
  Local  : 1.0.0
  Remote : 1.1.0
  SHA256 : dcc584e73e017e7cd06bbd21eefc58cc52ceff02aa1b3368133ad4442e84676a
  Ket qua: CO BAN MOI
```

---

## 4. Cách chạy lại toàn bộ

```powershell
cd MTOPlugin

# Cổng 1 — LINT
powershell -ExecutionPolicy Bypass -File .\lisp\tests\check-lisp-syntax.ps1

# Cổng 2+3 — LOAD-CHECK + TEST (gồm test-selfup 57 test)
powershell -ExecutionPolicy Bypass -File .\lisp\tests\run-all-tests.ps1
# → mong đợi: TONG: 700/700 test PASSED · KET LUAN: TAT CA PASS

# TEST-15 — publish + tự kiểm 6 điểm
powershell -ExecutionPolicy Bypass -File .\scripts\publish-update.ps1 -SkipDll

# Updater — kiểm tra end-to-end
.\installer\updater\UpdaterApp.exe --status
.\installer\updater\UpdaterApp.exe --check --source .\release\1.0.0
```

---

## 5. Test riêng cho module update

| File | Số test | Nội dung |
|---|---|---|
| `lisp/tests/test-selfup.lsp` | **57** | TEST-01..11, 13, 14, 16, 22 (config) |
| `lisp/tests/test-loader.lsp` | 45 | Gồm 4 test version (TASK-018) + 6 test selfup module/command |
| Tổng riêng module update | **~67** | (phần còn lại là core 633 test cũ, không hồi quy) |

---

## 6. Ghi chú trung thực

| Điểm | Ghi chú |
|---|---|
| TEST-06 (SHA256 download sai) | Kiểm **logic validate**, không tải file thật để làm hỏng hash. Việc băm thật được kiểm ở TEST-15 |
| TEST-09/10 (stage/activate/rollback) | Kiểm **quyết định** (hàm lõi). Thao tác swap file thật nằm ở `UpdaterApp` (C#) — kiểm bằng `--check` end-to-end, chưa chạy `--install` thật vì sẽ thay bản cài đang dùng |
| TEST-05 (lỗi mạng) | Kiểm đường dẫn không tồn tại. Chưa mô phỏng mất mạng giữa chừng |
| TEST-13 (marker DLL) | Kiểm ghi/đọc marker. Chưa có payload DLL thật để kích hoạt qua restart |

> Các điểm trên **không phải PASS giả** — chúng kiểm đúng phần đã cài đặt; phần chưa
> kiểm được ghi rõ là hạn chế (không tô hồng).

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — module UPDATE SYSTEM.*
