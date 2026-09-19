# HƯỚNG DẪN SỬ DỤNG — MTOPro (Bóc tách khối lượng M&E trên AutoCAD)

**Đề tài:** R&D-CAD-QTO-01 · **Phiên bản:** 1.0 (bản pilot để test thực tế)
**Ngày:** 18/09/2026 · **Đơn vị:** Phòng Dự án

> ⚠️ **Đây là bản PILOT** gửi bộ phận chuyên môn test thực tế. Vui lòng đọc mục
> [9. Những điểm CẦN SOI KỸ khi test](#9-những-điểm-cần-soi-kỹ-khi-test) trước khi bắt đầu.

---

## 1. Mục đích

Công cụ giúp kỹ sư M&E **bóc tách khối lượng tự động từ bản vẽ AutoCAD** cho 3 hệ:
**Điện — Nước — Điện nhẹ (ELV)**, thay vì đếm/đo thủ công.

Công cụ chạy **bên trong AutoCAD**, không cần phần mềm ngoài.

---

## 2. Yêu cầu hệ thống

| Thành phần | Yêu cầu |
|---|---|
| AutoCAD | **2023** (đã kiểm chứng) — các bản khác chưa kiểm chứng |
| Hệ điều hành | Windows 10/11 (64-bit) |
| Quyền | **Không cần quyền Admin** (cài cho người dùng hiện tại) |
| Khác | Không cần .NET SDK, không cần Excel |

---

## 3. Cài đặt (1 file, double-click)

1. Nhận file **`MTOPro.Setup-1.0.0.exe`**
2. **Đóng AutoCAD** (nếu đang mở)
3. Double-click file EXE → làm theo hướng dẫn trên màn hình
4. **Mở lại AutoCAD**

Bộ cài tự động:
- Copy các module LISP vào `%LOCALAPPDATA%\MTOPro\lisp\`
- Copy bộ quy tắc mẫu vào `%LOCALAPPDATA%\MTOPro\config\rules.json`
- Thêm thư mục LISP vào **Trusted Locations** của AutoCAD (bắt buộc — xem mục 10)
- Đăng ký tự nạp LISP khi AutoCAD khởi động (**Startup Suite**)
- Copy tài liệu vào `%LOCALAPPDATA%\MTOPro\docs\`

### Kiểm tra cài đặt thành công

Mở AutoCAD, gõ:

```
MTOHELP
```

Nếu hiện danh sách lệnh (MTOBLK, MTOTEXT, MTOSEL…) là **cài đặt thành công**.

Ngay khi mở AutoCAD, dòng thông báo sau sẽ hiện trên dòng lệnh:

```
MTOPro v0.6.0-lisp : da nap 16/16 module.
```

> Nếu báo *"Unknown command"* hoặc *"da nap 0/16 module"* → xem mục
> [10. Xử lý sự cố](#10-xử-lý-sự-cố).

### Đã kiểm chứng trước khi phát hành

| Nội dung | Kết quả |
|---|---|
| Bộ cài chạy (cài/gỡ, chế độ ẩn) | ✅ Đã chạy thật |
| Cài đúng 17 file LISP + rules.json + 2 tài liệu | ✅ |
| Tự nạp LISP từ thư mục cài | ✅ `da nap 16/16 module` |
| Lệnh .NET từ bundle (NETLOAD + MTOZOOM) | ✅ Chạy đúng |
| 617 test chức năng trên AutoCAD 2023 engine | ✅ PASS toàn bộ |

---

## 4. Quy trình sử dụng (7 bước)

```
BẢN VẼ  →  CHỌN VÙNG  →  NHẬN DẠNG  →  GOM NHÓM
        →  ĐẾM/ĐO  →  ĐIỀU CHỈNH  →  XUẤT  →  ĐỐI CHIẾU LẠI
```

Công cụ có **2 cách dùng** — chọn cách phù hợp:

| Cách | Lệnh | Ưu điểm | Phù hợp |
|---|---|---|---|
| **A. Giao diện panel** | `MTO` | Có nút bấm, bảng kết quả trực quan, tích chọn dòng để xuất | Người mới, thao tác thường ngày |
| **B. Lệnh dòng lệnh** | `MTOTEXT`, `MTOBLK`… | Nhanh, linh hoạt, dùng được cho script/batch | Người quen, xử lý hàng loạt |

> **Quan trọng:** Cả 2 cách **dùng chung một bộ dữ liệu** (`*MTO-DB*`). Ví dụ: quét bằng `MTOTEXT`
> rồi mở panel `MTO` vẫn thấy dữ liệu đó, và ngược lại.

### 4.0 Dùng giao diện panel (lệnh `MTO`)

1. Gõ `MTO` → panel hiện ra bên phải màn hình
2. **Bộ quy tắc đã được tự động nạp sẵn** (không cần chọn) —
   đường dẫn tự điền: `%LOCALAPPDATA%\MTOPro\config\rules.json`
3. **Bước 1:** chọn phạm vi quét (radio) → bấm **Quét + Phân loại**
   → bảng kết quả hiện ra bên dưới
4. **Bước 2:** tích chọn các dòng muốn xuất → bấm **Xuất các mục đã chọn**
   (hoặc **Xuất TOÀN BỘ**)
5. **Nhấp đúp** một dòng kết quả → zoom tới đúng đối tượng trên bản vẽ

**Nếu ô "Bộ quy tắc (JSON)" trống:** bấm nút `...` cạnh ô đó và chọn file
`%LOCALAPPDATA%\MTOPro\config\rules.json`. Hoặc bấm **Mở Rule Editor** để tự soạn bộ quy tắc.

**Các nút khác trong panel:** `Mở Rule Editor` (soạn/sửa quy tắc), `Kiểm tra` (rà lỗi bộ quy tắc).

---

### Bước 1 — Nhận dạng đối tượng

| Lệnh | Dùng khi | Ví dụ |
|---|---|---|
| `MTOTEXT` | Đếm thiết bị ghi bằng **chữ** (TEXT/MTEXT) | `MCB 32A`, `Đèn LED 10W` |
| `MTOBLK` | Đếm **block** (ký hiệu thiết bị) | block ổ cắm, camera, van |
| `MTOGEO` | Đo **chiều dài** ống/cáp/khay | LINE, LWPOLYLINE |

Ví dụ `MTOTEXT`:
```
Lệnh: MTOTEXT
Loại text [TEXT,MTEXT] <TEXT,MTEXT>: ↵
Layer (wildcard *, Enter = tat ca): EL-*
Chọn đối tượng: (quét chọn vùng bản vẽ)
→ Da xu ly 142 text, bo qua 0 doi tuong khong phai text.
```

Kết quả được gom theo **PREFIX → CATEGORY** tự động:
`MCB 20A` → prefix `MCB` → hệ `Electrical`

### Bước 2 (tuỳ chọn) — Chọn vùng trước

Nếu chỉ muốn bóc một khu vực (1 tầng, 1 phòng):

```
Lệnh: MTOSEL
Che do chon [Window(W)/Crossing(C)/WindowPolygon(WP)/CrossPolygon(CP)/Fence(F)] <W>: W
Loai doi tuong: TEXT,MTEXT,INSERT
Layer: EL-*
→ kéo chọn vùng trên bản vẽ
→ Da luu 87 handle vao *MTO-LAST-SELECTION*
```

Sau đó `MTOFLOOR` (chế độ 2) để gán vùng vừa chọn vào một **tầng**.

### Bước 3 — Cộng/trừ số lượng thủ công

Khi thực tế khác bản vẽ (thiết bị đã thay, chừa lại…):

```
Lệnh: MTOBLKMAN
Nhap TYPE hoac NAME can dieu chinh: MCB 20A
Manual adjustment moi: 3
→ Da cap nhat. FinalCount = 8
```

Công thức: **FinalCount = AutoCount + ManualCount**

### Bước 4 — Gán tầng / khu vực

```
Lệnh: MTOFLOOR
1 = Gan theo LAYER (pattern)
2 = Gan theo HANDLE (vung vua chon bang MTOSEL)
3 = Gan TAT CA
Chon cach gan [1/2/3] <1>: 1
Pattern layer (vd EL-*): EL-LIGHT-T1
FLOOR (vd T1): T1
ZONE (Enter = bo qua): Zone-A
AREA (Enter = bo qua): P101
→ Da gan floor cho 42 dong.
```

### Bước 5 — Xem kết quả

```
Lệnh: MTOLIST
```
Hiện bảng:
```
CATEGORY       TYPE        NAME                QTY    LENGTH   UNIT
Electrical     MCB         MCB 20A             8                    cai
Electrical     Tray        EL-TRAY-J           1      126        m
ELV            CCTV        Camera Dome         12                   cai
```

### Bước 6 — Tính toán (tuỳ chọn)

**Hệ số hao hụt / quy đổi:**
```
Lệnh: MTOFORMULA
Chon STT dong can ap dung cong thuc: 2
Cong thuc: LEN * 1.05
→ Giai thich: LEN * 1.05 = 132.3
```

Biến dùng được: `SL`, `QTY`, `NETQTY`, `LEN` (chiều dài), `DED`, `PRICE`
Phép toán: `*` (hoặc `x`), `/` (hoặc `:`), `+`, `-`

**Khấu trừ (trừ đoạn không thi công):**
```
Lệnh: MTODED
Chon STT can khau tru: 2
So luong khau tru: 10
→ Da cap nhat: QTY=126 DED=10 NET=116
```

**Tổng hợp theo nhóm:**
```
Lệnh: MTOSUB
Gom nhom theo [CATEGORY/TYPE/LAYER/FLOOR] <CATEGORY>: FLOOR
→ SUBTOTAL theo FLOOR ...
```

### Bước 7 — Xuất kết quả

| Lệnh | Kết quả |
|---|---|
| `MTOCSV` | File CSV (mở bằng Excel) |
| `MTOTABLE` | **Bảng vẽ ngay trên bản vẽ** (có subtotal + tổng cộng) |

```
Lệnh: MTOCSV
Duong dan file CSV <BanVe1_MTO_20260918_153045.csv>: ↵
→ Da xuat 42 dong ra: BanVe1_MTO_20260918_153045.csv
```

---

## 5. Đối chiếu ngược về bản vẽ

Khi phát hiện số liệu lạ, cần xem đối tượng gốc:

```
Lệnh: MTOFIND
Nhap STT hoac tu khoa: 2            (hoặc gõ "MCB" / "camera")
→ [STT 2] EL-TRAY-J
  Co 1 doi tuong con song.
  Da zoom + chon doi tuong handle 1A3B.
```

Hoặc zoom thẳng theo handle (lấy từ cột Handle trong CSV):
```
Lệnh: MTOGOTO
Nhap handle: 1A3B
```

---

## 6. Sửa dữ liệu trên bản vẽ (có hoàn tác)

```
Lệnh: MTOSNAP        ← CHỤP ảnh dữ liệu TRƯỚC khi sửa
Lệnh: MTOUPDATE      ← sửa nội dung TEXT/MTEXT
Lệnh: MTOUNDO        ← khôi phục về trước khi sửa
```

`MTOUNDO` hỏi `[Y/N]` trước khi khôi phục. Ghi chú XData truy vết tự động.

> **Lưu ý:** `MTOUNDO` chỉ khôi phục **nội dung TEXT/MTEXT**, không khôi phục XData.

---

## 7. Kiểm tra dữ liệu "mồ côi" (orphan)

Khi bản vẽ bị sửa (xóa đối tượng), dòng dữ liệu cũ có thể trỏ tới đối tượng không còn:

```
Lệnh: MTOORPHAN
→ Tong handle : 87 | Con song: 85 | Mo coi: 2 | Dong bi anh huong: 1
Loai bo handle mo coi khoi DB? [Y/N] <N>: Y
```

> **An toàn:** lệnh **không** xóa đối tượng trong bản vẽ — chỉ dọn dữ liệu MTO.

---

## 8. Cấu hình theo từng bản vẽ

```
Lệnh: MTOCFG
```
Lưu/đọc cấu hình (đường dẫn bộ quy tắc, đơn vị, thư mục xuất…) cho **riêng bản vẽ đó**:
- File `<tên-bản-vẽ>.mtocfg` cạnh DWG
- Hoặc lưu **trong chính DWG** (NOD)

---

## 9. Những điểm CẦN SOI KỸ khi test

Đây là các điểm **chưa kiểm chứng được trong môi trường tự động** — đề nghị anh/chị test kỹ:

| # | Điểm cần test | Vì sao |
|---|---|---|
| 1 | **Tự nạp LISP khi mở AutoCAD** — gõ `MTOHELP` ngay sau khi mở, không APPLOAD gì | Môi trường test tự động không có giao diện nên không xác nhận được Startup Suite |
| 2 | **`MTOTABLE` chế độ bảng gốc AutoCAD** (đối tượng TABLE) | Môi trường test thiếu ActiveX → chỉ chạy được chế độ lưới chữ + đường kẻ |
| 3 | **Zoom nhìn thấy được** bằng `MTOFIND`/`MTOGOTO` | Lệnh chạy đúng nhưng môi trường test không có màn hình |
| 4 | **Độ chính xác trên bản vẽ THẬT của công ty** | Test tự động dùng đối tượng tạo giả |
| 5 | **Bộ quy tắc `rules.json`** có khớp quy ước layer/block thực tế | Bộ mẫu hiện có 8 khoá cấu hình, chưa gắn với quy ước công ty |
| 6 | **Tiếng Việt trong file CSV** khi mở bằng Excel | Chưa có BOM UTF-8, có thể lệch dấu |

---

## 10. Xử lý sự cố

### Lỗi: `Unknown command` / không thấy lệnh MTO*

**Nguyên nhân phổ biến nhất:** AutoCAD chặn nạp LISP vì lý do bảo mật.

**Cách khắc phục (theo thứ tự):**

1. **Kiểm tra Trusted Locations:**
   - AutoCAD → gõ `OPTIONS` → tab **Files** → **Trusted Locations**
   - Phải có dòng `%LOCALAPPDATA%\MTOPro\lisp`
   - Nếu thiếu → **Add** → chọn thư mục đó

2. **Nạp thủ công 1 lần:**
   - Gõ `APPLOAD` → **Browse** → chọn
     `%LOCALAPPDATA%\MTOPro\lisp\mto-loader.lsp` → **Load**
   - Để tự nạp mọi lần: trong hộp APPLOAD → mục **Startup Suite** → **Contents** → **Add**
     → chọn `mto-loader.lsp`

3. **Kiểm tra biến bảo mật** (chỉ khi được IT cho phép):
   - Gõ `SECURELOAD` → nếu bằng `1`, AutoCAD chặn LISP ngoài Trusted Locations.
   - Cách đúng là thêm Trusted Location (bước 1), **không** nên đặt `SECURELOAD=0`.

### Lỗi: `File load canceled`

AutoCAD đang chặn `load` vì thư mục **chưa** nằm trong Trusted Locations → làm bước 1 ở trên.

### Lệnh chạy nhưng báo "DB dang rong"

Chưa có dữ liệu. Phải chạy `MTOTEXT` / `MTOBLK` / `MTOGEO` **trước** để nạp dữ liệu.

### Muốn gỡ cài đặt

- Xóa thư mục `%LOCALAPPDATA%\MTOPro`
- Trong AutoCAD: `APPLOAD` → Startup Suite → **Remove** dòng `mto-loader.lsp`
- (Nếu có cài bản .NET) xóa `%APPDATA%\Autodesk\ApplicationPlugins\MTOPro*.bundle`

---

## 11. Danh sách lệnh đầy đủ (22 lệnh LISP + 4 lệnh .NET)

### Lệnh .NET (giao diện panel)

| Lệnh | Chức năng |
|---|---|
| `MTO` | **Mở panel bóc tách** (quét → tích chọn → xuất Excel) |
| `MTOZOOM` | Truy vết đối tượng theo Handle |
| `MTOBANG` | Tạo bảng tổng hợp trên bản vẽ mới |
| `MTOTHONGKE` | Quét + xuất Excel nhanh không cần panel |

### Lệnh LISP

| Nhóm | Lệnh | Chức năng |
|---|---|---|
| **Nạp dữ liệu** | `MTOSEL` | Chọn vùng (Window/Crossing/Polygon) + lọc layer |
| | `MTOTEXT` | Nhận dạng TEXT/MTEXT theo prefix |
| | `MTOBLK` | Chọn block mẫu → đếm + nhập số thủ công |
| | `MTOBLKMAN` | Điều chỉnh thủ công cho dòng có sẵn |
| | `MTOGEO` | Đo tổng chiều dài LINE/LWPOLYLINE/ARC/CIRCLE |
| **Kết quả** | `MTOLIST` | Hiện bảng kết quả |
| | `MTOCSV` | Xuất CSV |
| | `MTOTABLE` | Tạo bảng trên bản vẽ |
| | `MTOORPHAN` | Kiểm tra & dọn dữ liệu mồ côi |
| **Đối chiếu** | `MTOFIND` | Tìm theo STT/từ khoá → zoom + chọn |
| | `MTOGOTO` | Zoom theo handle |
| **Sửa dữ liệu** | `MTOUPDATE` | Cập nhật TEXT/MTEXT + ghi XData |
| | `MTOSNAP` | Chụp ảnh dữ liệu trước khi sửa |
| | `MTOUNDO` | Khôi phục từ ảnh chụp |
| | `MTOSNAPSHOW` | Xem ảnh chụp hiện tại |
| | `MTOXCHECK` | Kiểm tra XData MTO trên đối tượng |
| **Tính toán** | `MTOFORMULA` | Công thức tuỳ chỉnh |
| | `MTOSUB` | Subtotal / gom nhóm |
| | `MTODED` | Khấu trừ |
| **Tầng / cấu hình** | `MTOFLOOR` | Gán & tổng hợp theo tầng/khu vực |
| | `MTOCFG` | Cấu hình theo từng bản vẽ |
| **Trợ giúp** | `MTOHELP` | Danh sách lệnh |

---

## 12. Bộ quy tắc mẫu (`rules.json`)

File: `%LOCALAPPDATA%\MTOPro\config\rules.json`

Gồm **110 quy tắc** cho **11 hệ** (Điện 33 · Nước 23 · Mạng 14 · Data Center 10 ·
CCTV 6 · Kiểm soát ra vào 6 · Báo cháy 7 · Âm thanh 5 · BMS 3 · Intercom 1 · IPTV 1).

> ⚠️ Bộ quy tắc này **là mẫu** — Phòng Dự án cần rà soát và sửa cho khớp quy ước
> layer/block thực tế của công ty trước khi dùng chính thức.

---

## 13. Liên hệ hỗ trợ

| Nội dung | Thông tin |
|---|---|
| Mã đề tài | R&D-CAD-QTO-01 |
| Nhật ký lỗi | `%LOCALAPPDATA%\MTOPro\logs\` |
| Báo lỗi | Gửi kèm: tên lệnh, ảnh màn hình, file log |

Khi báo lỗi, vui lòng gửi kèm **nội dung dòng lệnh** đã gõ và **thông báo lỗi** hiện ra.
