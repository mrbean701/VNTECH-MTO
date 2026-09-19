# TASK-008 — Orphan Detection

**Phase:** PHASE 1
**Trạng thái:** ✅ DONE
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-005 (data model)

---

## Objective

Mọi handle trong dataset phải kiểm tra được còn tồn tại hay không; nếu đối tượng đã mất
thì **đánh dấu orphan**, cho phép thống kê và **loại khỏi dataset** để orphan không làm
sai khối lượng. **Không tự động xoá đối tượng khỏi DWG** — chỉ xoá dữ liệu MTO.

---

## Files changed

| File | Hành động |
|---|---|
| `lisp/mto-orphan.lsp` | Tạo mới |
| `lisp/tests/test-orphan.lsp` | Tạo mới — 27 test case (tạo entity thật rồi xoá thật) |
| `docs/agent-progress/TASK-008.md` | Tạo mới |

---

## Implementation

| Hàm | Chức năng |
|---|---|
| `mto-orphan-exists-p` | Handle còn sống? — xem mục **Root cause** bên dưới |
| `mto-orphan-of-item` | Danh sách handle mồ côi của item |
| `mto-orphan-check-db` | Thống kê TOTAL / ALIVE / ORPHAN / ITEMS-ORPHAN |
| `mto-orphan-prune-item` | Bỏ handle mồ côi khỏi item, trả `(item . removed)` |
| `mto-orphan-prune-db` | Bỏ orphan toàn DB, trả `(db . removed)` |
| `mto-orphan-report` | Chuỗi báo cáo |

Lệnh `MTOORPHAN` — báo cáo + hỏi `Y/N` trước khi prune.

---

## Test performed

```powershell
powershell -ExecutionPolicy Bypass -File ".\lisp\tests\run-tests.ps1" -TestFile "test-orphan.lsp"
```

## Test result

**PASS — 27/27**

```
TESTS: 27/27 PASSED
RESULT: ALL-PASS
```

---

## Root cause quan trọng (đã kiểm chứng bằng thực nghiệm)

Ban đầu module chỉ dùng `handent`:

```lisp
(setq res (handent h))  ; nil = mo coi
```

Test cho thấy **sau khi `entdel`** entity vẫn được coi là "còn sống". Truy vết trực tiếp
trên `accoreconsole` cho kết quả:

```
H1=239  handent-alive=T
ENTDEL-RET=<Entity name: 1fdb2f2d510>     <- entdel thanh cong
ENTGET-AFTER=nil                          <- entity DA bi xoa khoi database
HANDENT-AFTER-DEL=T                       <- NHUNG handent VAN resolve duoc
```

**Kết luận:** entity bị `entdel` chỉ bị **đánh dấu xoá**, chưa purge cho tới khi bản vẽ
được lưu/đóng ⇒ `handent` **vẫn trả về ename**. Vì vậy chỉ `handent` là **không đủ**.

Đã sửa: kiểm tra **cả hai** — `handent` resolve được **VÀ** `entget` trả về dữ liệu.

```lisp
(setq got (vl-catch-all-apply 'entget (list res)))
(if (or (vl-catch-all-error-p got) (null got)) nil t)   ; nil => mo coi
```

Đây là **bug của module**, không phải của test — và là ví dụ đúng của nguyên tắc
"không đánh dấu DONE khi chưa test".

---

## Bug khác đã sửa ở test

| # | Vấn đề | Nguyên nhân | Sửa |
|---|---|---|---|
| B11 | `bad argument type: lentityp ((0 . "LINE") ...)` | Dùng **giá trị trả về của `entmake`** làm ename | Dùng `(entlast)` để lấy entity vừa tạo |

---

## Known issues

| # | Nội dung | Mức |
|---|---|---|
| I1 | Chỉ kiểm handle trong dataset hiện tại, chưa quét toàn bộ XData/named objects | Thấp |
| I2 | Chưa đánh dấu **trạng thái orphan** trên từng item (chỉ đếm + prune) | Trung bình — nên thêm cờ `ORPHAN-P` cho item |
| I3 | Prune làm **giảm khối lượng** nhưng không ghi log lý do | Trung bình — cần cho truy vết kiểm toán |

---

## Next task

**TASK-009 — AutoCAD Table** (`lisp/mto-table.lsp`) — bắt đầu PHASE 2.
