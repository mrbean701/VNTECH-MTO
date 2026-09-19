# TASK-012 — Plugin Undo / Restore

**Phase:** PHASE 2
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-011 (set/get giá trị), TASK-010 (resolve handle)

---

## Objective

Không phụ thuộc hoàn toàn vào `UNDO` của AutoCAD. Trước khi batch update:
**snapshot `HANDLE → OLD VALUE`**; sau đó cho phép `MTOUNDO` khôi phục dữ liệu về
trạng thái trước thao tác. Chỉ áp dụng cho dữ liệu LISP kiểm soát được (TEXT/MTEXT).

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-undo.lsp` | Tạo mới |
| `lisp/tests/test-undo.lsp` | Tạo mới — 28 test case |
| `docs/agent-progress/TASK-012.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-undo-capture-entity` | `(handle . giá-trị-cũ)` hoặc `nil` |
| `mto-undo-snapshot` / `-many` | Chụp snapshot từ 1 / nhiều item |
| `mto-undo-count` | Số entry |
| `mto-undo-save` / `-load` / `-clear` | Trạng thái snapshot phiên (`*MTO-UNDO*`) |
| `mto-undo-restore-list` | Khôi phục 1 snapshot → `(OK . FAIL)` |
| `mto-undo-restore` | Khôi phục snapshot phiên |
| `mto-undo-describe` | Mô tả snapshot |
| `mto-upd-batch-safe` | **Batch có snapshot tự động** (chụp trước, rồi update) |

Lệnh `MTOSNAP` (chụp), `MTOUNDO` (khôi phục, hỏi Y/N), `MTOSNAPSHOW` (xem).

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-undo.lsp"
```

## Test result

**PASS — 28/28**

```
TESTS: 28/28 PASSED
RESULT: ALL-PASS
```

Test **sửa thật rồi khôi phục thật**, và **đọc lại từ bản vẽ** để xác nhận giá trị
đã về đúng trạng thái gốc; kiểm cả nhánh thất bại (handle mồ côi vẫn đếm FAIL).

---

## Bug thật đã phát hiện & sửa

Không phát sinh bug mới ở task này (dùng lại hạ tầng đã kiểm chứng của TASK-010/011).

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | **XData KHÔNG được khôi phục** (chỉ nội dung TEXT/MTEXT) — đã ghi rõ trong lệnh và tài liệu | Trung bình |
| I2 | Snapshot chỉ trong **phiên hiện tại** (chưa ghi ra file để khôi phục sau khi đóng bản vẽ) | Trung bình |
| I3 | Chưa giới hạn kích thước snapshot (bản vẽ rất lớn có thể tốn bộ nhớ) | Thấp |
| I4 | Chưa có nhiều mức undo (chỉ 1 snapshot gần nhất) | Thấp |

---

## Next task

**TASK-013 — Custom Formula** (`lisp/mto-formula.lsp`) — bắt đầu PHASE 3.
