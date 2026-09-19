# HƯỚNG DẪN ĐO CÁP & IN BẢNG KHỐI LƯỢNG LÊN BẢN VẼ

**MTOPro · Đề tài R&D-CAD-QTO-01 · Phòng Dự án**
**Phiên bản 1.0 — 18/09/2026**

> Tài liệu này hướng dẫn **2 việc cụ thể**: (1) đo chiều dài cáp/ống, (2) in bảng khối lượng
> lên bản vẽ. Đã kiểm chứng thực tế trên bản vẽ *"MB Camera khu Restaurant, Recepption"*.

---

## ⚠️ ĐỌC TRƯỚC: KIỂM TRA ĐƠN VỊ BẢN VẼ

**Đây là bước quan trọng nhất.** Nếu sai đơn vị, **mọi con số chiều dài đều sai**.

### Kiểm tra

Gõ lệnh:
```
INSUNITS
```
Kết quả và ý nghĩa:

| Giá trị | Đơn vị | Có đúng cho bản vẽ VN? |
|---|---|---|
| `4` | Milimét (mm) | ✅ Đúng nhất |
| `6` | Mét (m) | ✅ Đúng |
| **`1`** | **Inch (in)** | ❌ **SAI** — bản vẽ VN không dùng inch |
| `2` | Foot (ft) | ❌ Sai |
| `0` | Không khai báo | ⚠️ Công cụ sẽ báo "?" |

### Nếu `INSUNITS = 1` (inch) trên bản vẽ Việt Nam

Đây là **lỗi phổ biến** do bản vẽ gốc nước ngoài. Ví dụ thực tế đã gặp:
đo được `1286.91` nhưng đơn vị ghi là `in` — trong khi bản vẽ vẽ bằng **mm**.

**Cách xử lý:**

1. **Xác định đơn vị thật** bằng cách đo một kích thước đã biết (ví dụ cửa 900mm):
   ```
   DIST     (hoặc gõ DI)
   ```
   Chọn 2 điểm của cửa. Nếu AutoCAD báo `900` → bản vẽ vẽ bằng **mm** (dù INSUNITS=inch).

2. **Ghi lại đơn vị thật** để tự quy đổi khi đọc kết quả:
   - Báo `900` → mm → chia 1000 để ra mét
   - Báo `0.9` → mét → dùng trực tiếp
   - Báo `35.4` → inch → nhân 0.0254 để ra mét

3. **Ghi đè đơn vị cho kết quả MTO** bằng lệnh `MTOCFG`:
   ```
   MTOCFG
   → chọn sửa khoá UNIT
   → nhập: mm      (hoặc m)
   ```

> 🔧 **Đề xuất cải tiến đã ghi nhận:** bổ sung cảnh báo tự động khi `INSUNITS = 1` hoặc `2`
> trên bản vẽ có đơn vị đo thực tế là mm/m, và cho phép chọn đơn vị đích để quy đổi.

---

## PHẦN 1 — ĐO CHIỀU DÀI CÁP

### Bước 1.1 — Xác định layer chứa cáp

Gõ `MTOHELP` hoặc dùng lệnh `LAYER` để xem tên layer.

**Các tên layer cáp thường gặp:**

| Nhóm | Tên layer mẫu |
|---|---|
| Cáp camera | `Camera Cable`, `ELV-CCTV block`, `CCTV` |
| Máng/tray cáp | `ELV-TRAY`, `1-ELV-Tray&Conduit`, `ELV-LINE-LT` |
| Thiết bị ELV | `ELV-EQP`, `1-ELV-Equipment` |
| Điện nhẹ khác | `ELV- QUANG` |

> Nếu không chắc layer nào, chạy `MTOSEL` trước để khảo sát (xem Bước phụ bên dưới).

### Bước 1.2 — Chạy lệnh đo

Gõ:
```
MTOGEO
```

Công cụ hỏi lần lượt **3 câu**:

**Câu 1 — Loại đối tượng:**
```
Loai [LINE,LWPOLYLINE,POLYLINE,ARC,CIRCLE] <LINE,LWPOLYLINE>: 
```
→ Gõ `LINE,LWPOLYLINE,POLYLINE,ARC` rồi **Enter**
*(hoặc chỉ Enter để dùng mặc định `LINE,LWPOLYLINE`)*

