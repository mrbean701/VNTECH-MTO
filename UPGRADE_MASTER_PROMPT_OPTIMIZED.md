# MASTER IMPLEMENTATION PROMPT — MTO "Offline Package + Online Update System" (BẢN TỐI ƯU THEO HIỆN TRẠNG)

> Phiên bản này được tối ưu từ prompt/MASTER GOAL gốc (do ChatGPT viết) dựa trên:
> 1) **Hiện trạng thực tế repo** `quantity take-off\MTOPlugin` (đã audit đầy đủ ở mục 4).
> 2) **Các luật mới trong `AGENTS.md`** ở workspace root (todo_write, 2 bản tin Telegram/task, cổng test thật, checkpoint sau mỗi task).
>
> Dùng prompt này làm **session goal / instruction** cho deepseek harness (dsh).
> End-to-end: bắt đầu ngay tại mục "START NOW".

---

## 1. VAI TRÒ VÀ BẢN CHẤT CÔNG VIỆC

Bạn là agent triển khai module **"Đóng gói offline (Offline Package) + Hệ thống cập nhật tập trung qua mạng (Centralized Online Update)"** cho bộ công cụ **MTOPro** — plugin AutoCAD bóc tách khối lượng (M&E: Điện / Nước / Điện nhẹ ELV), kiến trúc **LISP-first**.

Module này là **PHASE MỚI (UPGRADE) trên nền core ĐÃ HOÀN THÀNH** (MASTER GOAL 19/19 mục + 617 test LISP PASS + FINAL_AUDIT.md). **KHÔNG rewrite, KHÔNG đụng logic MTO hiện có.** Bạn chỉ **THÊM**:
- Client cập nhật trong bộ cài MTOPro.
- Pipeline đóng gói release + manifest + nguồn cập nhật (UpdateSource).
- Tài liệu + test cho toàn bộ luồng nâng cấp.

---

## 2. MASTER GOAL — MODULE UPDATE SYSTEM

### 2.1 Mục tiêu tổng quan
Thiết kế và triển khai hệ thống cập nhật:
- **Offline Package**: phiên bản bất kỳ vẫn cài/đóng gói được thành 1 file EXE đứng độc lập để cài tay cho máy ngoại tuyến (kế thừa `scripts/build-lisp-installer.ps1 → MTOPro.Setup-{version}.exe`).
- **Online Update**: máy kỹ sư đã cài (thường chỉ nối mạng nội bộ/VPN) tự kiểm tra bản mới, tải về, xác minh SHA256, backup và kích hoạt an toàn.

### 2.2 Yêu cầu chức năng (giữ nguyên 100% so với bản gốc)

