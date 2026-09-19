# TASK-010 — Find / Zoom Back

**Phase:** PHASE 2
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-006 (bảng), TASK-008 (orphan)

---

## Objective

Từ một dòng kết quả (STT) hoặc handle → **tìm đối tượng thật trên bản vẽ** → chọn
(highlight) và zoom tới nó. Yêu cầu cốt lõi: **"Bảng → bản vẽ"**.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-find.lsp` | Tạo mới |
| `lisp/tests/test-find.lsp` | Tạo mới — 32 test case |
| `docs/agent-progress/TASK-010.md` | Tạo mới |

---

## Implementation

**Không dùng ActiveX** (accoreconsole không có): dùng lệnh `ZOOM _O` + `sssetfirst`.

| Hàm | Chức năng |
|---|---|
| `mto-find-resolve` | handle → ename, **chỉ khi còn sống** (handent + entget) |
| `mto-find-alive-handles` | Lọc handle còn sống của item |
| `mto-find-build-index` | Danh mục `STT → item` (theo thứ tự bảng) |
| `mto-find-by-index` | Tra item theo STT |
| `mto-find-matches-p` | Khớp từ khoá trên NAME/TYPE/CATEGORY/LAYER/PREFIX/DESCRIPTION/HANDLE |
| `mto-find-search` | Tìm theo từ khoá |
| `mto-find-select-handle` | Chọn (highlight) đối tượng |
| `mto-find-zoom-handle` | Zoom tới đối tượng |
| `mto-find-zoom-item` | Zoom tới handle còn sống đầu tiên của item |

Lệnh `MTOFIND` (STT hoặc từ khoá → chọn → zoom) và `MTOGOTO` (theo handle).

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-find.lsp"
```

## Test result

**PASS — 32/32**

```
TESTS: 32/32 PASSED
RESULT: ALL-PASS
```

Test tạo entity thật, **xoá thật** (`entdel`), rồi kiểm resolve/zoom trả `nil` đúng;
và zoom/chọn thật trên entity còn sống (không cần ActiveX).

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B14 | Thứ tự bảng sai: `STT 1 = ELV`, `STT 2 = Electrical` | `mto-db-sort` so sánh chuỗi **phân biệt hoa/thường** (ASCII): `"ELV"` (`L`=76) < `"Electrical"` (`l`=108) ⇒ ELV đứng trước, khó đọc | Đổi `mto-db-sort` sang so sánh **không phân biệt hoa/thường** (`mto-str-up`) — đây là cải tiến UX thật, ảnh hưởng cả `MTOLIST`/`MTOCSV`/`MTOTABLE` |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | `ZOOM` hoạt động trong accoreconsole nhưng **không có màn hình** để mắt thường xác nhận khung nhìn | Thấp (đã xác nhận lệnh thành công) |
| I2 | Chưa hỗ trợ chọn nhiều dòng rồi zoom lần lượt | Thấp |
| I3 | Xử lý **handle trong Xref** chưa có (handle thuộc database Xref riêng) | Trung bình |

---

## Next task

**TASK-011 — Batch Update (TEXT/MTEXT/XData)** (`lisp/mto-update.lsp`)
