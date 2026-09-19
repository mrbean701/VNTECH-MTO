# TASK_INDEX.md — Danh mục task MTO (LISP-first)

> Nguồn sự thật cho việc "task nào tiếp theo". Cập nhật sau mỗi task.
> Cập nhật lần cuối: 2026-09-18

---

## Trạng thái ký hiệu

| Ký hiệu | Nghĩa |
|---|---|
| ✅ DONE | Code + test + checkpoint đầy đủ |
| 🔄 IN PROGRESS | Đang làm |
| ⏳ TODO | Chưa bắt đầu |
| 🚫 BLOCKED | Không thể tiếp tục, có lý do ghi rõ |

---

## PHASE 0 — AUDIT & BASELINE

| ID | Task | File chính | Test | Trạng thái | Checkpoint |
|---|---|---|---|---|---|
| TASK-000 | Audit repository, xác lập baseline, tạo checkpoint dir | `docs/agent-progress/*` | Kiểm chứng `accoreconsole` chạy LISP | ✅ DONE | `TASK-000.md` |

---

## PHASE 1 — CORE LISP MTO (ưu tiên cao nhất)

| ID | Task | File chính | Test | Trạng thái | Phụ thuộc |
|---|---|---|---|---|---|
| TASK-001 | Interactive Selection (Window/Crossing/Polygon + layer filter) | `lisp/mto-select.lsp` | **32/32 PASSED** | ✅ DONE | TASK-005 |
| TASK-002 | Text Prefix Recognition (TEXT/MTEXT → PREFIX→CATEGORY→TYPE) | `lisp/mto-text.lsp` | **40/40 PASSED** | ✅ DONE | TASK-005 |
| TASK-003 | Block Recognition & Counting (auto + manual adjust) | `lisp/mto-block.lsp` | **41/41 PASSED** | ✅ DONE | TASK-005 |
| TASK-004 | Geometry Quantity (LINE/LWPOLYLINE SumLength + layer filter) | `lisp/mto-geometry.lsp` | **31/31 PASSED** | ✅ DONE | TASK-005 |
| TASK-005 | Unified Quantity Data Model | `lisp/mto-core.lsp` | **45/45 PASSED** | ✅ DONE | — |
| TASK-006 | Result List (hiển thị bảng kết quả) | `lisp/mto-result.lsp` | **30/30 PASSED** | ✅ DONE | TASK-001..005 |
| TASK-007 | CSV Export (open/write-line/close) | `lisp/mto-csv.lsp` | **26/26 PASSED** | ✅ DONE | TASK-005 |
| TASK-008 | Orphan Detection (handent) | `lisp/mto-orphan.lsp` | **27/27 PASSED** | ✅ DONE | TASK-005 |
| LOADER | Loader đóng gói 1 lệnh + MTOHELP | `lisp/mto-loader.lsp` | **24/24 PASSED** | ✅ DONE | — |

**Thứ tự thực thi đã điều chỉnh:** TASK-005 (data model) làm TRƯỚC vì mọi task khác phụ thuộc nó.

---

## PHASE 2 — INTERACTIVE MTO TABLE

| ID | Task | File chính | Test | Trạng thái | Phụ thuộc |
|---|---|---|---|---|---|
| TASK-009 | AutoCAD Table (+ subtotal Category/Type) | `lisp/mto-table.lsp` | **38/38 PASSED** | ✅ DONE | TASK-006 |
| TASK-010 | Find / Zoom Back (bảng → handle → zoom) | `lisp/mto-find.lsp` | **32/32 PASSED** | ✅ DONE | TASK-009 |
| TASK-011 | Batch Update (update ngược TEXT/MTEXT/XData) | `lisp/mto-update.lsp` | **34/34 PASSED** | ✅ DONE | TASK-009 |
| TASK-012 | Plugin Undo/Restore (snapshot HANDLE→OLD VALUE) | `lisp/mto-undo.lsp` | **28/28 PASSED** | ✅ DONE | TASK-011 |
| LINT | Lint cú pháp + load-check (chặn lỗi cú pháp lọt qua) | `lisp/tests/check-lisp-syntax.ps1` | **27 file OK** | ✅ DONE | — |

---

## PHASE 3 — CALCULATION & GROUPING

| ID | Task | File chính | Test | Trạng thái | Phụ thuộc |
|---|---|---|---|---|---|
| TASK-013 | Custom Formula (SL × hệ số, dài × hệ số, KL × đơn giá) | `lisp/mto-formula.lsp` | **62/62 PASSED** | ✅ DONE | TASK-005 |
| TASK-014 | Subtotal & Deduction (generic theo khoá) | `lisp/mto-subtotal.lsp` | **33/33 PASSED** | ✅ DONE | TASK-013 |

---

## PHASE 4 — FLOOR / DRAWING CONFIGURATION

| ID | Task | File chính | Test | Trạng thái | Phụ thuộc |
|---|---|---|---|---|---|
| TASK-015 | Floor / Area / Zone + filter + subtotal | `lisp/mto-floor.lsp` | **43/43 PASSED** | ✅ DONE | TASK-014 |
| TASK-016 | Per-Drawing Configuration (file .mtocfg + NOD/XRecord) | `lisp/mto-config.lsp` | **34/34 PASSED** | ✅ DONE | TASK-015 |

---

## PHASE 5 — .NET EXTENSION (chỉ khi LISP không phù hợp)

| ID | Task | File chính | Test | Trạng thái | Phụ thuộc |
|---|---|---|---|---|---|
| TASK-017 | .NET Extension — build **net48** cho AutoCAD 2023 + NETLOAD + command chạy | `src/MTOPlugin/MtoCompat.cs` (+3 file) | Build 0 lỗi · NETLOAD OK · MTOZOOM chạy | ✅ DONE | TASK-016 |
| FINAL | Final audit đối chiếu MASTER GOAL | `docs/agent-progress/FINAL_AUDIT.md` | **19/19 mục ✅** | ✅ DONE | tất cả |

---

## NGUYÊN TẮC CHỌN TASK TIẾP THEO

1. Task có phụ thuộc đã DONE.
2. Ưu tiên PHASE thấp trước (PHASE 1 → 5).
3. Nếu task bị BLOCKED, chuyển sang task độc lập cùng phase, ghi rõ lý do.
4. Không đánh dấu DONE nếu chưa có test chạy thật.

---

## HARNESS TEST

```powershell
# Chạy toàn bộ selftest LISP headless
.\lisp\tests\run-tests.ps1

# Chạy trên DWG mẫu cụ thể
.\lisp\tests\run-tests.ps1 -Dwg "D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023\Sample\Electrical Power.dwg"
```

Kết quả kỳ vọng: dòng `TEST-PASS: <tên>` cho từng case, tổng kết `TESTS: n/n PASSED`.
