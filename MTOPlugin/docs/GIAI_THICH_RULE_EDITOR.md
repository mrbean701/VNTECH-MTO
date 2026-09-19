# GIẢI THÍCH RULE EDITOR — Bộ quy tắc bóc tách khối lượng

**MTOPro · Đề tài R&D-CAD-QTO-01 · Phòng Dự án**
**Phiên bản 1.0 — 18/09/2026**

---

## 1. Rule Editor là gì?

**Rule Editor** (nút "Mở Rule Editor" trong panel `MTO`) là công cụ để khai báo
**bộ quy tắc** — tức là **danh sách các quy tắc ánh xạ**:

```
CÁCH VẼ CỦA KỸ SƯ          →        DANH MỤC VẬT TƯ CHUẨN CỦA CÔNG TY
(tên block, layer, ...)              (hệ, mã vật tư, tên, đơn vị, cách tính)
```

**Ví dụ một quy tắc thật** (trích từ bộ mẫu):

| Phần | Nội dung |
|---|---|
| **Điều kiện khớp** | Layer = `EL-COND-WALL-DN20` hoặc `EL-COND-WALL-*`, loại = hình học (Line/Polyline) |
| **Kết quả** | Hệ = `HE-DIEN` · Mã vật tư = `VL-DIEN-001` · Tên = **"Ống PVC dày 20mm"** · Quy cách = `PVC D20` · Đơn vị = `m` |
| **Cách tính** | `SumLength` (cộng chiều dài) |

Nghĩa là: **"mọi đường vẽ trên layer EL-COND-WALL-* là ống PVC D20, tính theo mét"**.

---

## 2. **CÓ — đây chính là bộ quy tắc để setup việc bóc tách khối lượng**

Nhưng cần hiểu đúng **vai trò của nó**. Hệ thống có **2 lớp**:

```
┌─────────────────────────────────────────────────────────────────┐
│ LỚP 1 — ĐẾM / ĐO  (AutoLISP, KHÔNG cần bộ quy tắc)              │
│                                                                 │
│   MTOBLK   → đếm block theo tên      "SE.DOME CAMERA = 51 cái"  │
│   MTOGEO   → đo chiều dài theo layer "Camera Cable = 1.286,9"   │
│   MTOTEXT  → đếm chữ theo prefix     "MCB 20A = 8 cái"          │
│                                                                 │
│   -> Cho ra KHỐI LƯỢNG ĐÚNG, nhưng chưa có mã vật tư / hệ        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ LỚP 2 — PHÂN LOẠI / CHUẨN HOÁ  (bộ quy tắc, panel .NET)         │
│                                                                 │
│   Khớp điều kiện (tên block / layer / thuộc tính)               │
│   Gán: hệ · mã vật tư · tên chuẩn · quy cách · đơn vị · cách tính│
│                                                                 │
│   -> Cho ra BẢNG KHỐI LƯỢNG có MÃ VẬT TƯ để đặt hàng / dự toán  │
└─────────────────────────────────────────────────────────────────┘
```

| Lớp | Cần bộ quy tắc? | Cho ra gì |
|---|---|---|
| **Lớp 1** — LISP | ❌ **Không cần** | Khối lượng theo tên thật (block/layer/text) |
| **Lớp 2** — Panel | ✅ **Cần** | Khối lượng có **mã vật tư chuẩn** |

> **Tóm lại:** bộ quy tắc là **cầu nối** giữa cách kỹ sư vẽ và danh mục vật tư của công ty.
> Không có nó thì vẫn bóc được khối lượng, nhưng **không gắn được mã vật tư**.

---

## 3. **CÓ — tên khác nhau vẫn bóc tách được**

Đây là câu hỏi quan trọng nhất. Trả lời: **CÓ, bằng 2 cách**, và **KHÔNG bắt kỹ sư phải đổi cách đặt tên**.

### Cách A — Không cần bộ quy tắc (dùng lệnh LISP)

```
MTOBLK  → click chọn 1 camera làm mẫu → ra ngay "AutoCount = 51"
MTOTABLE → in bảng lên bản vẽ
MTOCSV   → xuất Excel
```

**Kết quả:** `SE.DOME CAMERA = 51 cái` — **khối lượng đúng**, không quan tâm tên gì.

**Hạn chế:** chưa có mã vật tư, chưa phân loại hệ (sẽ là "Other").

### Cách B — Khai báo quy tắc map tên đó (Rule Editor)

Mở Rule Editor → thêm 1 quy tắc:

