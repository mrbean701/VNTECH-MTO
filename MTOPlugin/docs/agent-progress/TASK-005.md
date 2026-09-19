# TASK-005 — Unified Quantity Data Model

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** —

---

## Objective

Tạo cấu trúc dữ liệu thống nhất cho kết quả MTO (item + database), làm nền cho mọi task
PHASE 1–4, kèm **hạ tầng test LISP chạy thật** qua `accoreconsole`.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-core.lsp` | Tạo mới — data model + tiện ích chuỗi/số |
| `lisp/tests/framework.lsp` | Tạo mới — test framework |
| `lisp/tests/test-core.lsp` | Tạo mới — 45 test case |
| `lisp/tests/run-tests.ps1` | Tạo mới — runner headless |
| `docs/agent-progress/TASK-005.md` | Tạo mới (file này) |

---

## Implementation

### Data model

`ITEM` = association list với 24 khoá:
`CATEGORY TYPE NAME SPEC DESCRIPTION LAYER QTY AUTOQTY MANQTY DEDUCTION NETQTY
LENGTH UNIT PREFIX HANDLES SOURCETYPE SOURCEOBJECT NOTES FLOOR AREA ZONE FORMULA
LABEL1 LABEL2 LABEL3`

`DB` = danh sách item. Khoá gộp nhóm = `CATEGORY|TYPE|NAME|SPEC|UNIT`.

### API chính

| Hàm | Chức năng |
|---|---|
| `mto-item-new` | Tạo item rỗng đủ khoá |
| `mto-item-get` / `mto-item-set` | Đọc/ghi (tự thêm khoá mới) |
| `mto-item-add-handle` | Thêm handle, chống trùng |
| `mto-item-add-auto` / `mto-item-add-length` | Cộng dồn số lượng/chiều dài |
| `mto-item-recalc` | `QTY = AUTO + MAN`; `NETQTY = QTY − DEDUCTION` |
| `mto-db-merge-item` | Gộp theo key (cộng số liệu + handle) hoặc thêm dòng mới |
| `mto-db-sort` / `mto-db-filter` / `mto-db-find-by-handle` | Sắp xếp / lọc / tra handle |
| `mto-db-total-net` / `mto-db-total-length` | Tổng hợp |
| `mto-db-save` / `mto-db-load` / `mto-db-clear` | Trạng thái phiên (`*MTO-DB*`) |

### Test harness

`run-tests.ps1` → sinh `out/run.scr` → `accoreconsole /s run.scr` → LISP ghi
`out/results.txt` → PowerShell đọc và trả exit code 0/1.

Ghi kết quả ra **file** (không đọc console) để tránh encoding UTF-16LE của accoreconsole.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1"
```

## Test result

**PASS — 45/45**

```
TESTS: 45/45 PASSED
RESULT: ALL-PASS
KET LUAN: PASS (TESTS: 45/45 PASSED)
```

Phạm vi: string utils (10), number utils (6), item model (9), handle (2), recalc (3),
key/DB (9), sort/filter/total (5), handle lookup (2), session (2).

---

## Bug thật đã phát hiện & sửa (nhờ test chạy thật)

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B1 | `mto-str-up` trả **chữ thường** thay vì chữ hoa | `(strcase s T)` trong AutoLISP nghĩa là LOWERCASE (tham số thứ 2 là `downcase-p`), không phải uppercase | Bỏ tham số: `(strcase (mto-str-trim s))` |
| B2 | `mto-num->str` trả `"0.0"` thay vì `"0"` | Vòng lặp cắt trailing-zero dừng sai khi gặp dấu `.` giữa chuỗi | Viết lại: cắt hết `0` cuối, rồi cắt `.` nếu còn |

Ngoài ra 1 lỗi ở **test** (không phải code): kỳ vọng tổng NETQTY = 24, thực tế đúng = 19 (12+3+4) → sửa kỳ vọng.

---

## Root cause quan trọng cho toàn dự án

`(load "...")` báo **"File load canceled"** không phải do dấu cách trong đường dẫn
(đã loại trừ bằng thực nghiệm trên `%TEMP%\mtonospace`), mà do biến hệ thống
**`SECURELOAD=1`** của AutoCAD chặn LISP ngoài `TRUSTEDPATHS`.

- Harness test: `(setvar "SECURELOAD" 0)` trong phiên test.
- **Production (cần đưa vào INSTALL.md)**: người dùng phải `APPLOAD` (dialog) hoặc
  thêm thư mục vào `TRUSTEDPATHS`, nếu không plugin không nạp được.

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | `mto-db-merge-item` là O(n) mỗi lần thêm ⇒ O(n²) khi gộp nhiều item | Thấp — chấp nhận PHASE 1; tối ưu ở PHASE 3 nếu cần |
| I2 | `mto-num->str` dùng `rtos` mode 2 precision 4 ⇒ mất chính xác quá 4 chữ số thập phân | Thấp — ghi nhận |
| I3 | KEY gộp nhóm chưa gồm FLOOR/AREA (chưa dùng ở PHASE 1) | Thấp — PHASE 4 sẽ mở rộng |
| I4 | Production load cần TRUSTEDPATHS/SECURELOAD (xem trên) | **Cao** — phải ghi INSTALL.md trước khi giao |

---

## Next task

**TASK-001 — Interactive Selection** (`lisp/mto-select.lsp`)

Chọn vùng bằng `ssget` với mode `W` / `C` / `WP`, filter theo layer và loại đối tượng
(TEXT/MTEXT/INSERT/LINE/LWPOLYLINE). Trả về danh sách handle để nạp vào data model TASK-005.