**Câu 2 — Layer:**
```
Layer (wildcard *, Enter = tat ca): 
```
→ Gõ danh sách layer, cách nhau bằng dấu phẩy:
```
Camera Cable,ELV-TRAY,ELV-LINE-LT
```
→ hoặc dùng wildcard: `ELV-*` (mọi layer bắt đầu bằng ELV-)
→ hoặc Enter để lấy **tất cả** layer

**Câu 3 — Chọn đối tượng trên bản vẽ:**
```
Select objects:
```

Có **2 cách**:

| Cách | Thao tác | Dùng khi |
|---|---|---|
| **Quét vùng** | Kéo chuột quét quanh khu vực cần đo → Enter | Chỉ đo 1 tầng / 1 phòng |
| **Chọn tất cả** | Gõ `all` → Enter | Đo toàn bộ bản vẽ |

> 💡 **Mẹo:** gõ `all` là nhanh nhất khi đã lọc layer ở Câu 2 —
> bộ lọc layer sẽ tự loại các đối tượng không liên quan.

### Bước 1.3 — Đọc kết quả

Màn hình hiện:
```
Da xu ly 5 doi tuong.
Don vi ghi vao ket qua: in
Tong chieu dai: 1286.91 in
DB co 1 dong.
```

**Kiểm tra ngay đơn vị** ở dòng thứ 2:
- Nếu là `mm` hoặc `m` → ✅ dùng được
- Nếu là `in` hoặc `ft` → ⚠️ **xem lại mục ĐỌC TRƯỚC ở trên**

> 📌 Lưu ý kỹ thuật: công cụ **gộp theo layer** — mỗi layer cho ra **1 dòng** trong bảng,
> cộng dồn mọi đoạn trên layer đó. Đây là cách gộp đúng cho bóc tách khối lượng.

### Bước phụ — Khảo sát layer trước khi đo (tuỳ chọn)

Nếu chưa biết layer nào chứa cáp:
```
MTOSEL
Che do chon [W/C/WP/CP/F] <W>: W
Loai doi tuong: LINE,LWPOLYLINE
Layer: *          (hoặc Enter)
→ quét chọn vùng cần khảo sát
```
Công cụ in ra **bảng tổng hợp theo layer** để bạn biết layer nào có bao nhiêu đối tượng.

---

## PHẦN 2 — GIẢI THÍCH CÁC LỆNH & CÁCH SỬ DỤNG

### 2.-1 — Biết mình đang ở lệnh nào (hiển thị tên lệnh)

MTOPro hiển thị tên lệnh đang chạy ở **3 nơi**:

**1. Banner trên dòng lệnh** — ngay khi lệnh bắt đầu:
```
==============================================================
  MTOGEO  --  Do chieu dai cap / ong / tray
==============================================================
```

**2. Thanh trạng thái (góc dưới màn hình)** — tự động cho **mọi lệnh**:
```
MTOPro > MTOGEO | Do chieu dai cap / ong / tray
```
Cơ chế: biến hệ thống `MODEMACRO` dùng DIESEL `$(getvar,cmdnames)` — luôn hiển thị
**tên lệnh đang chạy**, cập nhật tự động, không cần làm gì.

**3. Kết thúc lệnh**:
```
---- MTOGEO : ket thuc ----
```

#### Bật / tắt hiển thị thanh trạng thái

```
MTOTITLE
```
```
Trang thai hien tai: DANG BAT
Bat/Tat [ON/OFF] <ON>: ON
=> Da BAT hien thi ten lenh tren thanh trang thai.
```

> 💡 Nếu không muốn MTOPro thay đổi thanh trạng thái, gõ `MTOTITLE` → `OFF`.
> Khi tắt, thanh trạng thái trở về mặc định của AutoCAD (`MODEMACRO` rỗng).

#### Mẹo nhận biết lệnh nào đang chờ trả lời

