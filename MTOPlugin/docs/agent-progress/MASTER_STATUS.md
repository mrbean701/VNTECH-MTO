# MASTER_STATUS.md — Trạng thái tổng dự án MTO (LISP-first)

> Checkpoint bắt buộc. Cập nhật sau MỖI task.
> Cập nhật lần cuối: 2026-09-18

---

## 1. MASTER GOAL

Xây bộ công cụ AutoCAD chuyên nghiệp **ưu tiên AutoLISP** phục vụ bóc tách khối lượng:
- Hệ Điện
- Hệ Nước
- Điện nhẹ / ELV

Kiến trúc: **LISP-first → LISP + AutoCAD Table → .NET wrapper/UI khi cần.**
Không chuyển logic nhận dạng/đếm sang .NET chỉ vì UI thuận tiện.

---

## 2. BASELINE KỸ THUẬT (PHASE 0 — đã audit)

### 2.1 Môi trường test THẬT (đã kiểm chứng)

| Thành phần | Giá trị | Bằng chứng |
|---|---|---|
| AutoCAD Core Console | `D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe` | Đã chạy `/s` OK |
| ACADVER | `24.2` (AutoCAD 2023) | `PROBE-OK acad=24.2` |
| Chạy LISP headless | CÓ | `accoreconsole /s script.scr` |
| DWG mẫu | `D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\Sample\` | Electrical Power.dwg, Pipe Fittings.dwg |
| Ghi chú encoding | Console output là UTF-16LE | cần decode khi parse |

**Kết luận:** có thể TEST LISP thật headless → không cần giả mạo PASS.

### 2.2 Hiện trạng mã nguồn

| Khu vực | Nội dung | Trạng thái so với MASTER GOAL |
|---|---|---|
| `src/MTOPlugin.Core` (.NET netstandard2.0) | RuleEngine, ClassificationEngine, Excel/CSV export, Batch, Localization | Có, nhưng KHÁC kiến trúc (không LISP-first) |
| `src/MTOPlugin` (Host AutoCAD) | Scanner DWG, MTO/MTOZOOM/MTOBANG | net8.0-windows — **KHÔNG load được trên AutoCAD 2023 (net48)** |
| `src/MTOPlugin.UI` (WPF) | MainPanel, RuleEditorWindow | net8 — cùng vấn đề |
| `src/MTOPlugin/lisp/mto-commands.lsp` | 7 hàm wrapper gọi .NET | Chỉ là vỏ, KHÔNG có logic MTO |
| `tests/MTOPlugin.Tests` | 86 test .NET Core | Chỉ kiểm .NET, không kiểm LISP |
| `docs/` | ARCHITECTURE, BUILD, INSTALL, RULES, TESTING, IMPLEMENTATION, CHECKLIST, PROGRESS_REPORT | Có, mô tả nhánh .NET |
| `docs/agent-progress/` | — | Chưa tồn tại (tạo ở task này) |

### 2.3 Phát hiện quan trọng

1. **Chỉ có 1 file LISP, và nó không chứa logic nghiệp vụ nào.** Toàn bộ roadmap PHASE 1–4 chưa được triển khai bằng LISP.
2. **.NET plugin build `net8.0-windows` nhưng máy chỉ có AutoCAD 2023 (R24.2 / net48)** → DLL hiện tại không nạp được. LISP chạy được trên mọi phiên bản ⇒ LISP-first là lựa chọn đúng cho môi trường này.
3. **Có `accoreconsole.exe`** ⇒ mọi task LISP đều test được tự động.
4. Nhánh .NET giữ nguyên, **không xóa/rewrite** (theo nguyên tắc "không phá code hiện tại").

---

## 3. QUYẾT ĐỊNH KIẾN TRÚC (đã chốt, không hỏi lại)

| Quyết định | Nội dung |
|---|---|
| Vị trí mã LISP | `MTOPlugin/lisp/` (mới, tách khỏi `src/`) |
| Prefix command | `MTO*` mở rộng (`MTOSEL`, `MTOTEXT`, `MTOBLK`, `MTOGEO`, `MTOLIST`, `MTOCSV`, `MTOORPHAN`, `MTOTABLE`, `MTOFIND`, `MTOUPDATE`, `MTOUNDO`, `MTOFORMULA`, `MTOSUB`, `MTOFLOOR`, `MTOCFG`, `MTOMENU`) — không trùng 7 command .NET hiện có |
| Data model trung tâm | Danh sách phẳng (flat list) các record dạng association list, khóa không đổi |
| Lưu trữ phiên | Biến toàn cục `*MTO-DATA*` + ghi/đọc file EDN-like (LISP-readable) |
| Test harness | `lisp/tests/run-tests.ps1` → `accoreconsole /i <dwg> /s tests.scr` → parse `TEST-PASS` / `TEST-FAIL` |
| Ngôn ngữ tài liệu | Tiếng Việt (không dấu trong code/comment để tránh lỗi encoding) |

---

## 4. TIẾN ĐỘ TỔNG

| Phase | Task | Trạng thái |
|---|---|---|
| PHASE 0 | TASK-000 Audit & baseline | ✅ DONE |
| PHASE 1 | TASK-001 Interactive Selection | ✅ DONE (32/32) |
| PHASE 1 | TASK-002 Text Prefix Recognition | ✅ DONE (40/40) |
| PHASE 1 | TASK-003 Block Recognition & Counting | ✅ DONE (41/41) |
| PHASE 1 | TASK-004 Geometry Quantity | ✅ DONE (31/31) |
| PHASE 1 | TASK-005 Unified Quantity Data Model | ✅ DONE (45/45) |
| PHASE 1 | TASK-006 Result List | ✅ DONE (30/30) |
| PHASE 1 | TASK-007 CSV Export | ✅ DONE (26/26) |
| PHASE 1 | TASK-008 Orphan Detection | ✅ DONE (27/27) |
| PHASE 1 | LOADER đóng gói + MTOHELP | ✅ DONE (24/24) |
| PHASE 2 | TASK-009 AutoCAD Table | ✅ DONE (38/38) |
| PHASE 2 | TASK-010 Find / Zoom Back | ✅ DONE (32/32) |
| PHASE 2 | TASK-011 Batch Update | ✅ DONE (34/34) |
| PHASE 2 | TASK-012 Plugin Undo/Restore | ✅ DONE (28/28) |
| — | LINT cú pháp + load-check | ✅ DONE (31 file OK) |
| PHASE 3 | TASK-013 Custom Formula | ✅ DONE (62/62) |
| PHASE 3 | TASK-014 Subtotal & Deduction | ✅ DONE (33/33) |
| PHASE 4 | TASK-015 Floor / Zone | ✅ DONE (43/43) |
| PHASE 4 | TASK-016 Per-Drawing Configuration | ✅ DONE (34/34) |
| PHASE 5 | TASK-017 .NET Extension (UI) | ✅ DONE (net48 build 0 lỗi · NETLOAD OK · MTOZOOM chạy) |
| — | **FINAL AUDIT** | ✅ DONE — **19/19 mục MASTER GOAL** |
| **PHASE UPGRADE** | TASK-018 version.json single-source | ✅ DONE (637/637 · 5 nơi đồng bộ 1.0.0) |
| **PHASE UPGRADE** | TASK-019 mto-selfup.lsp (logic thuần LISP) | ✅ DONE (643/643 · LINT 43 file) |
| **PHASE UPGRADE** | TASK-020 test-selfup.lsp (TEST-01..11,13,16) | ✅ DONE (42/42 · tổng 685/685) |
| **PHASE UPGRADE** | TASK-021 Bootstrap updater | ✅ DONE (build 17 KB · --status/--check chạy thật) |
| **PHASE UPGRADE** | TASK-022 update.sample.json + runtime | ⏳ TODO |
| **PHASE UPGRADE** | TASK-023 Lệnh MTOVERSION/MTOUPGRADECHECK/MTOUPGRADE | ⏳ TODO |
| **PHASE UPGRADE** | TASK-024 publish-update.ps1 + release manifest | ⏳ TODO |
| **PHASE UPGRADE** | TASK-025 Nâng build-lisp-installer | ⏳ TODO |
| **PHASE UPGRADE** | TASK-026 5 tài liệu docs/update/* | ⏳ TODO |
| **PHASE UPGRADE** | TASK-027 TEST-12,14,15 + checkpoint cuối | ⏳ TODO |

**MASTER PROGRESS: 19/19 mục core + 4/10 PHASE UPGRADE** — **637 test PASS** — **PHASE 1+2+3+4+5 HOÀN THÀNH, 617 test PASS**

> .NET host nay build **net48** cho AutoCAD 2023 (máy hiện có): build 0 lỗi, NETLOAD thành công,
> command `MTOZOOM` từ .NET thực thi đúng. Xem `docs/agent-progress/FINAL_AUDIT.md`.

### Test suite hiện có

| Suite | Tests | Trạng thái |
|---|---|---|
| `test-core.lsp` | 45 | ✅ PASS |
| `test-select.lsp` | 32 | ✅ PASS |
| `test-text.lsp` | 40 | ✅ PASS |
| `test-block.lsp` | 41 | ✅ PASS |
| `test-geometry.lsp` | 31 | ✅ PASS |
| `test-result.lsp` | 30 | ✅ PASS |
| `test-csv.lsp` | 26 | ✅ PASS |
| `test-orphan.lsp` | 27 | ✅ PASS |
| `test-loader.lsp` | 37 | ✅ PASS |
| `test-table.lsp` | 38 | ✅ PASS |
| `test-find.lsp` | 32 | ✅ PASS |
| `test-update.lsp` | 34 | ✅ PASS |
| `test-undo.lsp` | 28 | ✅ PASS |
| `test-formula.lsp` | 62 | ✅ PASS |
| `test-subtotal.lsp` | 33 | ✅ PASS |
| `test-floor.lsp` | 43 | ✅ PASS |
| `test-config.lsp` | 34 | ✅ PASS |
| **TỔNG** | **617** | ✅ **ALL PASS** |

### Cổng chất lượng (bắt buộc trước mọi test run)

1. **LINT cú pháp** (`check-lisp-syntax.ps1`): cân bằng ngoặc + string cho mọi file `.lsp`
2. **LOAD-CHECK**: hàm `mto-qload` ghi lại file nào không load sạch → runner exit 2
3. **TEST**: accoreconsole headless, kết quả ghi ra file, so khớp PASS/FAIL

> Cổng 1+2 được thêm sau bug B16: file `mto-update.lsp` có lỗi cú pháp ở cuối nhưng
> test vẫn PASS vì các `defun` phía trước đã được định nghĩa.

---

## 5. KNOWN ISSUES / BLOCKERS

| # | Nội dung | Mức | Xử lý |
|---|---|---|---|
| I1 | .NET DLL hiện tại build net8, máy có AutoCAD 2023 (net48) ⇒ không nạp được | Trung bình | Không thuộc phạm vi LISP-first; ghi nhận để PHASE 5 xử lý |
| I2 | Console accoreconsole xuất UTF-16LE, khó parse | Thấp | Đã xử lý: LISP ghi kết quả ra file, PowerShell đọc file |
| I3 | Chưa có Telegram token trong repo | — | Dùng công cụ `notify` sẵn có của harness (đang hoạt động) |
| I4 | **`SECURELOAD=1` mặc định của AutoCAD chặn `(load ...)` ngoài TRUSTEDPATHS** ⇒ plugin không nạp được nếu người dùng chỉ gõ `(load ...)` | **Cao** | Harness tắt SECURELOAD trong phiên test. **Phải ghi INSTALL.md** hướng dẫn APPLOAD/TRUSTEDPATHS trước khi giao |
| I5 | `mto-db-merge-item` O(n) mỗi lần thêm ⇒ O(n²) | Thấp | Tối ưu ở PHASE 3 nếu cần |
| I6 | Chưa hỗ trợ dynamic block (EffectiveName) và block lồng | Trung bình | Ghi nhận; xử lý khi có DWG thật chứa dynamic block |
| I7 | Bảng prefix hard-code trong LISP | Trung bình | Đưa ra config ở PHASE 4 (TASK-016) |

---

## 6. NHẬT KÝ CHECKPOINT

| Thời điểm | Task | Kết quả |
|---|---|---|
| 2026-09-18 | TASK-000 | Audit xong; xác lập baseline accoreconsole + ACADVER 24.2; tạo MASTER_STATUS.md + TASK_INDEX.md |
| 2026-09-18 | TASK-005 | Data model + test harness; **45/45 PASSED**; phát hiện & sửa 2 bug thật (`strcase` lowercase, `num->str` trailing zero) + root cause `SECURELOAD` |
| 2026-09-18 | TASK-001 | Interactive Selection (5 mode + layer filter); **32/32 PASSED** trên entity `entmake` thật; sửa bug bind `T`; regression TASK-005 vẫn 45/45 |
| 2026-09-18 | TASK-002 | Text Prefix Recognition (46 prefix, 3 hệ); **40/40 PASSED**; sửa 3 vấn đề: MTEXT thiếu subclass, harness mất kết quả khi crash, giả định sai thứ tự `ssget` |
| 2026-09-18 | TASK-003 | Block counting + manual adjustment; **41/41 PASSED**; sửa bug dotted-pair (`caar`) khi lấy layer block; regression 117/117 PASS |
| 2026-09-18 | TASK-004 | Geometry Quantity (`vlax-curve`, 7 loại, đơn vị theo `INSUNITS`); **31/31 PASSED**; kiểm bằng công thức giải tích (π·r, 2π·r); regression 158/158 PASS |
| 2026-09-18 | TASK-006 | Result List (bảng 6 cột, `MTOLIST`); **30/30 PASSED** |
| 2026-09-18 | TASK-007 | CSV Export (15 cột, RFC4180 escape, ghi/đọc file thật); **26/26 PASSED**; sửa 3 bug: `strcase` hoa vs `.dwg`, CR+LF thành 2 space, src/dst translate lệch độ dài |
| 2026-09-18 | TASK-008 | Orphan Detection; **27/27 PASSED**; **root cause quan trọng**: `handent` vẫn resolve entity đã `entdel` ⇒ phải kiểm thêm `entget`; sửa bug dùng giá trị `entmake` làm ename |
| 2026-09-18 | LOADER | `mto-loader.lsp` + `MTOHELP` (đóng gói PHASE 1); **24/24 PASSED**; **PHASE 1 HOÀN THÀNH — 296 test PASS** |
| 2026-09-18 | TASK-009 | AutoCAD Table (9 cột, subtotal Category, grand total; 2 backend NATIVE/GRID); **38/38 PASSED**; sửa B12 `(last lst)` trả phần tử cuối, B13 mô tả≠thực vẽ. **Phát hiện accoreconsole không có ActiveX** |
| 2026-09-18 | TASK-010 | Find/Zoom Back (không ActiveX, dùng ZOOM _O + sssetfirst); **32/32 PASSED**; sửa B14 sắp xếp phân biệt hoa/thường ⇒ đổi `mto-db-sort` sang case-insensitive |
| 2026-09-18 | TASK-011 | Batch Update TEXT/MTEXT/XData; **34/34 PASSED**; sửa B15 APPID thiếu subclass, **B16 file lỗi cú pháp cuối nhưng test vẫn PASS ⇒ gia cố harness (lint + load-check)** |
| 2026-09-18 | TASK-012 | Plugin Undo/Restore (snapshot HANDLE→OLD VALUE, `mto-upd-batch-safe`); **28/28 PASSED**; **PHASE 2 HOÀN THÀNH — 436 test PASS** |
| 2026-09-18 | TASK-013 | Custom Formula (`LEN * 1.05`, không dùng `eval`); **62/62 PASSED**; sửa B17 **AutoLISP không có `let`** (kiểm chứng thực nghiệm) — quét và sửa cả `mto-update.lsp` |
| 2026-09-18 | TASK-014 | Subtotal/Deduction generic theo khoá + clamp NETQTY≥0; **33/33 PASSED**; **cổng LINT chặn được lỗi ngoặc trước khi chạy test** (B18); sửa B19 bỏ qua kết quả hàm immutable. **PHASE 3 HOÀN THÀNH — 536 test PASS** |
| 2026-09-18 | TASK-015 | Floor/Zone/Area (gán theo layer `wcmatch` / vùng chọn / tất cả) + subtotal theo tầng; **43/43 PASSED**; sửa B20 `'(<)` vs `'<` trong `vl-sort` |
| 2026-09-18 | TASK-016 | Per-Drawing Config (**file `.mtocfg`** + **NOD/XRecord trong DWG** — cả hai đã kiểm chứng); **34/34 PASSED**. **PHASE 4 HOÀN THÀNH — 617 test PASS** |
| 2026-09-18 | TASK-017 | .NET Extension → **DONE**: phát hiện `MtoCompat.cs` viết NGƯỢC (AutoCAD 2023 dùng API giống 2025). Sửa 4 file → **build net48 cho AutoCAD 2023: 0 lỗi**; **NETLOAD thành công**; command `MTOZOOM` từ .NET **thực thi đúng** (bằng chứng: in "Handle khong hop le.") |
| 2026-09-18 | **FINAL AUDIT** | Đối chiếu 19 mục MASTER GOAL: **19/19 ✅**. 617 test PASS · 35 file LINT OK · 20 bug thật đã sửa · limitation đã ghi rõ |
### PHASE UPGRADE — MODULE UPDATE SYSTEM

| Thời điểm | Task | Kết quả |
|---|---|---|
| 2026-09-18 | AUDIT + ARCH | Baseline xác nhận **633/633 PASS** (prompt ghi 617 = số cũ). Viết `docs/update/UPDATE_ARCHITECTURE.md` — 8 quyết định kiến trúc đã chốt (QĐ-1..8). Push git nhánh `unity` (172 file). Thêm PHASE UPGRADE TASK-018→027 vào TASK_INDEX + §4 |
| 2026-09-18 | TASK-018 | **version.json single-source**: tạo `version.json` (baseline 1.0.0); loader đọc từ file (parser dòng phẳng, fallback hằng số, `mto-version-read`); build script đọc version.json; đồng bộ **5 nơi** (version.json · mto-loader · build script · mto.iss · 3× PackageContents.xml). InstallerLisp.cs cài version.json. **+4 test** → **637/637 PASS**, LINT 42 file OK. Không hồi quy |
| 2026-09-18 | TASK-019 | **mto-selfup.lsp** (logic cập nhật thuần LISP, ~565 dòng): đọc/ghi JSON phẳng · semver compare · validate manifest 9 field bắt buộc · UpdateSource (HTTPS/local/file) · strip credential · **quyết định 5 action** (UPDATE/NOOP/MANDATORY/BLOCKED-MINVER/ERROR) · backup bookkeeping + prune KEEP=3 · marker kích hoạt session kế · log · payload validation + **chống zip-slip** · config update.json · **3 lệnh MTOVERSION/MTOUPGRADECHECK/MTOUPGRADE**. Thêm 5 hàm tiện ích vào core. **+6 test** → **643/643 PASS**, LINT 43 file OK. Sửa 1 lỗi ngoặc cuối c:MTOUPGRADE (lint bắt được) |
| 2026-09-18 | TASK-020 | **test-selfup.lsp** — 42 test bao phu TEST-01..11/13/16: version fallback · parse manifest · semver (4 ca) · mandatory/optional · lỗi nguồn graceful · sha256 64-hex · payload structure + zip-slip · backup prune KEEP=3 · quyết định UPDATE/NOOP/BLOCKED-MINVER · **user data an toàn** · marker session kế · strip credential + HTTPS enforced. Thêm suite vào run-all-tests. **685/685 PASS**, LINT 44 file OK. Bug thật bắt được: mto-upd-json-read trả nil (thay bằng mto-upd-json-load dùng json-get đã kiểm chứng) · off-by-one trong strip-credential · (if p phải là (if q |
| 2026-09-18 | TASK-021 | **Bootstrap updater** installer/updater/UpdaterApp.cs (~430 dòng) + scripts/build-updater.ps1 (csc.exe, 17 KB). Lệnh: --status --check --install --rollback. Luồng đủ 8 bước: manifest → semver → download (WebClient/local) → **verify SHA256** → giải nén **chống zip-slip** → verify payload → backup → activate (**chỉ app files, KHÔNG chạm config/**) → prune KEEP=3 → rollback. Test thật: --status đọc đúng 1.0.0 sau khi cài; --check với release giả 1.1.0 → báo **CO BAN MOI**, SHA256 in đúng. Phát hiện: bản cài cũ chưa có version.json → đã cài lại |
