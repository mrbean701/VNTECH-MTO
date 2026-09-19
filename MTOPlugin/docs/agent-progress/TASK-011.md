# TASK-011 — Batch Update (TEXT / MTEXT / XData)

**Phase:** PHASE 2
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model), TASK-010 (resolve handle)

---

## Objective

Sửa dữ liệu từ dataset rồi **cập nhật ngược vào bản vẽ**: `TEXT`/`MTEXT` (DXF 1) qua
`entmod`, và ghi **XData** để truy vết. Không sửa đối tượng không có handle hợp lệ,
có thông báo **"Đã cập nhật thành công X đối tượng"**.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-update.lsp` | Tạo mới |
| `lisp/tests/test-update.lsp` | Tạo mới — 34 test case |
| `docs/agent-progress/TASK-011.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-upd-supported-p` | Entity sửa được? (TEXT/MTEXT) |
| `mto-upd-get-value` | Nội dung hiện tại (DXF 1) |
| `mto-upd-set-value` | Đặt nội dung mới qua `entmod` |
| `mto-upd-ensure-appid` | Đăng ký APPID cho XData |
| `mto-upd-xdata-set` | Ghi XData (xoá bản cũ cùng app rồi ghi mới) |
| `mto-upd-xdata-get` | Đọc XData theo app |
| `mto-upd-apply-item` | Áp giá trị cho mọi handle của item → `(OK . FAIL)` |
| `mto-upd-batch` | Cập nhật hàng loạt nhiều item |

Lệnh `MTOUPDATE` (chọn STT → nhập giá trị mới → cập nhật + ghi XData) và `MTOXCHECK`.

App XData mặc định: `*MTO-XDATA-APP*` = `"MTO_QTO"`.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-update.lsp"
```

## Test result

**PASS — 34/34**

```
TESTS: 34/34 PASSED
RESULT: ALL-PASS
```

Test **sửa TEXT/MTEXT thật rồi đọc lại từ bản vẽ**, và **XData roundtrip thật**
(ghi → đọc → ghi đè → đọc lại; 2 app khác nhau không lẫn nhau).

---

## Bug thật đã phát hiện & sửa

| # | Bug | Nguyên nhân | Sửa |
|---|---|---|---|
| B15 | Toàn bộ 6 test XData FAIL, kể cả "APPID được đăng ký" | `entmake` APPID thiếu **DXF subclass markers** (`(100 . "AcDbSymbolTableRecord")`, `(100 . "AcDbRegAppTableRecord")`) ⇒ `entmake` trả `nil` (cùng loại lỗi như MTEXT thiếu `AcDbMText`) | Thêm đủ subclass |
| B16 | **File `mto-update.lsp` lỗi cú pháp `extra right paren on input`** nhưng test vẫn **PASS** | Lỗi nằm ở CUỐI file (`c:MTOUPDATE` thừa 1 ngoặc) ⇒ các `defun` phía trước vẫn được định nghĩa ⇒ test không phát hiện. **Harness đã che lỗi cú pháp.** | (1) Sửa ngoặc; (2) **Gia cố harness**: thêm lint cân bằng ngoặc + kiểm tra load-status, chặn loại lỗi này |

**Bài học:** test PASS không có nghĩa file nguồn hợp lệ — phải có lớp lint/load-check.
Đây là lỗi nghiêm trọng nhất về **phương pháp kiểm thử** trong dự án.

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Chưa cập nhật ngược **số liệu khối lượng** vào bản vẽ (chỉ sửa nội dung text) | Trung bình |
| I2 | XData chỉ ghi **1 trong 1 chuỗi** (chưa lưu nhiều trường có cấu trúc) | Thấp |
| I3 | Không cập nhật được MTEXT có nhiều định dạng con phức tạp (ghi đè toàn bộ nội dung) | Thấp |

---

## Next task

**TASK-012 — Plugin Undo/Restore** (`lisp/mto-undo.lsp`)