Khi lệnh hỏi, **prompt có tiền tố tên lệnh**:
```
[MTOGEO] Layer (wildcard *, Enter = tat ca):
```
→ Nhìn tiền tố là biết ngay đang ở lệnh nào, không bị lạc giữa 23 lệnh.

---

Phần này giải thích **từng lệnh** liên quan đến đo cáp và in bảng: lệnh làm gì,
gõ thế nào, trả lời ra sao, và đọc kết quả ở đâu.

### 2.0 — Bảng tra nhanh: dùng lệnh nào?

| Lệnh | Làm gì | Khi nào dùng | Cần tương tác? |
|---|---|---|---|
| `MTOHELP` | In danh sách mọi lệnh | Lần đầu, hoặc quên lệnh | Không |
| `MTOSEL` | Chọn vùng + khảo sát theo layer | **Trước khi đo** — để biết layer nào có gì | Có (quét chuột) |
| `MTOGEO` | **Đo chiều dài** cáp/ống/tray | Bóc khối lượng cáp | Có (chọn đối tượng) |
| `MTOBLK` | Đếm thiết bị theo block | Đếm camera, đầu ghi, tủ rack | Có (chọn block mẫu) |
| `MTOTEXT` | Đếm thiết bị ghi bằng chữ | Thiết bị chú thích bằng TEXT | Có (quét chọn) |
| `MTOLIST` | **Xem trước bảng** trên dòng lệnh | Kiểm tra số liệu trước khi vẽ | Không |
| `MTOTABLE` | **Vẽ bảng lên bản vẽ** | In bảng khối lượng | Có (click điểm gốc) |
| `MTOTESTNATIVE` | **Tự kiểm tra** bảng NATIVE có dữ liệu | Khi nghi bảng bị rỗng | Không |
| `MTOCSV` | Xuất file CSV | Gửi báo cáo / mở Excel | Không |
| `MTOSNAP` | Chụp ảnh dữ liệu trước khi sửa | Trước `MTOUPDATE` | Không |
| `MTOUNDO` | Khôi phục từ ảnh chụp | Khi sửa nhầm | Không |
| `MTOFIND` | Tìm + zoom tới đối tượng | Đối chiếu ngược bản vẽ | Không |
| `MTOCFG` | Cấu hình theo bản vẽ (đơn vị, tầng...) | Ghi đè đơn vị, lưu thiết lập | Không |

> **Nguyên tắc chung:** các lệnh đều **cộng dồn vào cùng một DB** (`*MTO-DB*`).
> Chạy `MTOGEO` rồi `MTOBLK` thì DB có **cả hai loại** — và `MTOTABLE` in ra bảng gộp.

---

### 2.1 — Lệnh `MTOGEO` (đo chiều dài cáp)

#### Công dụng
Đo tổng chiều dài các đối tượng hình học (LINE, LWPOLYLINE, POLYLINE, ARC, CIRCLE),
**gộp theo layer** — mỗi layer thành **1 dòng** trong bảng.

#### Cú pháp
Gõ `MTOGEO` rồi trả lời **3 câu hỏi** liên tiếp.

#### Hỏi 1 — Loại đối tượng

```
Loai [LINE,LWPOLYLINE,POLYLINE,ARC,CIRCLE] <LINE,LWPOLYLINE>: 
```

| Trả lời | Kết quả |
|---|---|
| Enter | Dùng mặc định `LINE,LWPOLYLINE` |
| `LINE,LWPOLYLINE,POLYLINE,ARC` | Đo cả cung tròn (cần cho cáp uốn cong) |
| `CIRCLE` | Đo chu vi vòng tròn |

> 💡 **Nên nhập đủ** `LINE,LWPOLYLINE,POLYLINE,ARC` — nếu thiếu `ARC`, các đoạn cáp
> uốn cong sẽ **không được tính** và tổng chiều dài bị hụt.

#### Hỏi 2 — Layer

```
Layer (wildcard *, Enter = tat ca): 
```

| Trả lời | Kết quả |
|---|---|
| Enter | Lấy **tất cả** layer (dễ lẫn với kiến trúc!) |
| `Camera Cable,ELV-TRAY` | Chỉ 2 layer này (phân cách bằng **dấu phẩy**) |
| `ELV-*` | Mọi layer **bắt đầu** bằng `ELV-` |
| `*CABLE*` | Mọi layer **chứa** chữ `CABLE` |

