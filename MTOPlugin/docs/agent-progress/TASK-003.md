# TASK-003 — Block Recognition & Counting

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-002 (prefix/category), TASK-001 (ssget)

---

## Objective

Chọn block mẫu → lấy tên → đếm **toàn bộ** block cùng tên. Kèm **MANUAL COUNT** cho
số lượng ngoài bản vẽ, theo công thức `TOTAL = AUTO_COUNT + MANUAL_ADJUSTMENT`,
lưu rõ **AutoCount / ManualCount / FinalCount**.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-block.lsp` | Tạo mới |
| `lisp/tests/test-block.lsp` | Tạo mới — 41 test case (block definition + INSERT thật) |
| `docs/agent-progress/TASK-003.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-blk-name` | Tên block từ entity (DXF 2) |
| `mto-blk-anonymous-p` | Phát hiện block ẩn danh (`*U`, `*D`...) |
| `mto-blk-entity-p` | Entity là INSERT? |
| `mto-blk-build-filter` | DXF filter: `(0 . "INSERT")`, `(2 . name)`, `(8 . layer)` |
| `mto-blk-count` | Đếm theo tên (+ layer tuỳ chọn) |
| `mto-blk-handles` | Danh sách handle |
| `mto-blk-layers` | Phân bố layer của block (alist) |
| `mto-blk-classify` | Block → item (kèm prefix/category/unit) |
| `mto-blk-apply-manual` | Đặt MANQTY rồi tính lại (`QTY = AUTO + MANUAL`) |
| `mto-blk-add-manual` | Cộng dồn MANQTY |
| `mto-blk-scan` | Nạp 1 block vào DB |
| `mto-blk-count-all` | Đếm tất cả block, nhóm theo tên, **bỏ qua ẩn danh** |
| `mto-blk-scan-all` | Nạp tất cả block vào DB |
| `mto-db-merge-replace` | Thay thế 1 dòng theo key |

**Commands:** `MTOBLK` (chọn mẫu → đếm → nhập manual → lưu DB), `MTOBLKMAN` (điều chỉnh manual cho dòng có sẵn).

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-block.lsp"
```

## Test result

**PASS — 41/41**

```
TESTS: 41/41 PASSED
RESULT: ALL-PASS
```

Test tạo **block definition thật** (`entmake BLOCK/ENDBLK`) + **INSERT thật** trên 2 layer,
gồm cả block ẩn danh `*U99` để kiểm việc loại trừ.

**Regression:** core 45/45 · select 32/32 · text 40/40 — tất cả PASS.

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B7 | `mto-blk-classify` lưu **dotted pair** vào LAYER ⇒ lỗi `bad list: 4` khi in/đối chiếu | `(car (mto-blk-layers name))` trả về **phần tử alist** `("MTO-T3-EL" . 4)` (dotted pair), không phải tên layer | Dùng `(car (car layers))` (tức `caar`) để lấy khoá layer |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Dynamic block: chưa phân biệt tên hiệu dụng (EffectiveName) với tên định nghĩa | Trung bình — cần cho dynamic block thật |
| I2 | Chưa phát hiện block lồng trong block (nested) | Trung bình — ghi nhận |
| I3 | `mto-db-merge-replace` định nghĩa trong `mto-block.lsp` nhưng là tiện ích DB — nên chuyển sang `mto-core.lsp` | Thấp |
| I4 | Prefix của tên block như `MTO-DEN-DL` chưa khớp bảng prefix (token đầu là `MTO-DEN-DL`) ⇒ category có thể là `Other` | Thấp — cần map theo tiền tố tên block thực tế của công ty |

---

## Next task

**TASK-004 — Geometry Quantity** (`lisp/mto-geometry.lsp`)

Bóc chiều dài `LINE` / `LWPOLYLINE` (+ `POLYLINE`, `ARC`, `CIRCLE`) có lọc layer,
tính `SumLength`, thể hiện rõ **đơn vị** (không tự ý giả định nếu không xác định được).
