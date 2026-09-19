# MASTER GOAL — MTO "Offline Package + Online Update System"

> Dùng file này làm **GOAL** (session goal) cho deepseek harness (dsh).
> Đi kèm với `UPGRADE_MASTER_PROMPT_OPTIMIZED.md` (IMPLEMENTATION PROMPT) — harness pải đọc cả hai.
> Luật ràng buộc: `AGENTS.md` ở workspace root `quantity take-off`.

---

## SỨ MỆNH

Triển khai **module "Đóng gói offline (Offline Package) + Hệ thống cập nhật tập trung qua mạng (Centralized Online Update)"** cho **MTOPro** — plugin AutoCAD bóc tách khối lượng M&E (Điện / Nước / Điện nhẹ ELV), kiến trúc **LISP-first**.

Core MTO đã **HOÀN THÀNH 19/19 mục + 617 test LISP PASS** (xem `MTOPlugin\docs\agent-progress\MASTER_STATUS.md`, `FINAL_AUDIT.md`). Module này là **PHASE MỚI (UPGRADE)**, **KHÔNG rewrite / KHÔNG phá code hiện có** — chỉ THÊM:

1. Client cập nhật trong bộ cài MTOPro (kiểm tra phiên bản, tải về, xác minh SHA256, backup, kích hoạt an toàn, rollback).
2. Pipeline đóng gói release + manifest + nguồn cập nhật (UpdateSource: Git nội bộ / HTTP(S) / NAS / folder cục bộ = offline mirror).
3. Tài liệu `MTOPlugin\docs\update\` (5 tài liệu) + toàn bộ test TEST-01..16.
4. Chuyển mọi nơi ghi phiên bản về **MỘT nguồn duy nhất** (`MTOPlugin\version.json`, baseline **1.0.0**).

## NGUYÊN TẮC BẮT BUỘC

- **LISP-first**: logic lõi của module viết bằng AutoLISP (`mto-selfup.lsp`), test headless trên `accoreconsole.exe` (AutoCAD 2023, ACADVER 24.2). Không chuyển logic sang .NET chỉ vì tiện.
- **Không trùng lệnh**: `MTOUPDATE` đã bị chiếm (TASK-011) → module dùng `MTOUPGRADE`, `MTOUPGRADECHECK`, `MTOVERSION`. Phải `grep` toàn repo trước khi thêm command mới.
- **An toàn dữ liệu user tuyệt đối**: không bao giờ xóa/ghi đè DWG, `config\rules.json`, `config\update.json`, `.mtocfg`, `DANH_MUC_VAT_TU.xlsx`, template, dữ liệu xuất.
- **SHA256 bắt buộc**, backup giữ `KEEP_BACKUPS=3`, kích hoạt nguyên tử (current/staging/backup), DLL cần restart session, LISP hot-reload.
- **Security**: chỉ HTTPS, không token/password/private key trong source/package/log.
- Nhánh `.NET` hiện có (`src\MTOPlugin*`) giữ nguyên, không xóa wiring.

## QUẢN LÝ TIẾN ĐỘ (BẮT BUỘC MỖI TASK)

1. Gọi `todo_write` ngay khi nhận việc; cập nhật `in_progress → completed` đúng lúc, gửi lại toàn bộ danh sách.
2. Sau mỗi task: cập nhật `MASTER_STATUS.md` **§4 (tiến độ)** + **§6 (nhật ký checkpoint)** và `TASK_INDEX.md` (thêm TASK-018+ ở "PHASE UPGRADE").
3. **KHÔNG kết thúc session khi TODO empty** — luôn tạo task tiếp theo cho đến khi DoD hoàn tất.

## BÁO CÁO TELEGRAM (ĐÚNG 2 BẢN TIN / TASK)

- Bắt đầu task: `🛠 Bắt đầu task <TASK-ID>: Đang làm ...`
- Hoàn thành: `✅ Vừa hoàn thành <TASK-ID>: ... · Test: <PASS/FAIL> · Tiến độ: <task done/total>`
- Mốc phase/blocker/release/publish → định dạng `[MTO UPDATE]` với `Version / Task / Status / Completed / Test / Next`.
- Dùng tool `notify` của harness; chưa cấu hình Telegram → ghi `BLOCKED` vào §6, **không tạo token giả**.

## CỔNG TEST THẬT (KHÔNG GIẢ PASS)

1. LINT: `lisp\tests\check-lisp-syntax.ps1`
2. LOAD-CHECK: load `mto-loader.lsp` headless bằng `accoreconsole.exe` (`D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe`, output UTF-16LE)
3. Test suite: 617 test LISP hiện có **vẫn PASS** + TEST-01..16 của module update.

## ĐỊNH NGHĨA HOÀN THÀNH (TÓM TẮT)

- `version.json` là nguồn phiên bản duy nhất (baseline 1.0.0).
- 3 lệnh mới hoạt động đúng, không trùng command.
- Luồng Download → Verify SHA256 → Verify cấu trúc → Backup → Stage → Activate → Validate → Rollback có code + test thật; kích hoạt nguyên tử; KEEP_BACKUPS=3; rollback 1 lệnh.
- User data an toàn (có test); log không credential; HTTPS.
- `docs\update\` đủ 5 tài liệu; TEST-01..16 PASS hoặc blocker rõ lý do.
- Release pipeline (`publish-update.ps1` + `verify-package.ps1`) nhất quán package/sha256/manifest.
- 617 test cũ không hồi quy; `MASTER_STATUS` §4/§6 + `TASK_INDEX` + `FINAL_AUDIT` cập nhật; Telegram báo hoàn thành.

## ĐẦU RA CỤ THỂ

```
MTOPlugin\version.json                      # nguồn phiên bản duy nhất
MTOPlugin\lisp\mto-selfup.lsp               # logic cập nhật thuần LISP (+ vào *MTO-MODULES*)
MTOPlugin\lisp\tests\test-selfup.lsp        # test module
MTOPlugin\installer\updater\*               # bootstrap updater (pattern csc như InstallerLisp.cs)
MTOPlugin\config\update.sample.json         # cấu hình mẫu
MTOPlugin\release\{manifest.json, 1.0.0\{package.zip, manifest.json}}
MTOPlugin\scripts\publish-update.ps1        # đóng gói + băm + sinh manifest
MTOPlugin\docs\update\{UPDATE_ARCHITECTURE,RELEASE_PROCESS,INSTALLATION,ROLLBACK,UPDATE_TROUBLESHOOTING}.md
MASTER_STATUS.md §1/§4/§6 + TASK_INDEX + FINAL_AUDIT   # cập nhật sau mỗi task
```

## BẮT ĐẦU

1. Audit repo (doc: `UPGRADE_MASTER_PROMPT_OPTIMIZED.md` mục 4 — đã audit sẵn, dùng làm nền).
2. Xác nhận baseline 617 test PASS.
3. Viết `UPDATE_ARCHITECTURE.md` → thêm TASK-018+ → triển khai tuần tự → TEST-01..16 → DoD → báo xong.