**Ký tự wildcard:**

| Ký tự | Nghĩa | Ví dụ |
|---|---|---|
| `*` | Bất kỳ chuỗi ký tự nào | `ELV-*` khớp `ELV-TRAY`, `ELV-CCTV block` |
| `?` | Đúng 1 ký tự | `ELV-?` khớp `ELV-A` |
| `[abc]` | 1 trong các ký tự | `T[12]` khớp `T1`, `T2` |

> ⚠️ **Cảnh báo:** để trống ở câu này (Enter) nghĩa là **đo toàn bộ bản vẽ** — bao gồm
> cả đường bao tường, ký hiệu cửa, nét hatch... Số liệu sẽ **rất lớn và vô nghĩa**.
> **Luôn nhập layer cụ thể.**

#### Hỏi 3 — Chọn đối tượng

```
Select objects:
```

| Cách | Thao tác | Kết quả |
|---|---|---|
| **Quét vùng** | Kéo chuột quét quanh khu vực → Enter | Chỉ đo trong vùng |
| **Chọn tất cả** | Gõ `all` → Enter | Đo mọi đối tượng **khớp layer đã lọc** |
| **Huỷ** | Enter ngay | Không đo gì |

> 💡 **Mẹo:** đã lọc layer ở Hỏi 2 rồi thì **gõ `all` là nhanh nhất** — bộ lọc layer
> tự loại các đối tượng không liên quan.

#### Đọc kết quả

```
Da xu ly 574 doi tuong.
Don vi ghi vao ket qua: mm
Tong chieu dai: 3337972.5606 mm
DB co 14 dong.
```

| Dòng | Ý nghĩa |
|---|---|
| `Da xu ly ... doi tuong` | Số đối tượng được đo thành công |
| `Don vi ghi vao ket qua` | **Đơn vị** — phải kiểm tra dòng này! |
| `Tong chieu dai` | Tổng cộng **toàn bộ** đối tượng đã chọn |
| `DB co ... dong` | DB có bao nhiêu **dòng** (= số layer khác nhau) |

> 📌 **Lưu ý:** `Tong chieu dai` là tổng của **tất cả**, còn bảng in ra có **nhiều dòng**
> vì gộp theo layer. Ví dụ: 574 đối tượng → 14 dòng (14 layer) → tổng 3.337.972 mm.

---

### 2.2 — Lệnh `MTOLIST` (xem trước bảng)

#### Công dụng
In bảng kết quả ra **dòng lệnh** để kiểm tra — **không vẽ gì lên bản vẽ**.

#### Cú pháp
```
MTOLIST
```
Không hỏi gì. In ngay bảng:
```
CATEGORY       TYPE           NAME                       QTY     LENGTH      UNIT
--------------------------------------------------------------------------------
ELV            CAM            cam                        2                   cai
Other          Camera Cable   Camera Cable               5       1286.9135   mm
Other          SE.DOME        SE.DOME CAMERA             51                  cai
```

#### Khi nào dùng
**Luôn chạy trước `MTOTABLE`** — để phát hiện sớm:
- Đơn vị sai (cột `UNIT` hiện `in` thay vì `mm`)
- Lọc nhầm layer (số dòng quá nhiều / quá ít)
- Phân loại sai (cột `CATEGORY` toàn `Other`)

> ✅ Sửa xong ở bước này rồi mới vẽ bảng — tránh phải xoá bảng trên bản vẽ.

---

### 2.3 — Lệnh `MTOTABLE` (vẽ bảng lên bản vẽ)

#### Điều kiện
**DB phải có dữ liệu.** Nếu chưa, chạy trước `MTOGEO` / `MTOBLK` / `MTOTEXT`.

Nếu DB rỗng, lệnh báo:
```
DB dang rong. Hay chay MTOTEXT / MTOBLK / MTOGEO truoc.
```

#### Cú pháp — 2 câu hỏi

**Hỏi 1 — Điểm gốc:**
```
Chon diem goc bang (goc trai-tren): 
```
→ **Click chuột** vào vị trí đặt **góc trái-trên** của bảng.
Nên chọn vùng trống cạnh khu vực bản vẽ (không đè lên hình).