**A. Phiên bản (Versioning)**
- Semantic versioning theo chuẩn `MAJOR.MINOR.PATCH`.
- **Một nguồn sự thật duy nhất**: file `version.json` ở gốc `MTOPlugin\` quyết định toàn bộ (LISP, installer, bundle, manifest). Các nơi đang lệch nhau phải gộp về nguồn này (chống lại hiện trạng: `*MTO-VERSION* "0.6.0-lisp"` vs `-Version 1.0.0` vs AppVersion 0.1.0 — xem 4.3).
- Manifest từ xa bắt buộc có các field: `product`, `version`, `release_date`, `package`, `sha256`, `minimum_version`, `minimum_autocad`, `mandatory`, `release_notes`.

**B. Nguồn cập nhật (UpdateSource abstraction)**
- Interface chung, triển khai: `Internal Git` (ưu tiên), `HTTP(S)` nội bộ, `NAS/SMB path`, `GitHub/GitLab` (tùy chọn). Hỗ trợ nguồn **cục bộ (folder/NAS)** = chính là "offline package mirror".
- Mỗi bản release: `releases/<version>/package.zip` + `manifest.json` (đặt cùng bản thân file zip).

**C. Luồng cập nhật (bắt buộc theo thứ tự)**
`START → Đọc local (version.json) → Check remote (manifest) → So sánh phiên bản → Download → Verify SHA256 → Verify cấu trúc payload → Backup bản hiện tại → Stage → Activate → Validate → Success / Rollback`.
- Check thủ công và **auto-check khi khởi động, KHÔNG chặn AutoCAD, KHÔNG block UI**.
- Bản `mandatory=true` → bắt buộc cập nhật, thông báo rõ và không cho dùng tiếp đến khi cập nhật/mandatory hết hạn; `optional` → đề xuất, hỏi xác nhận.
- Lỗi mạng phải graceful: không la hét, thử lại, cập nhật tiến độ trong log, không làm crash AutoCAD.

**D. An toàn dữ liệu (CRITICAL)**
- Chuỗi `Download → Staging → Verify(sha256) → Backup → Activate`.
- SHA256 **bắt buộc** với cả file zip.
- **KHÔNG bao giờ xóa/ghi đè dữ liệu người dùng**: DWG, `config\rules.json`, `config\update.json`, `.mtocfg`/NOD, `DANH_MUC_VAT_TU.xlsx`, template, dữ liệu xuất ra. Phân biệt rõ "application files" (lisp/, dll/, docs/, version.json) vs "user data" (config/).
- Backup giữ tối đa `KEEP_BACKUPS = 3` bản; rollback chỉ cần 1 click/1 lệnh.

**E. Kích hoạt nguyên tử (Atomic activation)**
- Layout `current / staging / backup` (hoặc thư mục theo version). Kích hoạt nếu lỗi → quay lại bản cuối còn nguyên.

**F. Bootstrap updater**
- Có một chương trình bootstrap độc lập (không phụ thuộc LISP đang chạy) để tải + verify + swap khi được triệu hồi. Tận dụng đúng pattern có sẵn trong repo: `installer/SetupApp/InstallerLisp.cs` + build bằng `csc.exe` (xem 4.4).

**G. Cấu hình `update.json`**
- `enabled`, `channel` (stable/beta/dev — **chỉ triển khai stable trước**), `checkOnStartup`, `checkIntervalHours`, `updateSource`, `keepBackups`.
- File mẫu `config/update.sample.json` ship kèm; runtime đọc ở `%LOCALAPPDATA%\MTOPro\config\update.json` (user data, không ghi đè nếu tồn tại).

**H. Hiển thị & UX**
- Hiện thông tin: `MTO Version`, `Last Update`, `Update Status` (dòng terminal MTOVERSION + dòng khuyến nghị khi có bản mới).
- Toàn bộ thông báo tiếng Việt, ngắn gọn, nhất quán với phong cách các lệnh MTO hiện có.

**I. Log**
- `logs\update.log` (có timestamp, version, nguồn, kết quả). **KHÔNG ghi token/mật khẩu/private key.**

**J. Tương thích & bảo mật**
- `minimum_version`, `minimum_autocad` (baseline AutoCAD 2023 / ACADVER 24.2 của repo; bản cũ 2018+ cũng nhận nếu payload tương thích).
- Chỉ HTTPS; **KHÔNG token/password/private key trong source/package/log**. Nếu server chưa có credential → triển khai client không credential (source nội bộ).

**K. Lệnh (đã đổi tên do xung đột — xem 4.2)**
- `MTOUPGRADECHECK` — kiểm tra (không tải, non-blocking).
- `MTOUPGRADE` — kiểm tra + tải + cài.
- `MTOVERSION` — xem phiên bản / lần cập nhật cuối / trạng thái.

---

## 3. CÁC LUẬT BẮT BUỘC CỦA REPO (nằm trong `AGENTS.md` — phải tuân thủ) - DON'T

- **todo_write luôn hiển thị**: ngay sau khi nhận yêu cầu gọi `todo_write`; cập nhật theo đúng `in_progress → completed`, gửi lại toàn bộ danh sách mỗi lần; giữ ngắn gọn, mỗi mục một việc con.
- **Báo cáo Telegram — đúng 2 bản tin / task**:
  - Bắt đầu task: `🛠 Bắt đầu task <TASK-ID>: Đang làm ...`
  - Hoàn thành task: `✅ Vừa hoàn thành <TASK-ID>: ... · Test: <PASS/FAIL> · Tiến độ: <task done/total>`
  - Dùng tool `notify` của harness (dsh-notifier). KHÔNG tự tạo token giả.
- **Cổng test THẬT (bắt buộc, không giả mạo PASS)**:
  1. LINT: `lisp/tests/check-lisp-syntax.ps1`
  2. LOAD-CHECK: load `mto-loader.lsp` headless bằng `accoreconsole.exe`
  3. Chạy test suite (617 test LISP hiện có + test mới) qua `lisp/tests/run-tests.ps1` trên `D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe` với DWG mẫu (`...\AutoCAD 2023\Sample\`), decode output UTF-16LE, chỉ PASS khi có marker `TEST-PASS`.
- **Checkpoint sau MỖI task**: cập nhật `MASTER_STATUS.md` §4 (tiến độ) + §6 (nhật ký checkpoint) + `TASK_INDEX.md`. KHÔNG kết thúc session khi TODO empty — luôn tạo task tiếp theo.

---

## 4. HIỆN TRẠNG THỰC TẾ REPO (ĐÃ AUDIT — KHÔNG CẦN HỎI LẠI, KHÔNG PHÁ)

### 4.1 Cây cấu trúc liên quan
- `MTOPlugin\lisp\` — 17 module LISP (`mto-loader.lsp`, `mto-core.lsp`, `mto-select.lsp`, `mto-text.lsp`, `mto-block.lsp`, `mto-geometry.lsp`, `mto-result.lsp`, `mto-csv.lsp`, `mto-orphan.lsp`, `mto-table.lsp`, `mto-find.lsp`, `mto-update.lsp`, `mto-undo.lsp`, `mto-formula.lsp`, `mto-subtotal.lsp`, `mto-floor.lsp`, `mto-config.lsp`).
- `MTOPlugin\lisp\tests\` — `framework.lsp`, `run-tests.ps1`, `run-all-tests.ps1`, `check-lisp-syntax.ps1`, `test-*.lsp` (có `test-update.lsp`).
- `MTOPlugin\config\` — `rules.sample.json`, `DANH_MUC_VAT_TU.xlsx` (template).
- `MTOPlugin\installer\` — `mto.iss` (Inno, "phương án thay thế"), `bundles\MTOPlugin.{2018-2022|2023-2024|2025-2026}.bundle\PackageContents.xml`, `SetupApp\{InstallerApp.cs, InstallerLisp.cs}`.
- `MTOPlugin\scripts\` — `build-installer.ps1`, `build-lisp-installer.ps1`, `deploy-bundle.ps1`, `verify-package.ps1`, `export-excel.ps1`, `import-materials.ps1`, ...
- `MTOPlugin\src\` — nhánh .NET giữ nguyên: `MTOPlugin.Core` (netstandard2.0), `MTOPlugin` (Host AutoCAD net48/net8, có `ApplicationPlugin.cs` tự tìm `mto-loader.lsp`, `MTOCommands.cs`), `MTOPlugin.UI` (WPF), `tests\MTOPlugin.Tests` (NUnit).
- `MTOPlugin\docs\` — kiến trúc/nội bộ; `docs\agent-progress\` — `MASTER_STATUS.md` (§1 MASTER GOAL, §2 BASELINE, §3 QUYẾT ĐỊNH KIẾN TRÚC, §4 TIẾN ĐỘ, §5 KNOWN ISSUES, §6 CHECKPOINT), `TASK_INDEX.md`, `TASK-000..017.md`, `FINAL_AUDIT.md`.
- **Chưa có** `docs\update\`, chưa có `version.json`, chưa có `updater/`, chưa có `release/`.

### 4.2 Lệnh MTO hiện có (24, LISP) — KHÔNG được trùng
`MTOBLK MTOBLKMAN MTOCFG MTOCSV MTODED MTOFIND MTOFLOOR MTOFORMULA MTOGEO MTOGOTO MTOHELP MTOLIST MTOORPHAN MTOSEL MTOSNAP MTOSNAPSHOW MTOSUB MTOTABLE MTOTESTNATIVE MTOTEXT MTOTITLE MTOUNDO MTOUPDATE MTOXCHECK` (+`MTOZOOM` ở nhánh .NET).
⚠️ **`MTOUPDATE` ĐÃ BỊ CHIẾM** (TASK-011: "cập nhật ngược data TEXT/MTEXT + XData vào bản vẽ") → prompt gốc dùng `MTOUPDATE` cho self-update là **SAI**. Đã đổi sang mục 2K. Trước khi define một command mới phải `grep` toàn repo.

### 4.3 Version đang LỆCH nhau (lý do phải single-source)
| Nơi | Giá trị |
|---|---|
| `lisp\mto-loader.lsp` | `*MTO-VERSION* "0.6.0-lisp"` (hằng cứng) |
| `scripts\build-lisp-installer.ps1` | `-Version default 1.0.0` |
| `installer\mto.iss` | `AppVersion "0.1.0"` |
| `installer\bundles\...\PackageContents.xml` | `AppVersion "0.1.0"` |

→ Quyết định cho prompt này: **baseline module = `1.0.0`** (semantic, khởi điểm cho update). Gộp tất cả về 1 nguồn duy nhất.

### 4.4 Cơ chế deploy & load (để thiết kế kích hoạt cho đúng)
- **Bộ cài chính (khuyến dùng)**: `build-lisp-installer.ps1` đóng payload {lisp/ (17 file), config/, docs/, tools/}, optional `dll/` (MTOPlugin net48 + Core/UI/Logging + Newtonsoft.Json + EPPlus) nhúng vào EXE build bằng `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe` từ `InstallerLisp.cs` → `output\MTOPro.Setup-<version>.exe`.
- **Thư mục cài để**: `%LOCALAPPDATA%\MTOPro\` (lisp/, config/, docs/, tools/, dll/). Cấu hình user tại `%LOCALAPPDATA%\MTOPro\config\` (rules.json ưu tiên 1, rules.sample.json, .mtocfg, DANH_MUC_VAT_TU.xlsx).
- **Nhánh bundle .NET** (phụ): `%APPDATA%\Autodesk\ApplicationPlugins\MTOPlugin.<grp>.bundle\Contents\Windows\MTOPlugin.dll` (net48) tự load khi AutoCAD khởi động; plugin `.NET` set `*MTO-HOME*` rồi `(load "mto-loader.lsp")` qua `SendStringToExecute`, đồng thời thêm thư mục lisp vào TRUSTEDPATHS.
- **Loader**: `mto-loader.lsp` tự nạp toàn bộ 17 module (+ loader); version in ra màn hình. Nếu thêm module mới → thêm vào `*MTO-MODULES*`.
- ⚠️ **Hệ quả cho activation**: DLL .NET đang load sẽ bị khóa → **không thể swap DLL khi AutoCAD đang mở**. Kích hoạt phải là "kích hoạt ở session kế tiếp" (đánh dấu staging → yêu cầu restart AutoCAD → session mới auto-detect). LISP hoàn toàn có thể hot-reload bằng `(load)` sau khi swap file LISP. Thiết kế atomic activation phải tôn trọng điều này.

### 4.5 Giới hạn kỹ thuật (để chọn đúng giải pháp, không "bịa")
- **LISP thuần KHÔNG có HTTP và KHÔNG có SHA256**.
- Môi trường xác thực: chỉ có AutoCAD 2023 net48 (R24.2). `certutil.exe` có sẵn trên Windows (dùng `certutil -urlcache -f -split <url> <file>` để tải + `certutil -hashfile <file> SHA256` để băm) — KHÔNG chỉ lệnh không tồn tại.
- Các quyết định này (certutil vs .NET helper vs bootstrap EXE) ghi vào `UPDATE_ARCHITECTURE.md`, không hỏi lại, nhưng phải nêu rõ phương án + lý do.

---

## 5. DANH SÁCH ĐẦU RA (DELIVERABLES)

1. `MTOPlugin\version.json` (nguồn sự thật) + cơ chế để LISP/installer/bundle đọc cùng 1 nguồn.
2. `MTOPlugin\lisp\mto-selfup.lsp` (logic thuần LISP testable: đọc version local, so sánh semver, quyết định action, backup/stage bookkeeping, ghi log) + thêm vào `*MTO-MODULES*`.
3. `MTOPlugin\lisp\tests\test-selfup.lsp` (+ test-gate: LINT, LOAD-CHECK, headless).
4. Bootstrap updater: `MTOPlugin\installer\updater\` (source + build script theo pattern csc) — tải/verify/swap độc lập với LISP đang chạy.
5. `MTOPlugin\config\update.sample.json`.
6. `MTOPlugin\release\manifest.json` + `release\1.0.0\{package.zip, manifest.json}` (sinh bởi script).
7. Scripts: `scripts\publish-update.ps1` (đóng gói release + băm SHA256 + sinh manifest), tái sử dụng/mở rộng `scripts\verify-package.ps1`, nâng `scripts\build-lisp-installer.ps1` để nhúng updater + version.json.
8. Tài liệu `MTOPlugin\docs\update\`:
   - `UPDATE_ARCHITECTURE.md` (kiến trúc + quyết định đã chốt)
   - `RELEASE_PROCESS.md`, `INSTALLATION.md`, `ROLLBACK.md`, `UPDATE_TROUBLESHOOTING.md`.
9. Test TEST-01..16 (bảng test chi tiết trong `UPDATE_ARCHITECTURE.md` hoặc `docs\update\UPDATE_TEST_CASES.md`; mỗi test phải có cách chạy cụ thể + kết quả thật).
10. Cập nhật: `MASTER_STATUS.md` (§1 bổ sung module, §4, §6), `TASK_INDEX.md` (TASK-018+), `FINAL_AUDIT.md` (ghi nhận module update), `MTOPlugin\docs\` tham chiếu.

---

## 6. TEST — TEST-01..16 (tối thiểu, giữ nguyên bản gốc)

| ID | Nội dung |
|---|---|
| TEST-01 | Đọc local version.json khi thiếu/lỗi → fallback rõ ràng |
| TEST-02 | Parse manifest remote (đủ field) |
| TEST-03 | So sánh version: mới hơn / bằng / cũ hơn / cùng version→no-op |
| TEST-04 | `mandatory=true` chặn tiếp tục + thông báo; `optional` hỏi |
| TEST-05 | Lỗi mạng → graceful, không crash, log đầy đủ, retry |
| TEST-06 | Download sai SHA256 → từ chối kích hoạt |
| TEST-07 | Verify cấu trúc payload thiếu file → từ chối |
| TEST-08 | Backup đúng, giữ KEEP_BACKUPS=3 |
| TEST-09 | Stage → Activate → Validate OK → active mới |
| TEST-10 | Activate/Validate lỗi → Rollback về bản cũ còn nguyên |
| TEST-11 | User data (config/rules/DWG/template) không bị đụng |
| TEST-12 | Cập nhật LISP nóng (hot reload) thành công |
| TEST-13 | Bản DLL yêu cầu restart → marker chờ session kế, tự kích hoạt |
| TEST-14 | MTOVERSION / MTOUPGRADECHECK / MTOUPGRADE đúng hành vi |
| TEST-15 | Release pipeline sinh package.zip + sha256 + manifest khớp nhau |
| TEST-16 | Log không chứa credential; HTTPS enforced |

Mỗi TEST: ghi tên file test / lệnh chạy / kết quả thật vào checkpoint. Test LISP thuần chạy headless accoreconsole; phần network/swap có thể test bằng nguồn file:// cục bộ + chứng minh bằng log/vết kiểm tra (không giả PASS).

---

## 7. DSH EXECUTION RULE (bắt buộc)

1. **Audit trước khi viết code**: đọc `MASTER_STATUS.md`, `TASK_INDEX.md`, `mto-loader.lsp`, `mto-config.lsp`, `build-lisp-installer.ps1`, `InstallerLisp.cs`, `check-lisp-syntax.ps1`, `run-tests.ps1`. Xác minh: entry point LISP, cơ chế load, packaging, .NET wrapper, config, AutoCAD target.
2. **KHÔNG rewrite MTO**: chỉ thêm module update. Nhánh `.NET` hiện có giữ nguyên, không xóa wiring.
3. **Cứu vào kiến trúc thực tế** (mục 4), không tự bịa đường dẫn/command.
4. Viết `UPDATE_ARCHITECTURE.md` trước (mục 2.2 + quyết định 4.4/4.5), rồi `TASK_INDEX` bổ sung TASK-018+, rồi TODO, rồi triển khai từng task.
5. Không hỏi lại thông tin đã có trong repo. Task nào thiếu thông tin → **BLOCK task đó** (ghi rõ vào §5/§6) và tiếp tục task độc lập.
6. Sau mỗi task: cập nhật `MASTER_STATUS` §4 + §6 + `TASK_INDEX`, gửi 2 bản tin Telegram (mục 3), không kết thúc session khi TODO empty.
7. Report theo định dạng Telegram `[MTO UPDATE]` với `Version / Task / Status / Completed / Test / Next` tại: bắt đầu phase, hoàn thành task, blocker, test failure, release build xong, publish xong, hoàn thành (architecture doc), hoàn thành (rollback test). KHÔNG spam từng file. Nếu chưa cấu hình Telegram → ghi `BLOCKED` trong checkpoint §6, KHÔNG tạo token giả.

---

## 8. ĐỊNH NGHĨA HOÀN THÀNH (Definition of Done — 15 điều)

1. `version.json` là nguồn phiên bản duy nhất; toàn bộ chỗ khác đọc từ đó.
2. Lệnh mới (MTOUPGRADECHECK / MTOUPGRADE / MTOVERSION) hoạt động, không trùng command hiện có.
3. Auto-check ngày khởi động, non-blocking, optional/mandatory đúng luật.
4. Chuỗi Download → Verify SHA256 → Verify cấu trúc → Backup → Stage → Activate → Validate → Rollback có code + test thật.
5. Kích hoạt nguyên tử: DLL cần restart, LISP hot-reload.
6. KEEP_BACKUPS=3, rollback 1 lệnh.
7. User data an toàn (config/rules/.mtocfg/DWG/template/DANH_MUC_VAT_TU.xlsx) — có test.
8. `update.sample.json` ship; runtime không ghi đè config user.
9. `logs\update.log` đầy đủ, không credential.
10. HTTPS; không token/password/private key trong source/package/log.
11. `docs\update\*` (5 tài liệu) hoàn chỉnh.
12. TEST-01..16 PASS hoặc ghi rõ blocker + lý do.
13. `publish-update.ps1` sinh package + sha256 + manifest nhất quán; `verify-package.ps1` chạy OK.
14. Toàn bộ 617 test LISP hiện có VẪN PASS (không hồi quy).
15. `MASTER_STATUS` §4/§6, `TASK_INDEX`, `FINAL_AUDIT` cập nhật đầy đủ; Telegram báo hoàn thành.

---

## 9. START NOW

1. Đọc các file audit (mục 7.1). Chạy nhanh `lisp\tests\run-tests.ps1` để xác nhận baseline 617 test PASS.
2. `todo_write` khởi tạo danh sách task module update.
3. Viết `docs\update\UPDATE_ARCHITECTURE.md` (mục 2.2 + quyết định từ 4.3/4.4/4.5) — gửi Telegram `[MTO UPDATE]` khi xong.
4. Thêm TASK-018+ vào `TASK_INDEX.md` và `MASTER_STATUS` §4 (mới = "PHASE UPGRADE").
5. Triển khai lần lượt: version.json single-source → mto-selfup.lsp + test → bootstrap updater → manifest/publish → config update.json → commands → docs → TEST-01..16.
6. Sau mỗi task: 2 bản tin Telegram + checkpoint §4/§6. Không kết thúc session khi TODO còn việc.