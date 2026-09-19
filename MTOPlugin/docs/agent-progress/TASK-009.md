# TASK-009 — AutoCAD Table

**Phase:** PHASE 2
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-006 (rows/bảng)

---

## Objective

Tạo bảng trên bản vẽ từ dataset: `STT | CATEGORY | TYPE | DESCRIPTION | QTY | LENGTH | UNIT | LAYER | NOTES`,
kèm **SUBTOTAL theo CATEGORY** và **GRAND TOTAL**.

---

## Phát hiện kỹ thuật quan trọng (dẫn tới thiết kế 2 backend)

`accoreconsole` **KHÔNG có ActiveX**: `vlax-get-acad-object`, `vlax-3d-point`,
`vla-AddTable` đều trả `no function definition` / `bad function`.
Nhưng AutoCAD đầy đủ **có** ActiveX.

⇒ Nếu chỉ dùng `vla-AddTable` thì **không test được headless** (không thể chứng minh PASS).

**Thiết kế chọn:** 2 backend, tự chọn theo môi trường
| Backend | Công nghệ | Môi trường | Test headless |
|---|---|---|---|
| NATIVE | `vla-AddTable` (ActiveX) | AutoCAD đầy đủ | ✗ (ghi nhận limitation) |
| GRID | `entmake` TEXT + LINE | mọi nơi, kể cả accoreconsole | ✓ |

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-table.lsp` | Tạo mới |
| `lisp/tests/test-table.lsp` | Tạo mới — 38 test case |
| `docs/agent-progress/TASK-009.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-table-columns` / `mto-table-total-width` | Định nghĩa 9 cột (tổng 126.0 đơn vị) |
| `mto-table-header-cells` | Tiêu đề |
| `mto-table-item-cells` | Ô của một item (9 ô) |
| `mto-table-subtotal-by` | Subtotal theo khoá (mặc định CATEGORY) |
| `mto-table-build-rows` | Header + data + subtotal + grand total, mỗi dòng có nhãn `H/D/S/G` |
| `mto-table-cell-point` | Toạ độ ô `[row][col]` |
| `mto-table-grid-entities` | **Mô tả** số entity grid sẽ tạo (khớp hành vi vẽ) |
| `mto-table-draw-grid` | Vẽ grid thật (TEXT + LINE) |
| `mto-table-activex-available-p` | Dò ActiveX |
| `mto-table-add-native` | Tạo native table, `nil` nếu không có ActiveX |

Lệnh `MTOTABLE`.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-table.lsp"
```

## Test result

**PASS — 38/38**

```
TESTS: 38/38 PASSED
RESULT: ALL-PASS
```

Test **vẽ grid thật** rồi `ssget` đếm entity trên bản vẽ (18 LINE, 38 TEXT) và
đối chiếu với hàm mô tả — không chỉ kiểm logic thuần.

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B12 | `bad argument type: consp "G"` | **`(last lst)` trong AutoLISP trả PHẦN TỬ cuối**, không phải list con (khác Common Lisp) ⇒ `(car (last rows))` là `"G"`, rồi `(car "G")` lỗi | Dùng `(car (last rows))` và `(cdr (last rows))` |
| B13 | Hàm **mô tả** 63 TEXT nhưng hàm **vẽ** chỉ 38 ⇒ không nhất quán | Mô tả đếm mọi ô, vẽ chỉ vẽ ô có nội dung | Sửa `mto-table-grid-entities` đếm ô non-empty; test kiểm `mô tả = thực vẽ` |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Backend NATIVE (ActiveX) **không kiểm chứng được headless** — cần AutoCAD đầy đủ để xác nhận | Trung bình (đã có fallback GRID) |
| I2 | Grid: chữ dài hơn cột **không tự wrap** | Thấp |
| I3 | Grid tạo nhiều entity (bảng 100 dòng ≈ 900 TEXT + 110 LINE) — có thể chậm | Thấp |
| I4 | Chưa cho chọn cột khi tạo bảng | Thấp |

---

## Next task

**TASK-010 — Find / Zoom Back** (`lisp/mto-find.lsp`)