> Bấm `Esc` để huỷ nếu chọn nhầm vị trí.

**Hỏi 2 — Layer cho bảng:**
```
Layer cho bang <MTO-TABLE>: 
```
→ Enter để dùng `MTO-TABLE`, hoặc gõ tên riêng (ví dụ `MTO-BANG-CAP`).

> Công cụ **tự tạo layer** nếu chưa có (màu xanh, nét Continuous).
> Đặt layer riêng giúp **tắt/bật/in riêng** bảng mà không ảnh hưởng bản vẽ.

#### Đọc kết quả

```
Da tao bang NATIVE (ActiveX Table) - co the sua bang TABLEEDIT.
So dong: 17
Layer: MTO-TABLE
Che do: NATIVE
```

---

### 2.4 — Hai chế độ vẽ bảng: NATIVE và GRID

Công cụ **tự dò** và chọn chế độ phù hợp — bạn không cần làm gì.

| | **NATIVE** | **GRID** |
|---|---|---|
| **Bản chất** | Đối tượng `TABLE` thật của AutoCAD | Nhiều `TEXT` + `LINE` xếp thành bảng |
| **Tạo bằng** | ActiveX (`vla-AddTable`) | `entmake` |
| **Có ở** | AutoCAD đầy đủ | Mọi nơi (kể cả AutoCAD LT) |
| **Sửa nội dung** | `TABLEEDIT` — sửa như bảng Excel | Sửa từng ô bằng `DDEDIT` |
| **Dòng subtotal** | Có | Có |
| **In ra** | Như bảng chuẩn | Như bảng chuẩn |

**Khi nào rơi vào GRID:** khi không có ActiveX (AutoCAD LT, môi trường headless),
hoặc khi NATIVE tạo thất bại. Công cụ **tự chuyển** và báo:
```
Native khong dung duoc -> da tao bang dang GRID (TEXT + LINE).
```

> ⚠️ **Đã sửa lỗi quan trọng (v1.0.2):** bản cũ có thể tạo bảng NATIVE nhưng
> **toàn bộ ô bị RỖNG** — do lỗi khi ghi dữ liệu vào ô bị "nuốt" âm thầm.
> Nay công cụ **kiểm tra lại** ô đầu tiên sau khi ghi; nếu rỗng thì **tự xoá bảng
> và chuyển sang GRID** (luôn có bảng có dữ liệu).
> Lệnh `MTOTESTNATIVE` (mục 2.5) giúp kiểm tra nhanh.

---

### 2.5 — Lệnh `MTOTESTNATIVE` (tự kiểm tra bảng)

#### Công dụng
Tạo một **bảng mẫu 3 dòng** ở gốc `(0,0)`, **đọc lại từng ô** và đối chiếu với dữ liệu
gửi vào — rồi **tự xoá bảng mẫu**. Dùng để xác nhận bảng NATIVE **không bị rỗng**.

#### Cú pháp
```
MTOTESTNATIVE
```
Không hỏi gì.

#### Kết quả

**Nếu tốt:**
```
KET QUA: 27 o DUNG / 0 o LECH
=> BANG NATIVE HOAT DONG TOT (o co du lieu, khong rong).
(Da xoa bang mau.)
```

**Nếu có vấn đề:**
```
  LECH o [1,3]: gui='SE.DOME CAMERA' nhan=''
KET QUA: 24 o DUNG / 3 o LECH
=> BANG NATIVE CO VAN DE - bao lai de kiem tra.
```

#### Khi nào dùng
- Sau khi cài bản mới, muốn xác nhận bảng hoạt động
- Khi `MTOTABLE` in ra bảng **trông rỗng**
- Khi gửi báo lỗi cho Phòng Dự án (kèm kết quả lệnh này)

---

### 2.6 — Bảng vẽ ra trông thế nào

