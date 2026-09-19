# TASK-014 — Subtotal & Deduction

**Phase:** PHASE 3
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-013 (formula)

---

## Objective

Hỗ trợ **subtotal / grouping / deduction** dạng **generic** để dùng được cho cả
Electrical, Plumbing, ELV (khoá gom nhóm là **tham số**, không hard-code).

Công thức: `NETQTY = QTY − DEDUCTION`; `Subtotal(nhóm) = SUM(NETQTY)`, `SUM(LENGTH)`, `SUM(DEDUCTION)`.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-subtotal.lsp` | Tạo mới |
| `lisp/tests/test-subtotal.lsp` | Tạo mới — 33 test case |
| `docs/agent-progress/TASK-014.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-sub-set-deduction` | Đặt deduction |
| `mto-sub-add-deduction` | Cộng/trừ dồn deduction (âm = hoàn lại) |
| `mto-sub-clamp-deduction` | Kẹp `0 ≤ DED ≤ QTY` ⇒ **NETQTY không bao giờ âm** |
| `mto-sub-group` | Gom nhóm theo khoá bất kỳ → `((value (QTY…) (LEN…) (DED…) (NET…) (COUNT…)) …)` |
| `mto-sub-total-of` / `-deduction-of` / `-net-of` | Truy xuất trường của nhóm |
| `mto-sub-summary` | `(GROUPS . GRAND)` |
| `mto-sub-apply-deductions` | Áp deduction hàng loạt theo rules `(giá-trị-khoá → amount)` |

Lệnh `MTOSUB` (báo subtotal theo CATEGORY/TYPE/LAYER/FLOOR + grand total),
`MTODED` (khấu trừ theo từng dòng).

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-subtotal.lsp"
```

## Test result

**PASS — 33/33**

```
TESTS: 33/33 PASSED
RESULT: ALL-PASS
```

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B18 | Lint **chặn trước khi chạy test**: `mto-subtotal.lsp` lệch ngoặc `depth=-1` | Thừa 1 ngoặc đóng ở `c:MTODED` | Sửa ngoặc. **Đây là minh chứng cổng LINT mới có giá trị**: lỗi cú pháp bị chặn TRƯỚC khi chạy, không thể che như B16 |
| B19 | `apply-deductions` báo 2 dòng áp dụng nhưng DED **không đổi** | Hàm gọi `mto-sub-add-deduction` (immutable, trả item MỚI) nhưng **bỏ qua kết quả trả về** ⇒ db không cập nhật | Trả về DB mới `(cons out applied)`; test dùng `(car res)` |

**1 lỗi kỳ vọng của test:** tôi tính `DED = 21` nhưng thực tế **20** — vì `it2` (QTY=5)
bị **clamp** khi DED `1+5=6 > 5`. Hành vi clamp là **đúng** (bảo vệ NETQTY ≥ 0);
đã sửa kỳ vọng và thêm assert kiểm "không nhóm nào có NETQTY âm".

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Chưa xuất subtotal ra Excel/CSV dạng nhiều mức (hiện bảng dùng 1 mức theo CATEGORY) | Trung bình |
| I2 | Clamp ngầm có thể **ẩn** ý định người dùng (khấu trừ nhiều hơn QTY) — cần cảnh báo | Trung bình |
| I3 | Chưa hỗ trợ deduction theo **chiều dài** (chỉ theo số lượng) | Thấp |

---

## Next task

**TASK-015 — Floor / Area / Zone** (`lisp/mto-floor.lsp`) — bắt đầu PHASE 4.
