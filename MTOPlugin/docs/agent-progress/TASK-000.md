# TASK-000 — Audit & Baseline

**Phase:** PHASE 0
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18

---

## Objective

Audit toàn bộ repository, xác định entry point / command / chức năng đã có và còn thiếu,
xác lập baseline kỹ thuật (đặc biệt: khả năng test LISP thật), tạo hạ tầng checkpoint.

---

## Files changed

| File | Hành động |
|---|---|
| `docs/agent-progress/MASTER_STATUS.md` | Tạo mới |
| `docs/agent-progress/TASK_INDEX.md` | Tạo mới |
| `docs/agent-progress/TASK-000.md` | Tạo mới (file này) |

Không sửa mã nguồn .NET (theo nguyên tắc không phá code hiện tại).

---

## Implementation

1. Glob tìm `*.lsp` trong toàn workspace → chỉ có `src/MTOPlugin/lisp/mto-commands.lsp`.
2. Đọc file LISP đó: 7 hàm `c:MTO/MTOSCAN/MTOEXPORT/MTOBANG/MTOZOOM/MTORULES/MTOSTATUS`
   — tất cả chỉ gọi `command "._X"` sang .NET, **không có logic MTO**.
3. Liệt kê `docs/` và `scripts/` → chưa có `docs/agent-progress/`.
4. Dò `accoreconsole.exe` trên các đường dẫn AutoCAD phổ biến → tìm thấy bản 2023.
5. Probe headless: chạy script in `ACADVER` → xác nhận hoạt động.
6. Ghi nhận kiến trúc hiện tại và quyết định tách nhánh LISP sang `MTOPlugin/lisp/`.

---

## Test performed

```powershell
$acad = "D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\accoreconsole.exe"
Set-Content probe.scr -Value '(princ (strcat "\nPROBE-OK acad=" (getvar "ACADVER")))'
& $acad /s probe.scr
```

## Test result

**PASS** — output chứa:

```
P R O B E - O K   a c a d = 2 4 . 2
```

(UTF-16LE, decode ra `PROBE-OK acad=24.2`)

Xác nhận: AutoCAD 2023 R24.2, AutoLISP chạy được headless.

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | .NET DLL hiện build `net8.0-windows` nhưng máy có AutoCAD 2023 (R24.2/net48) ⇒ không nạp được | Trung bình — ngoài phạm vi LISP-first, chuyển PHASE 5 |
| I2 | Console `accoreconsole` xuất UTF-16LE ⇒ harness test phải decode | Thấp — xử lý ở TASK-005/harness |
| I3 | Chưa có `docs/agent-progress/` trước task này | Đã xử lý |

---

## Next task

**TASK-005 — Unified Quantity Data Model** (`lisp/mto-core.lsp`)

Lý do đảo thứ tự: mọi task PHASE 1 (selection, text, block, geometry, result, CSV, orphan)
đều cần cấu trúc dữ liệu thống nhất trước. Làm data model trước để tránh viết lại 7 lần.

Sau đó: TASK-001 → TASK-002 → TASK-003 → TASK-004 → TASK-006 → TASK-007 → TASK-008.
