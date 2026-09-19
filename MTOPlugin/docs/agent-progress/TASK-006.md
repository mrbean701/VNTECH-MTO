# TASK-006 — Result List

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model)

---

## Objective

Hiển thị danh sách kết quả dạng **bảng** (không chỉ một dòng tổng kết), làm input cho
AutoCAD Table (TASK-009) và CSV (TASK-007).

Cột: `CATEGORY | TYPE | NAME | QTY | LENGTH | UNIT`

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-result.lsp` | Tạo mới |
| `lisp/tests/test-result.lsp` | Tạo mới — 30 test case |
| `docs/agent-progress/TASK-006.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-res-spaces` | Chuỗi n khoảng trắng |
| `mto-res-pad` | Căn cột (tự trim, cắt nếu dài hơn) |
| `mto-res-header` | Dòng tiêu đề |
| `mto-res-sep` | Dòng phân cách |
| `mto-res-row` | Một dòng dữ liệu từ item |
| `mto-res-table` | Header + separator + toàn bộ dòng (đã sắp xếp) |
| `mto-res-stats` | Thống kê: ROWS / QTY / LENGTH / CATS |

Độ rộng cột khai báo tập trung tại `*MTO-RES-WIDTHS*` = `(14 14 32 10 12 8)`.

Lệnh `MTOLIST` — in bảng, lọc theo CATEGORY.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-result.lsp"
```

## Test result

**PASS — 30/30**

```
TESTS: 30/30 PASSED
RESULT: ALL-PASS
```

---

## Bug thật đã phát hiện & sửa

Không có bug module. **1 lỗi kỳ vọng của test**: tôi viết độ dài dòng = 13, thực tế
tổng độ rộng cột `14+14+32+10+12+8 = 90` cộng 5 khoảng cách = **95** → sửa kỳ vọng.

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Tên dài bị **cắt** ở 32 ký tự (không wrap) | Thấp |
| I2 | Chưa phân trang khi nhiều dòng | Thấp |
| I3 | Chưa có subtotal theo CATEGORY trong bảng | Trung bình — TASK-009/014 |

---

## Next task

**TASK-007 — CSV Export** (`lisp/mto-csv.lsp`)

Xuất CSV bằng `(open ...)` / `(write-line ...)` / `(close ...)`, không phụ thuộc Excel.
Tên file mặc định: `<drawing>_MTO_<YYYYMMDD_HHMMSS>.csv`.