| Trường | Giá trị |
|---|---|
| Mã quy tắc | `R-ELV-CAM-001` |
| Mô tả | Camera dome — nhận dạng theo tên block của kỹ sư |
| Block names | `SE.DOME*;*DOME CAMERA*` ← **tên thật của công ty** |
| Layers | `*` (bất kỳ) |
| Loại đối tượng | `block` |
| Cách tính | `Count` (đếm) |
| Hệ thống | `HE-ELV` |
| Mã vật tư | `VL-CCTV-001` |
| Tên vật tư | `Camera Dome IP` |
| Quy cách | `2MP, PoE` |
| Đơn vị | `cái` |

Sau đó panel quét → tự động gán **`VL-CCTV-001` · Camera Dome IP · cái**.

> 💡 **Chỉ khai báo MỘT LẦN.** Từ đó mọi bản vẽ dùng tên đó đều tự nhận.
> Kỹ sư **không cần đổi cách đặt tên**.

---

## 4. Bằng chứng thực nghiệm (đã chạy thật)

Tôi đã viết test chứng minh cơ chế này (`tests/RuleMappingTest.cs`):

**Kịch bản:** block tên `SE.DOME CAMERA` (cách đặt tên của kỹ sư), bộ quy tắc mẫu dùng `ELV-CAM-DOME-*`.

**Kết quả chạy 1 — với BỘ QUY TẮC MẪU:**
```
--- 1) BLOCK 'SE.DOME CAMERA' voi BO QUY TAC MAU ---
  Phan loai duoc : 0
  Chua phan loai : 1
  Ly do          : Khong quy tac nao khop voi block SE.DOME CAMERA
```

**Kết quả chạy 2 — SAU KHI THÊM 1 QUY TẮC MAP:**
```
  Phan loai duoc : 1
  Chua phan loai : 0
  => He          : HE-ELV
  => Ma vat tu   : VL-CCTV-001
  => Ten vat tu  : Camera Dome IP
  => Quy cach    : 2MP, PoE
  => Don vi      : cai
  => Khoi luong  : 1
```

**Kết luận test:**
```
KET QUA: 6 PASS / 0 FAIL
=> BO QUY TAC MAP DUOC ten ky su sang danh muc vat tu chuan
```

⇒ **Chứng minh:** tên khác nhau **hoàn toàn bóc tách được** — chỉ cần khai báo quy tắc map.

---

## 5. Cấu trúc đầy đủ một quy tắc

### 5.1 Điều kiện khớp (nhiều điều kiện = AND với nhau)

| Trường | Ý nghĩa | Ví dụ |
|---|---|---|
| `entityKind` | Loại đối tượng | `block` · `geometry` · `both` · `*` |
| `blockNames` | Tên block (hỗ trợ `*`, phân cách `;`) | `SE.DOME*;*CAMERA*` |
| `effectiveBlockNames` | Tên dynamic block hiệu dụng | `CUA-*` |
| `layers` | Layer (hỗ trợ `*`, `;`) | `EL-COND-*;CCTV` |
| `geometryKinds` | Loại hình học | `Line;Polyline;Arc` |
| `attributes` | Thuộc tính block | `TEN=MCB*` |
| `linetypes` / `colorIndexes` | Kiểu đường / màu | `DASHED` / `1;2` |
| `blockNameRegex` / `layerRegex` | Biểu thức chính quy | `^SE\.DOME.*` |

> **Dấu `*` = "bất kỳ"**. Nhiều giá trị cách nhau bằng **dấu `;`**.

### 5.2 Kết quả phân loại

| Trường | Ý nghĩa | Ví dụ |
|---|---|---|
| `systemCode` | Hệ M&E | `HE-DIEN` · `HE-NUOC` · `HE-ELV` |
| `materialCode` | **Mã vật tư** | `VL-CCTV-001` |
| `materialName` | Tên vật tư chuẩn | `Camera Dome IP` |
| `specification` | Quy cách | `2MP, PoE` |
| `unit` | Đơn vị tính | `cái` · `m` · `bộ` |

### 5.3 Cách tính khối lượng

| `calculation` | Nghĩa |
|---|---|
| `Count` | Đếm số lượng |
| `SumLength` | Cộng chiều dài |
| `SumArea` | Cộng diện tích |
| `AttributeSum` | Cộng giá trị thuộc tính block |

