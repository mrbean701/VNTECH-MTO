# HƯỚNG DẪN NHẬP DANH MỤC VẬT TƯ CỦA CÔNG TY

**MTOPro · Đề tài R&D-CAD-QTO-01 · Phòng Dự án**
**Phiên bản 1.0 — 18/09/2026**

---

## 1. Mục đích

Công ty đã có **danh mục vật tư riêng** (mã, tên, quy cách, đơn vị). Tài liệu này hướng dẫn
cách **nhập danh mục đó vào MTOPro** để phần mềm tự động phân loại khi bóc tách khối lượng.

**Nguyên tắc:** anh **KHÔNG phải nhập lại** danh mục thủ công từng dòng. Chỉ cần:

1. Mở file Excel mẫu
2. **Dán danh mục có sẵn** của công ty vào
3. Điền thêm **cách nhận dạng** (tên block hoặc layer trên bản vẽ)
4. Chạy 1 lệnh → có bộ quy tắc dùng được ngay

---

## 2. Hai file anh cần biết

| File | Vai trò |
|---|---|
| `config\DANH_MUC_VAT_TU.xlsx` | **Anh điền vào đây** (danh mục vật tư công ty) |
| `scripts\import-materials.ps1` | Công cụ chuyển Excel → bộ quy tắc |

**Kết quả:** file `config\rules.json` — nạp vào MTOPro là dùng được.

---

## 3. Cấu trúc file Excel (3 sheet)

### Sheet 1 — `DANH_MUC` (điền vào đây)

| Cột | Bắt buộc | Ý nghĩa | Ví dụ |
|---|---|---|---|
| STT | | Số thứ tự | `1` |
| **Mã vật tư** | ✅ | Mã trong danh mục công ty | `VL-CCTV-001` |
| **Tên vật tư** | ✅ | Tên chuẩn | `Camera Dome IP` |
| Quy cách | | Mô tả kỹ thuật | `2MP, PoE` |
| **Đơn vị** | ✅ | Đơn vị tính | `cái` · `bộ` · `m` |
| Hệ | | Hệ M&E | `HE-ELV` · `HE-DIEN` |
| **Tên block (mẫu)** | ⚠️ | Cách kỹ sư đặt tên block | `SE.DOME*` |
| **Layer (mẫu)** | ⚠️ | Layer chứa đối tượng | `CCTV;ELV-CCTV*` |
| Cách tính | | Kiểu tính khối lượng | `Count` / `SumLength` |
| Hệ số | | Nhân thêm (hao hụt) | `1.05` (= +5%) |
| Ưu tiên | | Số lớn thắng | `100` |
| Trạng thái | | `Active` / `Draft` | `Active` |
| Ghi chú | | Ghi chú nội bộ | |

> ⚠️ **Phải có ít nhất 1 trong 2 cột: Tên block HOẶC Layer.**
> Nếu không, phần mềm **không biết cách nhận dạng** vật tư đó → tự động đặt `Draft`.

### Sheet 2 — `HUONG_DAN`
Hướng dẫn ngay trong file (không cần mở tài liệu này).

### Sheet 3 — `HE_THONG`
Danh sách hệ M&E — có thể thêm/sửa.

---

## 4. Wildcard — cách viết "mẫu" tên block / layer

| Ký tự | Nghĩa | Ví dụ |
|---|---|---|
| `*` | Bất kỳ chuỗi nào | `SE.DOME*` khớp `SE.DOME CAMERA`, `SE.DOME-B` |
| `;` | Nhiều mẫu (hoặc) | `CCTV;ELV-CCTV*` |

**Ví dụ thực tế — bản vẽ Camera:**
```
Tên block (mẫu) = SE.DOME*;*DOME CAMERA*
Layer (mẫu)     = CCTV;ELV-CCTV*
```
→ Nhận được cả `SE.DOME CAMERA` (tên thật của kỹ sư).

---

## 5. Cách tính khối lượng

| Giá trị | Nghĩa | Dùng cho |
|---|---|---|
| `Count` | Đếm số lượng | Camera, đèn, ổ cắm, tủ điện |
| `SumLength` | Cộng chiều dài | Cáp, ống, máng, khay |
| `SumArea` | Cộng diện tích | Hatch, vùng |
| `AttributeSum` | Cộng thuộc tính block | Thuộc tính động trong block |

**Hệ số** — dùng cho hao hụt:
```
Chiều dài bản vẽ 1.000 m, hệ số 1.05  →  khối lượng = 1.050 m
```

---

## 6. Cách chạy import

Mở **PowerShell** tại thư mục `MTOPlugin`, chạy:

```powershell
.\scripts\import-materials.ps1
```

**Kiểm tra trước, không ghi file** (khuyên dùng lần đầu):
```powershell
.\scripts\import-materials.ps1 -DryRun
```

**Dùng file Excel khác:**
```powershell
.\scripts\import-materials.ps1 -Xlsx "D:\DanhMuc\VatTu2026.xlsx" -Out "config\rules.json"
```

### Kết quả mẫu

```
=== IMPORT DANH MUC VAT TU -> RULES ===
  Sheet DANH_MUC: 8 dong x 13 cot
  So dong du lieu: 7

---- KET QUA KIEM TRA ----
  Hop le    : 7 vat tu
  Canh bao  : 0
  Loi       : 0

PHAN BO THEO HE:
  HE-DIEN          2 vat tu
  HE-ELV           5 vat tu
PHAN BO THEO CACH TINH:
  Count            4 vat tu
  SumLength        3 vat tu

=== DA TAO RULES ===
  File: config\rules.json (7.5 KB)
  7 rule | 2 he
```

