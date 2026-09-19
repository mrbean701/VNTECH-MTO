# TASK-016 — Per-Drawing Configuration

**Phase:** PHASE 4
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model)

---

## Objective

Mỗi bản vẽ **nhớ được cấu hình MTO của chính nó** (đường dẫn bộ quy tắc, đơn vị, thư mục xuất,
tầng hiện hành, chế độ Xref...).

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-config.lsp` | Tạo mới |
| `lisp/tests/test-config.lsp` | Tạo mới — 34 test case |
| `docs/agent-progress/TASK-016.md` | Tạo mới |

---

## Implementation

**Hai cơ chế** (chọn theo khả dụng):

| Cơ chế | Công nghệ | Ưu điểm | Đã kiểm chứng |
|---|---|---|---|
| **FILE** `<dwg>.mtocfg` | `open`/`read-line` | Luôn chạy, dễ đọc/sao chép/gửi kèm | ✅ PASS |
| **NOD** trong DWG | `namedobjdict` + `XRECORD` + `dictadd` | Đi theo bản vẽ | ✅ **PASS (hoạt động cả trong accoreconsole)** |

**Định dạng file:** mỗi dòng `KEY\|VALUE`. **KHÔNG dùng `read`/`eval`** trên nội dung file
(tránh thực thi dữ liệu từ file ngoài). Ký tự phân cách trong giá trị được làm sạch.

| Hàm | Chức năng |
|---|---|
| `mto-cfg-new` | Cấu hình mặc định (8 khoá) |
| `mto-cfg-get` / `mto-cfg-set` | Đọc/ghi (immutable) |
| `mto-cfg-to-lines` / `-from-lines` | Serialize/deserialize (làm sạch ký tự phân cách) |
| `mto-cfg-default-path` | `<tên-dwg>.mtocfg` (bỏ đuôi `.dwg`, không phân biệt hoa/thường) |
| `mto-cfg-save` / `-load` | Ghi/đọc file |
| `mto-cfg-nod-save` / `-load` | Lưu/đọc trong DWG qua NOD + XRecord (bọc `vl-catch-all-apply`) |

Lệnh `MTOCFG` — nạp theo thứ tự **NOD → file → mặc định**, sửa khoá, lưu file hoặc lưu NOD.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-config.lsp"
```

## Test result

**PASS — 34/34**

```
TESTS: 34/34 PASSED
RESULT: ALL-PASS
```

Test **ghi/đọc file cấu hình thật**, kiểm định dạng văn bản trên đĩa, và **kiểm cả nhánh NOD**
(nếu không hỗ trợ thì phải trả `nil` sạch, không crash).

---

## Bug thật đã phát hiện & sửa

Không phát sinh bug mới (module viết đúng ngay nhờ đã nắm các gotcha AutoLISP:
`let`, `vl-sort`, `(last ...)`, `wcmatch`).

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | File `.mtocfg` nằm **cạnh DWG** (theo tên) chứ chưa đọc đường dẫn đầy đủ của DWG → hai bản vẽ cùng tên ở thư mục khác nhau sẽ dùng chung cấu hình | Trung bình |
| I2 | Cấu hình NOD chỉ lưu **1 XRecord** chuỗi (chưa có cấu trúc nhiều trường) | Thấp |
| I3 | Chưa tự động nạp cấu hình khi chạy các lệnh MTO khác (phải gọi `MTOCFG`) | Trung bình |

---

## Next task

**TASK-017 — .NET Extension** (`src/MTOPlugin.UI`) — PHASE 5.
