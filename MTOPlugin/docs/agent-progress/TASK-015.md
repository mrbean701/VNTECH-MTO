# TASK-015 — Floor / Area / Zone

**Phase:** PHASE 4
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-014 (subtotal generic)

---

## Objective

Cho dữ liệu MTO gán được **FLOOR / ZONE / AREA** và **lọc + subtotal theo tầng/khu vực**.
Gán được theo 3 cách: theo **layer** (wildcard), theo **vùng chọn** (handle), và **thủ công**.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-floor.lsp` | Tạo mới |
| `lisp/tests/test-floor.lsp` | Tạo mới — 43 test case |
| `docs/agent-progress/TASK-015.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-floor-set` / `-of-item` / `-zone-of-item` / `-area-of-item` | Gán / đọc |
| `mto-floor-set-all` | Gán tất cả về cùng tầng |
| `mto-floor-match-p` | Khớp layer với pattern bằng **`wcmatch`** (`*`, `?`, `[...]`) |
| `mto-floor-find-rule` | Rule pattern đầu tiên khớp sẽ thắng |
| `mto-floor-assign-by-layer` | Gán hàng loạt theo layer rules |
| `mto-floor-item-touches` | Item có handle nằm trong danh sách? |
| `mto-floor-assign-by-handles` | Gán theo **vùng chọn** (`*MTO-LAST-SELECTION*` từ MTOSEL) |
| `mto-floor-list` | Danh sách tầng có trong DB |
| `mto-floor-filter` | Lọc theo tầng |
| `mto-floor-unassigned` | Đếm dòng chưa gán |
| `mto-floor-subtotal` | Subtotal theo FLOOR (tái dùng `mto-sub-group`) |

Lệnh `MTOFLOOR` (3 chế độ: theo layer / theo vùng chọn / tất cả).

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-floor.lsp"
```

## Test result

**PASS — 43/43**

```
TESTS: 43/43 PASSED
RESULT: ALL-PASS
```

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B20 | `too few arguments` khi `mto-floor-list` sắp xếp | Dùng `(vl-sort out '(<))` — **`'(<)` là một LIST chứa symbol `<`**, không phải symbol hàm; `vl-sort` gọi `(<)` với 0 tham số | Dùng `'<` (symbol hàm). Đã grep: chỉ 1 chỗ mắc lỗi |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Chưa tự suy ra FLOOR từ tên layer theo quy ước công ty (phải nhập pattern thủ công) | Trung bình |
| I2 | Gán theo handle chỉ khớp **một phần** handle của item (đủ cho mục đích chọn vùng) | Thấp |
| I3 | Chưa lọc kết hợp nhiều điều kiện (Floor + Category) | Thấp |

---

## Next task

**TASK-016 — Per-Drawing Configuration** (`lisp/mto-config.lsp`)
