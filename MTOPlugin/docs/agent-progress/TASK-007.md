# TASK-007 — CSV Export

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-006 (bảng)

---

## Objective

Xuất kết quả ra **CSV** bằng AutoLISP thuần (`open` / `write-line` / `close`),
**không phụ thuộc Excel**, có header rõ ràng, tên file mặc định chứa tên bản vẽ + ngày giờ.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-csv.lsp` | Tạo mới |
| `lisp/tests/test-csv.lsp` | Tạo mới — 26 test case (ghi file THẬT, đọc lại kiểm) |
| `docs/agent-progress/TASK-007.md` | Tạo mới |

---

## Implementation

15 cột (`*MTO-CSV-COLUMNS*`): Category, Type, Name, Spec, Description, Layer,
AutoQty, ManualQty, FinalQty, Length, Unit, Prefix, SourceType, Handles, Notes.

| Hàm | Chức năng |
|---|---|
| `mto-csv-escape` | Escape RFC4180: bọc `"` + nhân đôi `"` khi có `,` `;` `"`; loại bỏ xuống dòng |
| `mto-csv-header` | Dòng tiêu đề |
| `mto-csv-row` | Một dòng dữ liệu (handle nối bằng `\|`) |
| `mto-csv-lines` | Header + toàn bộ dòng (đã sắp xếp) |
| `mto-csv-write` | Ghi file, trả `T`/`nil` |
| `mto-csv-default-name` | `<DWGNAME>_MTO_<YYYYMMDD_HHMMSS>.csv` |

Lệnh `MTOCSV`.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-csv.lsp"
```

## Test result

**PASS — 26/26**

```
TESTS: 26/26 PASSED
RESULT: ALL-PASS
```

Test **ghi file CSV thật**, rồi **đọc lại bằng `read-line`** và kiểm nội dung
(số dòng, giá trị tiếng Việt/số, thứ tự sắp xếp) — không chỉ kiểm hàm thuần.

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B8 | Tên file mặc định **không cắt** đuôi `.dwg` | `(strcase dwg)` trả **CHỮ HOA**, rồi tìm `".dwg"` (chữ thường) ⇒ không bao giờ khớp | So sánh 4 ký tự cuối bằng `(strcase ...)` cả hai vế |
| B9 | Xuống dòng thành **2 khoảng trắng** | Literal `"\n"` trong AutoLISP sinh **CR+LF** (2 ký tự) ⇒ `vl-string-translate` thay 2 lần | Thay cặp `"\r\n"` → 1 khoảng trắng **trước**, rồi mới translate `\r`/`\n` còn lại |
| B10 | `vl-string-translate` với src/dst **khác độ dài** (10 vs 12) | Hằng chuỗi đếm sai | Sửa dst thành đúng 10 ký tự `"__________"` |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Chưa có tuỳ chọn chọn cột / thứ tự cột | Thấp |
| I2 | Chưa hỗ trợ xuất "chỉ các dòng đang chọn" (hiện xuất toàn DB) | Trung bình |
| I3 | Chưa có BOM UTF-8 (Excel mở có thể lệch dấu tiếng Việt) | Trung bình — cần cho bàn giao |
| I4 | Dấu phân cách luôn là `,` (chưa hỗ trợ `;` cho locale vi-VN) | Thấp |

---

## Next task

**TASK-008 — Orphan Detection** (`lisp/mto-orphan.lsp`)
