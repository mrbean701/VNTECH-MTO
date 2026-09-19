# TASK-001 — Interactive Selection

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model)

---

## Objective

Cho phép người dùng chọn **VÙNG** (Window / Crossing / WindowPolygon / CrossPolygon / Fence)
thay vì bắt buộc scan toàn bộ bản vẽ, kèm lọc theo **loại đối tượng** và **layer** (wildcard).
Kết quả trả về danh sách handle để nạp vào data model.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-select.lsp` | Tạo mới |
| `lisp/tests/test-select.lsp` | Tạo mới — 32 test case (tạo entity THẬT) |
| `lisp/tests/run-tests.ps1` | Sửa — auto-load mọi module trong `lisp/` |
| `docs/agent-progress/TASK-001.md` | Tạo mới |

---

## Implementation

### Logic thuần (testable headless)

| Hàm | Chức năng |
|---|---|
| `mto-sel-normalize-list` | `"text, mtext ; insert"` → `("TEXT" "MTEXT" "INSERT")` |
| `mto-sel-valid-mode-p` | Kiểm tra mode ssget hợp lệ (`W C WP CP F X I A`) |
| `mto-sel-build-filter` | Sinh DXF filter list: code `0` (types), code `8` (layers) |
| `mto-sel-ss->handles` | Selection set → danh sách handle (DXF 5) |
| `mto-sel-ss->enames` | Selection set → entity names |
| `mto-sel-ss->types` | Đếm theo loại (alist) |
| `mto-sel-ss->layers` | Đếm theo layer (alist) |
| `mto-sel-ss-summary` | Tổng hợp TOTAL + TYPES + LAYERS |
| `mto-sel-all-handles` | Lấy handle toàn bản vẽ theo filter (cho module khác dùng) |

### Tương tác

Lệnh `MTOSEL`:
1. Hỏi mode (`W`/`C`/`WP`/`CP`/`F`), mặc định `W`.
2. Hỏi loại đối tượng (phân cách `,` hoặc `;`, Enter = tất cả).
3. Hỏi layer (wildcard `*`, Enter = tất cả).
4. Chọn 2 điểm (W/C/F) hoặc polygon (WP/CP).
5. In thống kê theo loại + layer; lưu handle vào `*MTO-LAST-SELECTION*`.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-select.lsp"
```

## Test result

**PASS — 32/32**

```
TESTS: 32/32 PASSED
RESULT: ALL-PASS
```

Test tạo entity **thật** bằng `entmake` (3 LINE + 2 TEXT trên 2 layer), rồi kiểm
`ssget "_X"` với filter loại/layer/wildcard — không dùng dữ liệu giả.

**Regression TASK-005:** chạy lại `test-core.lsp` → **45/45 PASSED** (không phá).

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B3 | Lỗi runtime `incorrect object to bind: T`, `mto-run-tests` dừng giữa chừng ⇒ **không sinh file kết quả** | Dùng `t` làm **biến local** trong `defun` (`(ss / i n e t lst pair)`). AutoLISP coi `T` là symbol `true`, không được bind | Đổi tên biến local `t` → `ety`; thêm comment cảnh báo |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | `MTOSEL` chưa ghi kết quả vào `*MTO-DB*` (mới lưu handle vào `*MTO-LAST-SELECTION*`) | Thấp — TASK-006 sẽ nối vào DB |
| I2 | Chưa hỗ trợ chọn theo `F` (Fence) đa điểm — hiện chỉ 2 điểm như W/C | Thấp — bổ sung sau nếu cần |
| I3 | Chưa kiểm tra layer bị frozen/off khi chọn | Thấp — ghi nhận |

---

## Next task

**TASK-002 — Text Prefix Recognition** (`lisp/mto-text.lsp`)

Đọc `TEXT`/`MTEXT`, tách **prefix** (MCB/ELCB/DB/AP/CAM/FACP...) để gom nhóm
`PREFIX → CATEGORY → TYPE → QUANTITY` thay vì gộp tất cả TEXT thành một nhóm.
