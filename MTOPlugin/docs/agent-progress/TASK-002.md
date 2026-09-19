# TASK-002 — Text Prefix Recognition

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-001 (selection/filter)

---

## Objective

Đọc `TEXT`/`MTEXT` và nhận dạng **PREFIX** (MCB/ELCB/DB/AP/CAM/FACP...) để gom nhóm
`PREFIX → CATEGORY → TYPE → QUANTITY`, thay vì gộp tất cả TEXT thành một nhóm.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-text.lsp` | Tạo mới |
| `lisp/tests/test-text.lsp` | Tạo mới — 40 test case (TEXT/MTEXT thật) |
| `lisp/tests/run-tests.ps1` | Sửa — bọc test trong `vl-catch-all-apply` để không mất file kết quả khi crash |
| `docs/agent-progress/TASK-002.md` | Tạo mới |

---

## Implementation

### Bảng prefix

`*MTO-PREFIX-TABLE*` — 46 prefix → category:
- **Electrical:** MCB, MCCB, ELCB, RCBO, RCD, MDB, SDB, DB, CB, CONTACTOR, RELAY,
  LIGHT, LED, LAMP, SOCKET, SWITCH, FAN, TRAY, CONDUIT
- **ELV:** AP, CAM, CCTV, NVR, DVR, FACP, SMOKE, HEAT, MCP, SIREN, STROBE,
  SPEAKER, AMP, LAN, DATA, RJ45, PATCH, RACK, UPS, PDU, ODF, ACC
- **Plumbing:** PUMP, VALVE, PIPE, WC, LAV, SINK, URINAL, SHOWER, TANK, GATE, BALL, CHECK, PRV, FD

### API

| Hàm | Chức năng |
|---|---|
| `mto-text-strip-mtext` | Bỏ format code MTEXT (`{\fArial\|b0;...}`, `\A1;`, `\P`, `\~`, `{}`) |
| `mto-text-content` | Nội dung sạch từ entity |
| `mto-text-entity-p` | Entity là TEXT/MTEXT/ATTDEF? |
| `mto-text-extract-prefix` | Token đầu, tách thêm theo `-` và `_` |
| `mto-text-match-known-prefix` | Khớp prefix **dài nhất** + kiểm tra **ranh giới** |
| `mto-text-recognize-prefix` | Bảng prefix, fallback token đầu |
| `mto-text-category-for-prefix` | Prefix → category |
| `mto-text-classify` | Entity text → item |
| `mto-text-scan-ss` | Selection set → db (kèm đếm added/skipped) |

Lệnh `MTOTEXT` — quét text theo loại + layer, nạp vào `*MTO-DB*`.

### Điểm quan trọng về nhận dạng

- `MCCB 100A` → **MCCB** (không phải MCB): ưu tiên prefix dài nhất.
- `ELCB 32A` → **ELCB** (không phải E).
- `DBX 100` → **không khớp** `DB`: kiểm tra ranh giới (ký tự sau prefix phải là
  hết chuỗi, khoảng trắng, `-`, `_`, `:`, `.`, hoặc chữ số).

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-text.lsp"
```

## Test result

**PASS — 40/40**

```
TESTS: 40/40 PASSED
RESULT: ALL-PASS
```

**Regression:** `test-core` 45/45 PASS, `test-select` 32/32 PASS.

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B4 | `entmake` MTEXT trả `nil` ⇒ `entget nil` lỗi `bad argument type: lentityp nil`, test dừng giữa chừng | Thiếu DXF subclass markers `(100 . "AcDbEntity")` `(100 . "AcDbMText")` | Thêm đủ subclass trong helper test |
| B5 | Harness **mất file kết quả** khi test crash giữa chừng | `mto-write-results` nằm cuối test function, không chạy khi có lỗi | Harness bọc `vl-catch-all-apply`, ghi `TEST-FAIL: UNCAUGHT-ERROR` rồi luôn gọi `mto-write-results` |
| B6 | 3 test FAIL vì cho rằng thứ tự `ssget` = thứ tự tạo | `ssget "_X"` **không bảo đảm thứ tự** | Test tìm entity theo **loại** thay vì theo index |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | `mto-text-strip-mtext` chưa xử lý `%%d/%%c/%%p` và stacked fraction `\S1/2;` | Thấp |
| I2 | Bảng prefix hard-code trong LISP, chưa đọc từ file config ngoài | Trung bình — nên đưa ra config ở PHASE 4 (TASK-016) |
| I3 | TEXT nhiều dòng trong 1 MTEXT chỉ tạo 1 item theo chuỗi đã nối | Thấp — ghi nhận |

---

## Next task

**TASK-003 — Block Recognition & Counting** (`lisp/mto-block.lsp`)

Chọn block mẫu → lấy tên → đếm toàn bộ block cùng tên (`ssget "_X"` + filter INSERT).
Kèm **MANUAL COUNT**: `TOTAL = AUTO_COUNT + MANUAL_ADJUSTMENT`, lưu rõ
`AutoCount / ManualCount / FinalCount`.