```
STT  CATEGORY    TYPE           NAME                    QTY     LENGTH      UNIT
---------------------------------------------------------------------------------
1    ELV         CAM            cam                     2                   cai
2    Other       Camera Cable   Camera Cable            5       1286.9135   mm
3    Other       SE.DOME        SE.DOME CAMERA          51                  cai
     Subtotal Other                                     56      1286.9135
     TONG CONG                                          58      1286.9135
```

| Thành phần | Ý nghĩa |
|---|---|
| **Cột STT** | Đánh số tự động từ 1 |
| **Dòng `Subtotal <hệ>`** | Tạm tính theo từng Category — **tự sinh** khi có nhiều hệ |
| **Dòng `TONG CONG`** | Tổng toàn bộ — luôn ở cuối |

**9 cột của bảng:** STT · CATEGORY · TYPE · NAME · QTY · LENGTH · UNIT · LAYER · NOTES

---

### 2.7 — Sửa bảng sau khi vẽ

| Muốn | Làm |
|---|---|
| Sửa 1 ô (chế độ NATIVE) | `TABLEEDIT` → chọn bảng → sửa trực tiếp |
| Sửa 1 ô (chế độ GRID) | `DDEDIT` → chọn ô text → sửa |
| Di chuyển cả bảng | `MOVE` → chọn `all` với layer `MTO-TABLE` |
| Xoá bảng | `ERASE` → `all` → layer `MTO-TABLE` |
| Vẽ lại chỗ khác | `ERASE` bảng cũ → chạy lại `MTOTABLE` |
| Đổi nội dung rồi vẽ lại | Sửa DB (`MTOBLKMAN`, `MTODED`…) → `MTOTABLE` (bảng cũ **không** tự cập nhật) |

> ⚠️ **Quan trọng:** bảng đã vẽ là **ảnh chụp** tại thời điểm vẽ.
> Sửa dữ liệu xong phải **xoá bảng cũ và vẽ lại** — bảng không tự đồng bộ.

---

## PHẦN 3 — XUẤT KÈM EXCEL / CSV

Sau khi đo và in bảng, xuất dữ liệu để gửi báo cáo:

| Lệnh | Kết quả |
|---|---|
| `MTOCSV` | File `.csv` — mở được bằng Excel, 15 cột |
| `MTOTABLE` | Bảng trên bản vẽ (đã làm ở Phần 2) |

**Để có file Excel (.xlsx) đẹp:**

```
MTOCSV
→ Enter để dùng tên file mặc định
→ file CSV được tạo cạnh bản vẽ
```

Sau đó dùng tiện ích chuyển sang Excel (nếu có cài sẵn):
```powershell
.\scripts\export-excel.ps1 -Csv "duong-dan-file.csv"
```
→ Tạo file `.xlsx` có kẻ khung, header in đậm, **tự giải mã tiếng Việt**.

> ⚠️ **Lưu ý đã ghi nhận:** file CSV do AutoCAD ghi có thể chứa ký tự escape
> `\U+0111` thay vì `đ`. Tiện ích `export-excel.ps1` **tự giải mã** khi chuyển sang Excel.
> Khi mở CSV trực tiếp bằng Excel, có thể thấy ký tự lạ.

---

## PHẦN 4 — VÍ DỤ THỰC TẾ ĐÃ CHẠY

**Bản vẽ:** `MB Camera khu Restaurant,Recepption.dwg` (17.3 MB)

| Thông số bản vẽ | Giá trị |
|---|---|
| Layers / Block definitions | 359 / 492 |
| TEXT-MTEXT / Hình học | 1.019 / 54.915 |
| `INSUNITS` | **1 = inch** ⚠️ |

**Kết quả đo và in bảng** (thời gian: **6.9 giây**):

```
--- BUOC 1: Kiem tra du lieu cap/tray ---
Doi tuong tren cac layer cap = 5
Tong chieu dai = 1286.9135 in | bo qua = 0

--- BUOC 2: Nap vao DB ---
ADDED = 5 | DB = 1 dong

--- BUOC 3: Them camera ---
DB sau khi them camera = 3 dong

--- BUOC 4: Bang khoi luong ---
ELV    | CAM          | cam             | 2  |        | cai
Other  | Camera Cable | Camera Cable    | 5  | 1286.91| in
Other  | SE.DOME      | SE.DOME CAMERA  | 51 |        | cai

--- BUOC 5: Ve bang len ban ve ---
So dong bang = 7
Da ve 40 o text
Entity tren layer MTO-BANG-CAP = 58

--- BUOC 6: Luu DWG moi ---
Da luu: MB-Camera-BANG-CAP.dwg
```