### Công cụ kiểm tra giúp gì

| Kiểm tra | Ý nghĩa |
|---|---|
| **Hợp lệ** | Số vật tư nhập thành công |
| **Cảnh báo** | Thiếu tên block/layer → đặt `Draft` (vẫn nhập, nhưng chưa dùng) |
| **Lỗi** | Thiếu Mã / Tên / Đơn vị → **bỏ qua dòng đó** (báo rõ dòng nào) |
| **Phân bố theo hệ** | Xem có hệ nào bị bỏ sót không |
| **Phân bố theo cách tính** | Xem có bao nhiêu vật tư đếm / đo |

---

## 7. Sau khi import — dùng trong AutoCAD

```
1. Mở AutoCAD → gõ  MTO
2. Ô "Bộ quy tắc (JSON)"  → trỏ tới:  <MTOPro>\config\rules.json
3. Bấm "Bước 1: Quét + Phân loại"
4. Bảng kết quả sẽ có CỘT MÃ VẬT TƯ theo danh mục công ty
5. Tích chọn → "Bước 2: Xuất Excel"
```

---

## 8. Quy trình làm việc đề xuất

```
BƯỚC 1 — Phòng Dự án xuất danh mục vật tư ra Excel
         (mã, tên, quy cách, đơn vị — công ty đã có sẵn)

BƯỚC 2 — Dán 4 cột đó vào sheet DANH_MUC của file mẫu

BƯỚC 3 — Với mỗi vật tư, điền "Tên block (mẫu)" hoặc "Layer (mẫu)"
         • Nếu kỹ sư đặt tên block có quy tắc  -> dùng cột block
         • Nếu kỹ sư vẽ theo layer đúng quy ước -> dùng cột layer
         • Chưa biết -> để trống, đánh dấu Draft

BƯỚC 4 — Chạy import-materials.ps1 -DryRun  (kiểm tra)

BƯỚC 5 — Chạy import-materials.ps1          (sinh rules.json)

BƯỚC 6 — Quét thử 1 bản vẽ thật trong panel MTO
         → xem còn bao nhiêu dòng "Chưa phân loại"

BƯỚC 7 — Bổ sung mẫu block/layer cho tới khi "Chưa phân loại" = 0

BƯỚC 8 — Lưu file Excel vào thư mục chung của phòng
         (lần sau chỉ cần cập nhật + chạy lại import)
```

---

## 9. Ưu điểm của cách làm này

| Điểm | Lợi ích |
|---|---|
| **Không nhập lại danh mục** | Dán từ Excel có sẵn của công ty |
| **Một nguồn duy nhất** | File Excel là "nguồn sự thật" — sửa Excel rồi import lại |
| **Có kiểm tra tự động** | Báo rõ dòng nào thiếu gì |
| **Không cần biết JSON** | Chỉ làm việc với Excel quen thuộc |
| **Chia sẻ được** | Gửi file Excel cho cả phòng cùng điền |
| **Cập nhật dễ** | Thêm vật tư mới → thêm 1 dòng → import lại |

---

## 10. Xử lý sự cố

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Khong tim thay file danh muc` | Sai đường dẫn | Kiểm tra file ở `config\DANH_MUC_VAT_TU.xlsx` |
| `Khong tim thay sheet 'DANH_MUC'` | Đổi tên sheet | Đổi tên sheet về đúng `DANH_MUC` |
| Nhiều dòng báo **Lỗi** | Thiếu Mã / Tên / Đơn vị | Mở Excel, kiểm tra các dòng đó |
| Nhiều dòng **Cảnh báo** | Thiếu tên block/layer | Điền mẫu block/layer (hoặc để Draft) |
| Vật tư nhập rồi nhưng vẫn "Chưa phân loại" | Mẫu block/layer chưa khớp bản vẽ | Mở AutoCAD xem tên block/layer thật, sửa mẫu |
| Không mở được file `.ps1` | Chính sách PowerShell | Chạy: `powershell -ExecutionPolicy Bypass -File .\scripts\import-materials.ps1` |

---

## 11. Ví dụ đã kiểm chứng

**Dữ liệu mẫu 7 vật tư** (Camera Dome, Camera Bullet, Cáp CAT6, NVR, Màn hình, Ống PVC, Dây điện)
→ import thành công **7/7 rule, 0 lỗi, 0 cảnh báo**.

**Kiểm chứng phân loại** (block `SE.DOME CAMERA` trên bản vẽ thật):

| Bộ quy tắc | Kết quả |
|---|---|
| Bộ mẫu 110 rule (dùng `ELV-CAM-DOME-*`) | ❌ **Chưa phân loại** — "Không quy tắc nào khớp" |
| Bộ **từ Excel danh mục** (dùng `SE.DOME*`) | ✅ **Phân loại đúng**: `HE-ELV` · `VL-CCTV-001` · `Camera Dome IP` · `2MP, PoE` · `cái` |

```
KET QUA: 6 PASS / 0 FAIL
=> BO QUY TAC MAP DUOC ten ky su sang danh muc vat tu chuan
```

⇒ **Chứng minh:** nhập danh mục từ Excel → phần mềm tự nhận đúng vật tư, **không cần kỹ sư đổi cách đặt tên**.

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01.*
