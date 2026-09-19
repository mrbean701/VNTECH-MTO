# HƯỚNG DẪN NGƯỜI MỚI — Bắt đầu với MTOPro trong 30 phút

**Dành cho:** kỹ sư M&E **chưa từng dùng** MTOPro
**Kết quả sau khi đọc:** tự bóc tách được 1 bản vẽ và xuất Excel

---

## ⏱️ Lộ trình 30 phút

| Phút | Việc | Mục |
|---|---|---|
| 0–5 | Cài đặt | [1](#1-cài-đặt-5-phút) |
| 5–10 | Mở AutoCAD, kiểm tra chạy được | [2](#2-kiểm-tra-cài-đặt-5-phút) |
| 10–25 | **Bóc tách bản vẽ đầu tiên** | [3](#3-bóc-tách-bản-vẽ-đầu-tiên-15-phút) |
| 25–30 | Xuất Excel + lưu cấu hình | [4](#4-xuất-kết-quả-5-phút) |

---

## 1. Cài đặt (5 phút)

### Bước 1 — Đóng AutoCAD
Nếu đang mở, đóng hoàn toàn (kiểm tra Task Manager không còn `acad.exe`).

### Bước 2 — Chạy bộ cài
Nhận **1 file duy nhất**: `MTOPro.Setup-1.0.0.exe` (~1.1 MB)

→ Double-click → làm theo hướng dẫn.

> ✅ **Không cần quyền Admin** · không cần cài thêm gì · không cần mạng.

### Bước 3 — Mở lại AutoCAD

**Kiểm tra:** ngay khi mở, dòng đầu tiên phải hiện:
```
MTOPro v1.0.0 : da nap 18/18 module.
Da bat hien thi ten lenh tren thanh trang thai (go MTOTITLE de tat).
```

❌ **Nếu KHÔNG thấy dòng này** → xem [mục 6 — Lỗi thường gặp](#6-lỗi-thường-gặp).

---

## 2. Kiểm tra cài đặt (5 phút)

Gõ lần lượt trong AutoCAD:

| Lệnh | Phải thấy |
|---|---|
| `MTOHELP` | Bảng 27 lệnh, chia theo nhóm |
| `MTOVERSION` | Phiên bản + nguồn cập nhật + trạng thái backup |

**Ví dụ `MTOVERSION`:**
```
==============================================================
  MTOVERSION  --  Xem phien ban / cap nhat gan nhat
==============================================================
Phien ban dang chay : 1.0.0
Nguon cap nhat      : https://raw.githubusercontent.com/...
Kenh (channel)      : stable
So ban backup       : 0 (giu toi da 3)
```

✅ Nếu cả 2 lệnh chạy → cài đặt thành công.

---

## 3. Bóc tách bản vẽ đầu tiên (15 phút)

### Bước 1 — Mở bản vẽ
Mở file DWG cần bóc tách (VD bản vẽ camera/điện).

### Bước 2 — Chọn đối tượng

```
Gõ:  MTOSEL
```

Hệ thống hỏi chế độ chọn:

| Chọn | Khi nào dùng |
|---|---|
| `All` | Quét **toàn bộ** bản vẽ (thường dùng nhất) |
| `Window` | Chỉ quét trong 1 vùng (kéo chuột) |
| `Layer` | Chỉ quét 1 vài layer |
| `View` | Chỉ quét vùng đang xem |
| `Xref` | Quét cả bản vẽ tham chiếu |

👉 **Người mới: gõ `All` rồi Enter.**

Hệ thống hiện số đối tượng đã chọn, ví dụ: `Da chon 1247 doi tuong.`

### Bước 3 — Nhận dạng

```
Gõ:  MTOTEXT      ← nhận dạng theo tiền tố văn bản (cáp, ống...)
Gõ:  MTOBLK       ← đếm block (thiết bị)
```

Mỗi lệnh chạy xong sẽ báo đã nhận dạng bao nhiêu đối tượng.

### Bước 4 — Xem kết quả

```
Gõ:  MTOLIST
```

Hiện bảng 6 cột: `STT · Mã · Mô tả · SL · ĐVT · Layer`

### Bước 5 — Kiểm tra chất lượng ⭐ QUAN TRỌNG

```
Gõ:  MTOORPHAN
```

**Đây là bước người mới hay bỏ qua nhất — nhưng quan trọng nhất.**

`MTOORPHAN` liệt kê các đối tượng **không khớp quy tắc nào** — tức là
những thứ bạn **đã bỏ sót**, chưa được tính vào khối lượng.

| Kết quả | Nghĩa là |
|---|---|
| `Khong co doi tuong mo coi` | ✅ Bộ quy tắc phủ hết — an tâm |
| Có danh sách | ⚠️ Cần bổ sung quy tắc, hoặc đó là đối tượng không cần tính |

> 💡 **Mẹo:** chạy `MTOORPHAN` **trước khi** xuất báo cáo. Nếu còn nhiều mồ côi,
> bảng khối lượng của bạn đang **thiếu** vật tư.

### Bước 6 — Truy vết khi nghi ngờ

Nghi con số `51 Bộ Camera` là sai?

```
Gõ:  MTOFIND
→ chọn mã "ELV-CAM-DOME"
→ AutoCAD ZOOM tới từng đối tượng đã đếm
```

Đây là tính năng **quan trọng nhất để tin được con số** — bạn kiểm tra được
từng đối tượng đã đưa vào bảng.

---

## 4. Xuất kết quả (5 phút)

### 4.1 Ra Excel (khuyên dùng)

```
Gõ:  MTOCSV
→ chọn nơi lưu (VD: D:\KhoiLuong\DuAn-A.csv)
```

File CSV mở được bằng Excel, **15 cột**: mã, hệ thống, mô tả, quy cách,
số lượng, chiều dài, đơn vị, layer, tầng, ghi chú...

### 4.2 Bảng ngay trong bản vẽ

```
Gõ:  MTOTABLE
→ chọn điểm đặt bảng
```

Tạo bảng 9 cột **ngay trong DWG** (để in cùng bản vẽ).

### 4.3 Lưu cấu hình cho lần sau

```
Gõ:  MTOCFG
```

Lưu cài đặt (đơn vị, hệ số, quy tắc dùng) **theo bản vẽ** — lần sau mở
lên là dùng được ngay, không phải thiết lập lại.

---

## 5. Mười phút tiếp theo — làm quen thêm

Sau khi đã bóc tách được 1 bản vẽ, thử các lệnh sau:

| Lệnh | Để làm gì |
|---|---|
| `MTOTABLE` | In bảng khối lượng kèm bản vẽ |
| `MTOFLOOR` | Tách khối lượng **theo tầng** |
| `MTOSUB` | Tạo **tổng phụ** theo nhóm (VD tổng cáp theo hệ) |
| `MTODED` | **Khấu trừ** (VD trừ đoạn cáp không dùng) |
| `MTOFORMULA` | Công thức riêng: `LEN * 1.05` (cộng 5% hao hụt) |
| `MTOUPDATE` | Sửa hàng loạt TEXT/MTEXT trong bản vẽ |
| `MTOUNDO` | Khôi phục sau khi sửa hàng loạt |
| `MTOXCHECK` | Kiểm tra chéo số liệu |

---

## 6. Lỗi thường gặp

| Hiện tượng | Nguyên nhân | Cách sửa |
|---|---|---|
| **Lệnh MTO* không chạy** (`Unknown command`) | AutoCAD chặn nạp LISP (`SECURELOAD`) | Xem hướng dẫn ngay dưới |
| Không thấy dòng `da nap 18/18 module` | Chưa nạp LISP | Như trên |
| Số lượng = 0 dù đã chọn | Chưa chạy `MTOTEXT`/`MTOBLK` | Chạy bước nhận dạng trước |
| Đơn vị sai (cáp dài gấp 25 lần) | Bản vẽ khai `INSUNITS` inch nhưng vẽ bằng mm | Hệ thống **tự cảnh báo**; kiểm tra `MTOGEO` |
| Bảng vẽ ra nhưng ô trống | Lỗi hiển thị bảng NATIVE | Hệ thống tự chuyển sang GRID; báo kỹ thuật |
| Bảng thiếu vật tư | Còn đối tượng mồ côi | Chạy `MTOORPHAN`, bổ sung quy tắc |

### 🔧 Sửa lỗi "lệnh MTO* không chạy"

**Nguyên nhân:** AutoCAD mặc định `SECURELOAD=1` → chặn nạp LISP ngoài
"Trusted Locations".

**Cách sửa (chọn 1):**

**Cách A — thêm Trusted Location (nên làm):**
```
Gõ OPTIONS → tab Files → Trusted Locations → Add
→ chọn thư mục:  %LOCALAPPDATA%\MTOPro\lisp
→ OK → mở lại AutoCAD
```

**Cách B — nạp thủ công:**
```
Gõ APPLOAD → Browse
→ chọn  %LOCALAPPDATA%\MTOPro\lisp\mto-loader.lsp  → Load

Để tự nạp mọi lần: APPLOAD → Startup Suite → Contents → Add → chọn file trên
```

> ⛔ **ĐỪNG** đặt `SECURELOAD=0` — giảm bảo mật máy.

---

## 7. Câu hỏi thường gặp

**Hỏi: MTOPro có sửa bản vẽ của tôi không?**
Không. Chỉ đọc để bóc tách. Riêng `MTOUPDATE` (sửa hàng loạt) là lệnh bạn
**chủ động gọi**, và có `MTOUNDO` để khôi phục.

**Hỏi: Bộ quy tắc lấy từ đâu?**
Từ `DANH_MUC_VAT_TU.xlsx` — kỹ sư điền vật tư, chạy script chuyển thành
`rules.json`. Xem `docs/HUONG_DAN_NHAP_DANH_MUC_VAT_TU.md`.

**Hỏi: Tôi sửa quy tắc thì có mất khi cập nhật phần mềm không?**
Không. Thư mục `config\` (chứa quy tắc, cấu hình) **không bao giờ** bị
cập nhật ghi đè.

**Hỏi: Làm sao biết có bản mới?**
```
Gõ:  MTOUPGRADECHECK     ← kiểm tra (không tải)
Gõ:  MTOUPGRADE          ← Enter để cập nhật
```

**Hỏi: Bao nhiêu người dùng cùng lúc được?**
Không giới hạn — mỗi máy cài độc lập, không cần server.

**Hỏi: Bóc 1 bản vẽ 1000 đối tượng mất bao lâu?**
Vài giây đến vài chục giây, tuỳ số đối tượng và độ phức tạp.

---

## 8. Đọc thêm

| Muốn | Đọc |
|---|---|
| Dùng chi tiết từng lệnh | `docs/HUONG_DAN_SU_DUNG.md` |
| Đo cáp & in bảng chuyên sâu | `docs/HUONG_DAN_DO_CAP_VA_IN_BANG.md` |
| Nhập danh mục vật tư | `docs/HUONG_DAN_NHAP_DANH_MUC_VAT_TU.md` |
| Dùng Rule Editor (giao diện) | `docs/GIAI_THICH_RULE_EDITOR.md` |
| Hiểu hệ thống bên trong | `docs/MO_TA_HE_THONG.md` |
| Cài đặt / cập nhật / sự cố | `docs/update/INSTALLATION.md` · `UPDATE_TROUBLESHOOTING.md` |

---

## 9. Quy trình chuẩn (in ra dán tường)

```
1. MTOSEL      → chọn đối tượng (All)
2. MTOTEXT     → nhận dạng text
3. MTOBLK      → đếm block
4. MTOLIST     → xem kết quả
5. MTOORPHAN   → ⚠️ KIỂM TRA BỎ SÓT
6. MTOFIND     → truy vết nếu nghi ngờ
7. MTOCSV      → xuất Excel
8. MTOTABLE    → in bảng kèm bản vẽ
9. MTOCFG      → lưu cấu hình
```

> **Nhớ nhất 2 điều:**
> ① **Luôn chạy `MTOORPHAN`** trước khi xuất báo cáo.
> ② **Nghi ngờ con số thì `MTOFIND`** — đừng đoán.

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — VNTECH.*