**Vấn đề phát hiện qua ví dụ này:**

| # | Vấn đề | Ảnh hưởng |
|---|---|---|
| 1 | `INSUNITS = 1` (inch) | Chiều dài cáp ghi `in` — **sai đơn vị thực tế** |
| 2 | Chỉ có **5 đối tượng** cáp | Có thể tuyến cáp nằm ở layer khác hoặc bản vẽ khác |
| 3 | `SE.DOME CAMERA` → Category `Other` | Bộ quy tắc mẫu chưa khớp tên block thực tế |

---

## PHẦN 5 — XỬ LÝ SỰ CỐ

| Hiện tượng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Khong chon duoc doi tuong nao` | Layer filter không khớp | Kiểm tra tên layer; thử wildcard `*` |
| Tổng chiều dài = 0 | Chọn nhầm loại đối tượng | Cáp có thể là `LWPOLYLINE` chứ không phải `LINE` — thêm vào Câu 1 |
| Đơn vị hiện `?` | `INSUNITS = 0` | Ghi đè bằng `MTOCFG` → khoá `UNIT` |
| Đơn vị hiện `in` / `ft` | Bản vẽ gốc nước ngoài | Xem mục **ĐỌC TRƯỚC** |
| `DB dang rong` khi `MTOTABLE` | Chưa đo/đếm gì | Chạy `MTOGEO` / `MTOBLK` / `MTOTEXT` trước |
| Bảng vẽ đè lên bản vẽ cũ | Chọn điểm gốc trùng | Dùng `MTOSNAP` trước, hoặc `UNDO` rồi vẽ lại chỗ khác |
| Muốn xoá bảng | — | `ERASE` → chọn `all` với layer `MTO-TABLE` (hoặc layer bạn đặt) |

---

## PHẦN 6 — QUY TRÌNH ĐẦY ĐỦ (TÓM TẮT)

```
1.  INSUNITS                 ← KIỂM TRA ĐƠN VỊ (quan trọng nhất)
2.  MTOGEO                   ← đo cáp: loại → layer → all
3.  MTOBLK                   ← đếm thiết bị (camera, đầu ghi...)
4.  MTOLIST                  ← xem trước bảng
5.  MTOTABLE                 ← in bảng lên bản vẽ: điểm gốc → layer → Enter
6.  MTOCSV                   ← xuất CSV → chuyển Excel
7.  QSAVE                    ← lưu bản vẽ
```

**Thứ tự quan trọng:** đo/đếm **trước**, in bảng **sau** — vì `MTOTABLE` lấy dữ liệu
từ DB, DB rỗng thì không vẽ được gì.

---

## PHẦN 7 — MẸO DÙNG NHANH

| Muốn | Làm |
|---|---|
| Đo cáp **toàn bộ** bản vẽ | `MTOGEO` → layer `*` → gõ `all` |
| Đo cáp **1 tầng** | `MTOGEO` → layer cáp → **quét vùng** tầng đó |
| Bảng **riêng cho cáp** | Trước khi `MTOTABLE`, xoá DB các mục khác bằng cách chỉ chạy `MTOGEO` |
| Bảng **gộp nhiều hệ** | Chạy lần lượt `MTOGEO` → `MTOBLK` → `MTOTEXT`, rồi `MTOTABLE` (DB cộng dồn) |
| Gán **tầng** cho dữ liệu | `MTOFLOOR` — gán theo layer hoặc theo vùng đã chọn bằng `MTOSEL` |
| Tìm lại đối tượng đã đo | `MTOFIND` — nhập số thứ tự hoặc từ khoá → tự zoom tới |
| Sửa số liệu **trên bản vẽ** | `MTOSNAP` (chụp trước) → `MTOUPDATE` → `MTOUNDO` nếu cần khôi phục |

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01. Mọi góp ý về quy trình xin gửi Phòng Dự án.*