| Trường phụ | Nghĩa |
|---|---|
| `factor` | Hệ số nhân (hao hụt, quy đổi) |
| `ceilingStep` | Bước làm tròn lên (ví dụ 3m/cây → 10m = 4 cây) |
| `priority` | Ưu tiên khi 1 đối tượng khớp nhiều quy tắc (số lớn thắng) |
| `status` | `Active` (dùng) / `Draft` / `Obsolete` |

### 5.4 Quản lý

| Trường | Nghĩa |
|---|---|
| `code` | Mã quy tắc duy nhất (`R-ELV-CAM-001`) |
| `version` | Phiên bản quy tắc |
| `description` | Mô tả |
| `createdBy` / `approvedBy` | Người khai báo / người duyệt |

> Quy tắc có `approvedBy` = có **quy trình duyệt** — phù hợp yêu cầu quản lý chất lượng.

---

## 6. Quy trình thiết lập bộ quy tắc cho công ty

```
BƯỚC 1 — Liệt kê danh mục vật tư chuẩn
         (mã vật tư, tên, quy cách, đơn vị) — do Phòng Dự án cung cấp

BƯỚC 2 — Với mỗi vật tư: xác định cách nó được VẼ trên bản vẽ
         (tên block? layer nào? ký hiệu chữ gì?)

BƯỚC 3 — Tạo quy tắc trong Rule Editor:
         điều kiện (block/layer) → kết quả (mã vật tư, đơn vị, cách tính)

BƯỚC 4 — Kiểm tra: quét thử 1 bản vẽ, xem còn bao nhiêu "Chưa phân loại"

BƯỚC 5 — Bổ sung quy tắc cho tới khi "Chưa phân loại" = 0

BƯỚC 6 — Lưu bộ quy tắc (JSON) → dùng chung cho cả phòng
```

**Thời gian ước tính:** mỗi vật tư ~1-2 phút. Với ~100 vật tư thường dùng → **khoảng 2-4 giờ** cho lần đầu; sau đó chỉ bổ sung khi có vật tư mới.

---

## 7. Mẹo tạo quy tắc hiệu quả

| Mẹo | Làm |
|---|---|
| **Dùng wildcard rộng vừa đủ** | `SE.DOME*` thay vì liệt kê từng tên |
| **Ưu tiên quy tắc đặc thù cao hơn** | Quy tắc cho `SE.DOME CAMERA` có `priority` cao hơn quy tắc `*CAMERA*` chung |
| **Tận dụng layer** | Nếu kỹ sư vẽ theo layer đúng quy ước → khớp theo layer ổn định hơn tên block |
| **Kiểm tra định kỳ** | Panel báo "Chưa phân loại" — đó là **danh sách quy tắc còn thiếu** |
| **Xuất/nhập JSON** | Nút "Xuất JSON"/"Nhập từ JSON" để chia sẻ giữa các máy |

---

## 8. Lưu ý và giới hạn

| # | Nội dung |
|---|---|
| 1 | Bộ quy tắc mẫu (110 quy tắc) dùng **tên giả định** — **phải sửa cho khớp công ty** trước khi dùng |
| 2 | Lớp LISP (MTOBLK/MTOGEO/MTOTEXT) **không dùng** bộ quy tắc → luôn bóc được khối lượng thô |
| 3 | Mỗi lần chèn block = **1 dòng chi tiết**; tổng hợp gộp theo mã vật tư |
| 4 | Khi 1 đối tượng khớp nhiều quy tắc → **quy tắc `priority` lớn nhất thắng** |
| 5 | "Chưa phân loại" **không phải lỗi** — là danh sách quy tắc cần bổ sung |

---

## 9. Trả lời ngắn gọn 3 câu hỏi

| Câu hỏi | Trả lời |
|---|---|
| **Rule Editor là gì?** | Công cụ khai báo **ánh xạ**: cách vẽ của kỹ sư (block/layer) → danh mục vật tư chuẩn (hệ, mã, tên, đơn vị, cách tính) |
| **Có phải bộ quy tắc để setup bóc tách không?** | **ĐÚNG** — nhưng là lớp **phân loại/chuẩn hoá**. Lớp **đếm/đo** chạy bằng LISP và **không cần** quy tắc |
| **Tên khác nhau có bóc được không?** | **CÓ.** (A) Dùng LISP `MTOBLK` — đếm trực tiếp theo tên thật, không cần quy tắc. (B) Khai báo quy tắc map tên đó → có thêm mã vật tư chuẩn. **Đã chứng minh bằng test: 6 PASS / 0 FAIL** |

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01.*
