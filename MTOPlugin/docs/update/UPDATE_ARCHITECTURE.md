# UPDATE_ARCHITECTURE.md — Kiến trúc hệ thống cập nhật MTOPro

**Module:** Offline Package + Centralized Online Update
**Phiên bản tài liệu:** 1.0 — 18/09/2026
**Trạng thái:** CHỐT (các quyết định dưới đây không hỏi lại)

---

## 1. Mục tiêu & phạm vi

### 1.1 Mục tiêu

| # | Mục tiêu |
|---|---|
| 1 | **Offline Package**: mọi phiên bản đóng gói được thành 1 file EXE tự cài cho máy ngoại tuyến |
| 2 | **Online Update**: máy đã cài tự kiểm tra bản mới → tải → xác minh SHA256 → backup → kích hoạt an toàn |
| 3 | **User data bất khả xâm phạm**: không bao giờ ghi đè/xoá dữ liệu người dùng |
| 4 | **Rollback 1 lệnh** khi kích hoạt lỗi |
| 5 | **Không chặn AutoCAD**: check/tải chạy nền, lỗi mạng không làm crash |

### 1.2 Phạm vi — CHỈ THÊM, KHÔNG SỬA

**Được thêm:**
- `version.json` (nguồn phiên bản duy nhất)
- `lisp/mto-selfup.lsp` + `lisp/tests/test-selfup.lsp`
- `installer/updater/` (bootstrap updater)
- `config/update.sample.json`
- `release/` (manifest + package)
- `scripts/publish-update.ps1`
- `docs/update/*` (5 tài liệu)
- 3 lệnh mới: `MTOUPGRADECHECK` · `MTOUPGRADE` · `MTOVERSION`

**KHÔNG được đụng:**
- 17 module LISP nghiệp vụ hiện có (chỉ sửa `mto-loader.lsp` để thêm 1 module + đọc version)
- Toàn bộ nhánh `.NET` (`src/**`)
- 633 test LISP hiện có (phải vẫn PASS — không hồi quy)

### 1.3 Baseline xác nhận khi bắt đầu

