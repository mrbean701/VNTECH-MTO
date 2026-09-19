# TASK-013 — Custom Formula

**Phase:** PHASE 3
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-010 (index)

---

## Objective

Cho phép người dùng định nghĩa **công thức tính đơn giản**: `SL × hệ số`,
`Chiều dài × hệ số`, `Khối lượng × đơn giá`. Phải lưu rõ
**Formula / Input / Result / Explanation** — ví dụ `LEN * 1.05 = 126`.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-formula.lsp` | Tạo mới |
| `lisp/tests/test-formula.lsp` | Tạo mới — 62 test case |
| `docs/agent-progress/TASK-013.md` | Tạo mới |

---

## Implementation

**An toàn:** KHÔNG dùng `eval`/`read` trên chuỗi người dùng. Chỉ chấp nhận đúng dạng
`<toán-hạng> <phép-toán> <toán-hạng>`.

| Hàm | Chức năng |
|---|---|
| `mto-formula-op-normalize` | `x`/`X`/`*` → `*`; `:`/`/` → `/`; `+`; `-` |
| `mto-formula-parse` | Chuỗi → `(a op b)` hoặc `nil` (kiểm đúng 3 token) |
| `mto-formula-lookup` | Token → số (literal hoặc biến, không phân biệt hoa/thường) |
| `mto-formula-eval` | Tính `(a op b)` + vars → số hoặc `nil` (chia 0 → `nil`) |
| `mto-formula-run` | → `(RESULT . EXPLANATION)` |
| `mto-formula-vars-of-item` | Biến của item: `SL/QTY/NETQTY/LEN/DED/PRICE` |
| `mto-formula-apply-item` | Lưu `FORMULA`, `FORMULA-VALUE`, `FORMULA-EXPLAIN`; tuỳ chọn ghi `NETQTY` |
| `mto-formula-apply-db` | Áp công thức theo rules `(NAME/TYPE → expr)` |

Lệnh `MTOFORMULA`.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-formula.lsp"
```

## Test result

**PASS — 62/62**

```
TESTS: 62/62 PASSED
RESULT: ALL-PASS
```

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B17 | `syntax error` khi chạy `mto-formula-lookup` | Hàm dùng `(let ((v ...)) ...)` — **AutoLISP KHÔNG có `let`**. Đã kiểm chứng bằng thực nghiệm: `(let ((x 1)) x)` → lỗi `no function definition` | Bỏ `let`, dùng `setq` + biến local khai báo trong `defun` |

**Quét toàn bộ:** đã grep `let` trong tất cả file `.lsp` → phát hiện và sửa thêm 1 chỗ
trong `mto-update.lsp` (`c:MTOUPDATE`). Hiện **0 chỗ dùng `let`**.

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Chỉ hỗ trợ **1 phép toán, 2 toán hạng** (không có biểu thức lồng, ngoặc) | Trung bình (theo thiết kế "không over-engineering") |
| I2 | `PRICE` mặc định = 0 (chưa có nguồn đơn giá) | Thấp |
| I3 | Chưa có UI nhập công thức hàng loạt (hiện nhập từng dòng hoặc qua `apply-db`) | Thấp |

---

## Next task

**TASK-014 — Subtotal & Deduction** (`lisp/mto-subtotal.lsp`)
