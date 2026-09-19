# TASK-004 — Geometry Quantity

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-002 (prefix/category), TASK-001 (filter)

---

## Objective

Bóc chiều dài `LINE` / `LWPOLYLINE` / `POLYLINE` / `ARC` / `CIRCLE` / `SPLINE` / `ELLIPSE`
có lọc layer, tính `SumLength`, và **thể hiện rõ đơn vị** — không tự ý giả định đơn vị
nếu bản vẽ không khai báo.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-geometry.lsp` | Tạo mới |
| `lisp/tests/test-geometry.lsp` | Tạo mới — 31 test case (LINE/LWPOLYLINE/ARC/CIRCLE thật) |
| `docs/agent-progress/TASK-004.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-geo-kind` | Loại hình học đo được (LINE/LWPOLYLINE/POLYLINE/ARC/CIRCLE/SPLINE/ELLIPSE) |
| `mto-geo-entity-p` | Có đo được chiều dài? |
| `mto-geo-length` | Chiều dài 1 đối tượng (dùng `vlax-curve-getDistAtParam` — đúng cho cả cung/bulge) |
| `mto-geo-insunits` | Đọc `INSUNITS` của bản vẽ |
| `mto-geo-unit-text` | Mã → chuỗi đơn vị (`?` khi không xác định) |
| `mto-geo-current-unit` | Đơn vị bản vẽ hiện tại |
| `mto-geo-total-length` | Tổng chiều dài selection set (+ đếm bỏ qua) |
| `mto-geo-scan-ss` | Quét → DB, **gom nhóm theo layer** |
| `mto-geo-handles` | Handle theo loại + layer |

Lệnh `MTOGEO`.

### Đơn vị — nguyên tắc

Bảng theo `INSUNITS` (20 mã). Nếu `INSUNITS = 0` (unitless) → đơn vị là `?`
và lệnh in **cảnh báo**, không tự suy diễn. Đơn vị được ghi vào `UNIT` của từng item.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-geometry.lsp"
```

## Test result

**PASS — 31/31**

```
TESTS: 31/31 PASSED
RESULT: ALL-PASS
```

Đo trên hình học tạo bằng `entmake`, kiểm bằng công thức giải tích:

| Đối tượng | Kỳ vọng | Kết quả |
|---|---|---|
| LINE (0,0)→(100,0) | 100 | ✅ |
| LWPOLYLINE (0,0)(100,0)(100,50) | 150 | ✅ |
| ARC r=50 nửa đường tròn | π·50 = 157.0796 | ✅ |
| CIRCLE r=10 | 2π·10 = 62.8319 | ✅ |
| TEXT | nil (không đo) | ✅ |

**Regression:** core 45/45 · select 32/32 · text 40/40 · block 41/41 — tất cả PASS.

---

## Bug thật đã phát hiện & sửa

Không phát sinh bug mới ở task này. Module chạy đúng ngay sau khi viết nhờ dùng
`vl-catch-all-apply` bọc `vlax-curve` (an toàn với đối tượng không phải curve).

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Gộp nhóm theo **layer** nên mọi loại hình học trên cùng layer thành 1 dòng; chưa tách theo loại (LINE vs ARC) | Trung bình — có thể thêm khoá nhóm theo `SOURCEOBJECT` |
| I2 | Chưa xử lý trừ chiều dài đoạn giao nhau (deduction) | Trung bình — thuộc TASK-014 |
| I3 | Chưa quét hình học nằm trong block (nested geometry) | Trung bình — ghi nhận |
| I4 | `mto-geo-scan-ss` gán `AUTOQTY = 1` cho mỗi đối tượng (nghĩa "đếm tuyến"), có thể gây nhầm với đếm số lượng | Thấp — ghi nhận |

---

## Next task

**TASK-006 — Result List** (`lisp/mto-result.lsp`)

Hiển thị danh sách kết quả dạng bảng `CATEGORY | TYPE | NAME | QTY | LENGTH | UNIT`
(chứ không chỉ in một dòng tổng kết), làm input cho Table (TASK-009) và CSV (TASK-007).