| Hạng mục | Giá trị thật |
|---|---|
| Test LISP | **633 PASS** (prompt ghi 617 — số cũ) |
| Module LISP | 18 (17 nghiệp vụ + `mto-ui.lsp`) |
| Lệnh hiện có | 24 (+ `MTOZOOM` ở nhánh .NET) |
| Thư mục cài | `%LOCALAPPDATA%\MTOPro\` |
| AutoCAD xác thực | 2023, ACADVER **24.2**, net48 |

---

## 2. Quyết định kiến trúc đã chốt

### QĐ-1 — Một nguồn phiên bản duy nhất: `version.json`

**Hiện trạng lệch (phải gộp):**

| Nơi | Giá trị hiện tại |
|---|---|
| `lisp/mto-loader.lsp` → `*MTO-VERSION*` | `"0.6.0-lisp"` |
| `scripts/build-lisp-installer.ps1` → `-Version` | `1.0.0` |
| `installer/mto.iss` → `AppVersion` | `0.1.0` |
| `installer/bundles/*/PackageContents.xml` → `AppVersion` | `0.1.0` |

**Quyết định:** tạo `MTOPlugin/version.json` là **nguồn sự thật**. Định dạng:

```json
{
  "product": "MTOPro",
  "version": "1.0.0",
  "release_date": "2026-09-18",
  "minimum_autocad": "24.0",
  "autocad_series": "R24.0-R24.9",
  "channel": "stable"
}
```

**Cách đọc:**
- **LISP**: đọc bằng hàm thuần (`mto-selfup-read-version-json`) — **không có JSON parser trong AutoLISP**, nên dùng **parser dòng đơn giản** (tìm `"version"` rồi lấy chuỗi giữa 2 dấu `"`). Đây là lý do `version.json` phải giữ **định dạng 1 field/dòng**.
- **PowerShell** (`build-lisp-installer.ps1`, `publish-update.ps1`): `ConvertFrom-Json`.
- **Installer EXE**: đọc file text, cùng parser dòng đơn giản (C#).
- **Bundle .NET**: `PackageContents.xml` sinh từ script, không sửa tay.

> ⚠️ **Ràng buộc kỹ thuật:** `version.json` KHÔNG được nén 1 dòng, KHÔNG có field lồng nhau.
> Phải là object phẳng, mỗi field 1 dòng — để parser LISP/C# đọc được.

### QĐ-2 — Download + SHA256: dùng `certutil.exe`

**Ràng buộc:** *AutoLISP thuần KHÔNG có HTTP và KHÔNG có SHA256.*

**Phương án đã cân nhắc:**

| Phương án | Ưu | Nhược | Chọn |
|---|---|---|---|
| `certutil.exe` (`-urlcache -f -split` tải, `-hashfile SHA256` băm) | Có sẵn mọi Windows, không cần cài | Không hỗ trợ auth header | ✅ **Chính** |
| .NET helper (WebClient) | Linh hoạt, hỗ trợ HTTPS/auth | Cần build thêm DLL, phức tạp | Dự phòng |
| PowerShell `Invoke-WebRequest` | Mạnh | Bị ExecutionPolicy chặn ở nhiều máy | ❌ |
| Bootstrap EXE tự tải | Kiểm soát hoàn toàn | Nặng hơn | ✅ Cho swap |

**Quyết định:**
- **Tải file**: `certutil -urlcache -f -split <url> <dest>` (fallback: bootstrap EXE dùng `HttpClient`).
- **Băm SHA256**: `certutil -hashfile <file> SHA256` → parse output.
- **Gọi từ LISP**: `(startapp "certutil" "...")` — `startapp` có sẵn trong AutoLISP, chạy **không đồng bộ**.
- **Nguồn cục bộ** (folder/NAS/`file://`): **không cần certutil** — copy file trực tiếp bằng `vl-file-copy`, băm bằng `certutil -hashfile` (vẫn cần cho verify).

### QĐ-3 — Kích hoạt nguyên tử phải tôn trọng khóa DLL

**Hiện trạng:** `.NET` plugin (`MTOPlugin.dll`) nằm trong bundle và **đã được nạp vào AutoCAD** khi phiên chạy → **file DLL bị khoá**, không thể ghi đè khi AutoCAD đang mở.

**Quyết định — 2 kịch bản kích hoạt:**

| Payload chứa | Cách kích hoạt | Cần restart AutoCAD? |
|---|---|---|
| **Chỉ LISP** (`.lsp`) | Swap thư mục `lisp/` → gọi `(load "mto-loader.lsp")` | ❌ **Không** — hot reload |
| **Có DLL** (`.dll`) | Ghi **marker** `pending-activation.json` → bootstrap EXE swap khi AutoCAD đã đóng | ✅ **Có** |

**Marker** `%LOCALAPPDATA%\MTOPro\staging\pending-activation.json`:
```json
{
  "staged_version": "1.1.0",
  "staged_at": "2026-09-18 14:30:00",
  "requires_restart": true,
  "reason": "payload contains dll"
}
```

Lần khởi động AutoCAD kế tiếp: `ApplicationPlugin.Initialize()` (đã có trong nhánh .NET — **KHÔNG sửa**, chỉ đọc marker) hoặc `mto-loader.lsp` kiểm tra marker → nếu `requires_restart=true` và AutoCAD vừa mở → gọi bootstrap swap → `(load)` lại.

> **Ghi chú:** vì prompt yêu cầu **không sửa nhánh .NET**, việc phát hiện marker đặt ở **LISP**
> (`mto-selfup.lsp` tại thời điểm load). Đây là điểm vào hợp lệ vì loader chạy mỗi session.

### QĐ-4 — Layout thư mục: GIỮ NGUYÊN layout hiện tại

**Không** chuyển sang `current/` (sẽ phá bản đã cài + phải sửa loader/tài liệu).

**Layout chốt:**

```
%LOCALAPPDATA%\MTOPro\
├─ lisp\                  ← APPLICATION (current) — được phép swap
│  └─ mto-loader.lsp ...
├─ docs\                  ← APPLICATION
├─ tools\                 ← APPLICATION
├─ dll\                   ← APPLICATION (có thể bị khoá)
├─ version.json           ← APPLICATION (nguồn phiên bản local)
├─ staging\               ← BẢN MỚI đang chờ kích hoạt
│  ├─ lisp\ ...
│  └─ pending-activation.json
├─ backup\
│  ├─ 1.0.0\              ← giữ tối đa KEEP_BACKUPS = 3
│  ├─ 0.9.0\
│  └─ 0.8.0\
├─ config\                ← ⛔ USER DATA — KHÔNG BAO GIỜ GHI ĐÈ
│  ├─ rules.json
│  ├─ rules.sample.json
│  ├─ update.json
│  ├─ DANH_MUC_VAT_TU.xlsx
│  └─ *.mtocfg
└─ logs\
   ├─ update.log
   └─ <session>_startup.log
```

**Bảng phân loại — bắt buộc tuân thủ:**

| Loại | Đường dẫn | Update được? |
|---|---|---|
| **Application** | `lisp\` `docs\` `tools\` `dll\` `version.json` | ✅ Ghi đè khi kích hoạt |
| **User data** | `config\**` | ⛔ **KHÔNG BAO GIỜ** |
| **User data (ngoài)** | `*.dwg`, `*.mtocfg` cạnh DWG | ⛔ **KHÔNG BAO GIỜ** |
| **Log** | `logs\**` | Chỉ ghi thêm, không xoá |

### QĐ-5 — `KEEP_BACKUPS = 3`, rollback 1 lệnh

- Trước khi kích hoạt: copy toàn bộ app files hiện tại → `backup\<version-đang-chạy>\`.
- Sau khi backup xong: nếu số thư mục trong `backup\` > 3 → xoá cái **cũ nhất** (theo `release_date`).
- **Rollback**: `MTOUPGRADE ROLLBACK` hoặc `mto-selfup-rollback` → copy `backup\<ver>\` trở lại `lisp\` → `(load)`.

### QĐ-6 — `UpdateSource` abstraction

```lisp
;; Tra ve MANIFEST (alist) hoac nil
(mto-selfup-fetch-manifest source)
```

| Loại source | Cú pháp `updateSource` | Cách lấy manifest |
|---|---|---|
| **Local folder / NAS** | `\\server\share\MTOPro` hoặc `D:\MTOPro-Release` | `vl-file-copy` / đọc trực tiếp `<src>\manifest.json` |
| **HTTP(S) nội bộ** | `https://update.congty.local/mtopro` | `certutil -urlcache -f <url>/manifest.json <tmp>` |
| **file://** | `file:///D:/MTOPro-Release` | Strip `file://` → xử lý như local |
| **Internal Git** | `https://git.congty.local/mto/releases` (raw) | HTTP(S) — ưu tiên dùng raw file URL |

**Thứ tự ưu tiên triển khai:** Local folder (test được ngay) → HTTP(S) → Git raw.
**Chỉ HTTPS** cho nguồn mạng; **từ chối `http://`** (trừ `http://localhost` để test).

### QĐ-7 — Kiểm tra khi khởi động: NON-BLOCKING

- `mto-loader.lsp` sau khi nạp module → **KHÔNG** tự tải mạng.
- Chỉ **đọc marker** `pending-activation.json` (file cục bộ) → nếu có, báo và xử lý.
- **Auto-check mạng** đặt sau cờ `checkOnStartup` + `checkIntervalHours` trong `update.json`; nếu bật:
  - Kiểm tra `logs\update.log` (lần check cuối) → nếu chưa quá `checkIntervalHours` → **bỏ qua**.
  - Nếu cần check: `startapp` chạy **nền** → không chặn AutoCAD.
  - **Mặc định `checkOnStartup = false`** trong bản đầu (an toàn; user bật bằng `MTOCFG`/sửa file).

### QĐ-8 — Không credential trong source/package/log

- Không token/password/private key ở bất kỳ đâu.
- Nguồn cập nhật là **nội bộ** (share/NAS/HTTPS nội bộ) → xác thực bằng quyền hệ điều hành.
- `update.log` ghi: timestamp, version, source URL **(đã strip credential nếu có)**, kết quả.
- Nếu URL chứa `user:pass@` → **strip trước khi ghi log**.

---

## 3. Luồng cập nhật (8 bước bắt buộc)

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. START                                                         │
│    - Đọc config\update.json (nếu thiếu → dùng mặc định an toàn)  │
│    - Nếu enabled=false → DỪNG                                    │
├──────────────────────────────────────────────────────────────────┤
│ 2. ĐỌC LOCAL VERSION                                             │
│    - Đọc version.json (app) → local_version                      │
│    - Thiếu/lỗi → fallback "*MTO-VERSION*" + WARNING (TEST-01)    │
├──────────────────────────────────────────────────────────────────┤
│ 3. CHECK REMOTE (manifest)                                       │
│    - Fetch <updateSource>/manifest.json                          │
│    - Lỗi mạng → graceful, ghi log, RETRY tối đa 3 lần (TEST-05)  │
├──────────────────────────────────────────────────────────────────┤
│ 4. SO SÁNH PHIÊN BẢN                                             │
│    - remote > local      → UPDATE                                │
│    - remote = local      → NO-OP                                 │
│    - remote < local      → NO-OP (kèm cảnh báo)                  │
│    - mandatory=true      → bắt buộc, thông báo rõ (TEST-04)      │
├──────────────────────────────────────────────────────────────────┤
│ 5. DOWNLOAD                                                      │
│    - Tải <updateSource>/<package> → staging\package.zip          │
│    - Local source → vl-file-copy; HTTP → certutil                │
├──────────────────────────────────────────────────────────────────┤
│ 6. VERIFY                                                        │
│    - SHA256(zip) == manifest.sha256      (TEST-06)               │
│    - Giải nén → kiểm tra cấu trúc payload (TEST-07):             │
│        • có ít nhất 1 file .lsp                                  │
│        • có version.json khớp manifest.version                   │
│        • KHÔNG chứa đường dẫn ngoài phạm vi (chống zip-slip)     │
├──────────────────────────────────────────────────────────────────┤
│ 7. BACKUP + STAGE + ACTIVATE                                     │
│    - Backup app files → backup\<local_version>\   (TEST-08)      │
│    - Copy staging → lisp\, docs\, tools\, dll\                   │
│    - Payload chỉ LISP → hot reload ngay          (TEST-12)       │
│    - Payload có DLL  → ghi pending-activation    (TEST-13)       │
├──────────────────────────────────────────────────────────────────┤
│ 8. VALIDATE / ROLLBACK                                           │
│    - Load lại loader → đếm module OK?            (TEST-09)       │
│    - Lỗi → rollback từ backup\                   (TEST-10)       │
│    - Xoá backup cũ nếu > KEEP_BACKUPS                            │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4. Thành phần & trách nhiệm

| Thành phần | File | Trách nhiệm |
|---|---|---|
| **Nguồn phiên bản** | `version.json` | Nguồn sự thật duy nhất |
| **Logic LISP** | `lisp/mto-selfup.lsp` | Đọc version, parse manifest, so sánh semver, quyết định action, bookkeeping backup/stage, ghi log, marker |
| **Lệnh** | (trong `mto-selfup.lsp`) | `MTOVERSION` · `MTOUPGRADECHECK` · `MTOUPGRADE` |
| **Bootstrap updater** | `installer/updater/UpdaterApp.cs` + `scripts/build-updater.ps1` | Tải/verify/swap **độc lập với LISP** — giải quyết việc DLL bị khoá |
| **Pipeline phát hành** | `scripts/publish-update.ps1` | Đóng gói `package.zip`, băm SHA256, sinh `manifest.json`, tạo cây `release\` |
| **Cấu hình** | `config/update.sample.json` | Mẫu cấu hình (user data) |
| **Tài liệu** | `docs/update/*.md` (5 file) | Kiến trúc, phát hành, cài đặt, rollback, xử lý sự cố |

**Ranh giới trách nhiệm:**

```
LISP (mto-selfup.lsp)
  ├─ Đọc version, parse manifest      ← THUẦN LISP, testable headless
  ├─ So sánh semver                    ← THUẦN LISP, testable headless
  ├─ Quyết định action                 ← THUẦN LISP, testable headless
  ├─ Bookkeeping (backup list, marker) ← THUẦN LISP, testable headless
  ├─ Ghi log                           ← THUẦN LISP, testable headless
  └─ Gọi certutil (download/hash)      ← startapp, KHÔNG đồng bộ

Bootstrap EXE (UpdaterApp.exe)
  ├─ Tải (HttpClient / copy local)
  ├─ Verify SHA256
  ├─ Giải nén + kiểm cấu trúc
  ├─ Backup + swap (được phép khi AutoCAD đã đóng)
  └─ Ghi log + exit code
```

> **Nguyên tắc:** phần **quyết định** ở LISP (test được headless, 100% test coverage);
> phần **thao tác file/network nặng** ở EXE (chỉ chạy khi cần).

---

## 5. Manifest — định dạng bắt buộc

`release/manifest.json` (và `release/<version>/manifest.json`):

```json
{
  "product": "MTOPro",
  "version": "1.1.0",
  "release_date": "2026-10-01",
  "package": "package.zip",
  "sha256": "a3f5...64-hex...",
  "size_bytes": 1058304,
  "minimum_version": "1.0.0",
  "minimum_autocad": "24.0",
  "mandatory": false,
  "release_notes": "Sua loi bang NATIVE rong; them canh bao don vi; ..."
}
```

| Field | Bắt buộc | Ghi chú |
|---|---|---|
| `product` | ✅ | Phải khớp `MTOPro` — chống cài nhầm sản phẩm |
| `version` | ✅ | Semver `MAJOR.MINOR.PATCH` |
| `release_date` | ✅ | `YYYY-MM-DD` |
| `package` | ✅ | Tên file zip, **tương đối** so với manifest |
| `sha256` | ✅ | 64 ký tự hex **chữ thường** |
| `size_bytes` | | Kiểm tra sơ bộ trước khi băm |
| `minimum_version` | ✅ | Bản cũ hơn → phải cập nhật tuần tự |
| `minimum_autocad` | ✅ | So với `ACADVER` |
| `mandatory` | ✅ | `true` = bắt buộc |
| `release_notes` | ✅ | Hiển thị cho người dùng |

> **Ràng buộc parser LISP**: cùng lý do như `version.json` — **object phẳng, mỗi field 1 dòng,
> KHÔNG field lồng nhau**. `release_notes` phải là **1 dòng** (không xuống dòng trong chuỗi).

---

## 6. Bảng TEST-01..16 — cách chạy & bằng chứng

| ID | Nội dung | Cách chạy | Bằng chứng |
|---|---|---|---|
| TEST-01 | Đọc local version.json thiếu/lỗi → fallback | `test-selfup.lsp` headless: gọi hàm với file không tồn tại | `TEST-PASS: selfup-01` |
| TEST-02 | Parse manifest remote đủ field | `test-selfup.lsp`: parse chuỗi manifest mẫu | `TEST-PASS: selfup-02` |
| TEST-03 | So sánh version (mới/bằng/cũ/cùng) | `test-selfup.lsp`: 8 ca so sánh semver | `TEST-PASS: selfup-03` |
| TEST-04 | mandatory chặn / optional hỏi | `test-selfup.lsp`: hàm quyết định action | `TEST-PASS: selfup-04` |
| TEST-05 | Lỗi mạng → graceful, không crash | `test-selfup.lsp`: source không tồn tại → trả nil + log | `TEST-PASS: selfup-05` |
| TEST-06 | SHA256 sai → từ chối | `test-selfup.lsp`: hash so sánh sai → `verify` fail | `TEST-PASS: selfup-06` |
| TEST-07 | Payload thiếu file → từ chối | `test-selfup.lsp`: kiểm cấu trúc danh sách file | `TEST-PASS: selfup-07` |
| TEST-08 | Backup đúng, giữ 3 bản | `test-selfup.lsp`: hàm prune danh sách backup | `TEST-PASS: selfup-08` |
| TEST-09 | Stage→Activate→Validate OK | `test-selfup.lsp`: mô phỏng chuỗi trạng thái | `TEST-PASS: selfup-09` |
| TEST-10 | Activate lỗi → Rollback | `test-selfup.lsp`: quyết định rollback | `TEST-PASS: selfup-10` |
| TEST-11 | User data không bị đụng | `test-selfup.lsp`: danh sách đường dẫn cấm | `TEST-PASS: selfup-11` |
| TEST-12 | Hot reload LISP | **accoreconsole thật**: swap lisp → `(load)` → đếm module | log `FIELD-*` + `TEST-PASS` |
| TEST-13 | DLL cần restart → marker | `test-selfup.lsp`: tạo/đọc `pending-activation.json` | `TEST-PASS: selfup-13` |
| TEST-14 | 3 lệnh đúng hành vi | `test-loader.lsp` + headless gọi lệnh | `TEST-PASS: command: MTOVERSION` |
| TEST-15 | Pipeline sinh package+sha256+manifest | `publish-update.ps1` chạy thật → kiểm 3 file khớp | log publish + `verify-package.ps1` |
| TEST-16 | Log không credential; HTTPS enforced | `test-selfup.lsp`: hàm strip credential + validate scheme | `TEST-PASS: selfup-16` |

**Nguyên tắc:** không giả PASS. Test nào không chạy được → ghi **BLOCKED + lý do** vào `MASTER_STATUS §5`.

---

## 7. Rủi ro & giảm thiểu

| # | Rủi ro | Mức | Giảm thiểu |
|---|---|---|---|
| 1 | Ghi đè `config\rules.json` của user | 🔴 Cao | Whitelist app paths; `config\` **không bao giờ** trong danh sách swap; TEST-11 |
| 2 | DLL bị khoá → swap thất bại giữa chừng | 🔴 Cao | Marker + bootstrap EXE; swap chỉ khi AutoCAD đóng; rollback |
| 3 | Mất điện giữa lúc swap | 🟠 TB | Backup trước; activate theo thứ tự (ghi `staging` xong mới swap); rollback |
| 4 | Hash sai do file tải lỗi | 🟠 TB | SHA256 bắt buộc, từ chối nếu lệch |
| 5 | Zip-slip (giải nén ghi ra ngoài) | 🟠 TB | Kiểm mọi entry không chứa `..`/đường dẫn tuyệt đối |
| 6 | `certutil` bị chặn bởi policy | 🟡 Thấp | Fallback bootstrap EXE dùng `HttpClient` |
| 7 | Nguồn cập nhật bị giả mạo | 🟠 TB | Chỉ HTTPS; SHA256 từ manifest (manifest lấy qua HTTPS nội bộ tin cậy) |
| 8 | Auto-check làm chậm AutoCAD | 🟡 Thấp | Mặc định `checkOnStartup=false`; chạy nền `startapp`; giới hạn `checkIntervalHours` |
| 9 | Phiên bản mới lỗi → người dùng kẹt | 🔴 Cao | Rollback 1 lệnh; giữ 3 backup |
| 10 | Người dùng sửa file trong `lisp\` | 🟡 Thấp | Update ghi đè — đã ghi rõ trong tài liệu |

---

## 8. Thứ tự triển khai (TASK-018 → TASK-027)

| Task | Nội dung | Phụ thuộc |
|---|---|---|
| **TASK-018** | `version.json` single-source + gộp 4 nơi lệch | — |
| **TASK-019** | `mto-selfup.lsp` (logic thuần: version, semver, manifest, action, backup, log, marker) | 018 |
| **TASK-020** | `test-selfup.lsp` (TEST-01..11, 13, 16) | 019 |
| **TASK-021** | Bootstrap updater `installer/updater/` + build script | 018 |
| **TASK-022** | `config/update.sample.json` + đọc runtime | 019 |
| **TASK-023** | 3 lệnh `MTOVERSION` / `MTOUPGRADECHECK` / `MTOUPGRADE` | 019, 022 |
| **TASK-024** | `scripts/publish-update.ps1` + `release/manifest.json` | 018, 021 |
| **TASK-025** | Nâng `build-lisp-installer.ps1` (nhúng updater + version.json) | 021 |
| **TASK-026** | 5 tài liệu `docs/update/*` | 018..025 |
| **TASK-027** | TEST-12, 14, 15 + tổng hợp TEST-01..16 + checkpoint cuối | tất cả |

---

## 9. Ghi chú tuân thủ luật repo

- **todo_write** mỗi task; **2 bản tin Telegram/task** (bắt đầu + hoàn thành).
- **3 cổng test bắt buộc**: LINT → LOAD-CHECK → TEST headless.
- **Checkpoint sau mỗi task**: `MASTER_STATUS.md` §4 + §6, `TASK_INDEX.md`.
- **Tiếng Việt không dấu** trong code/comment LISP; tài liệu `.md`/`.docx` có dấu.
- **Không** sửa nhánh `.NET` trong `src/**`; **không** sửa 633 test hiện có.

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — module UPDATE SYSTEM.*
