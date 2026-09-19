# Test và tiêu chí nghiệm thu

## Unit test (nhanh, không cần AutoCAD)

```powershell
.\scripts\build.ps1 -AcadVersion 2025
.\scripts\run-tests.ps1
```

Trên máy chưa cài AutoCAD (chỉ có .NET SDK) thì dùng lệnh trực tiếp:
`dotnet build MTOPlugin.sln; dotnet test`. Từ .NET 8 SDK, `dotnet test` tự build
projects net8.0; project test `tests/MTOPlugin.Tests` hiện nhắm `net8.0`
(adapter NUnit cũ không chạy được project net48 trên máy chỉ có .NET 8).

Nội dung hiện có trong `tests/MTOPlugin.Tests`:

| File | Kiểm tra |
|---|---|
| `RuleMatcherTests.cs` | Khớp layer/block/attribute/wildcard; phủ định attribute; phân biệt entity kind. |
| `ClassificationEngineTests.cs` | Phân loại đúng/sai; bỏ qua Draft; SumLength; hệ số; tỉ lệ phân loại. |
| `ExcelExporterTests.cs` | 5 sheet; Kieu xuat toan bo / da chon; So muc da xuat; từ chối file trống; từ chối lượt quét lỗi; từ chối xuất khi chưa chọn dòng nào. |

## Test tích hợp với AutoCAD (bộ ca nghiệm thu)

### Chuẩn bị máy test theo nhóm phiên bản
| Nhóm | AutoCAD | Target .NET | Trạng thái |
|---|---|---|---|
| A | 2018-2022 | net48 | Chưa xác minh trên máy thật |
| B | 2023-2024 | net48 | Chưa xác minh trên máy thật |
| C | 2025-2026 | net8.0-windows | Build + cài EXE xác minh; còn chờ load/đo kiểm trong AutoCAD |

Với mỗi nhóm cần một máy cài đúng AutoCAD; khi build phải chỉ đúng
`-AcadVersion` tương ứng (xem BUILD.md).

### Bộ DWG tối thiểu (5 bộ, Giai đoạn 1)
| Bộ | Đặc điểm | Mục tiêu |
|---|---|---|
| 1 | Model space thuần, không layout | Quét Model, đếm block + chiều dài |
| 2 | Nhiều Layout + viewport | Không tính lặp Model qua viewport |
| 3 | Có Xref chuẩn | 3 chế độ Xref -> khác biệt về kết quả |
| 4 | Xref thiếu/unload/lặp | Cảnh báo CANH_BAO_LOI |
| 5 | Bản vẽ thiếu chuẩn (layer/block lộn xộn) | Phân loại >=95%, phần còn lại vào CHUA_PHAN_LOAI |

### Kiểm thử luồng 2 bước (panel MTO)
- BƯỚC 1 (Quét + Phân loại) hiện bảng kết quả đúng số lượng và đơn vị.
- Đánh dấu một phần dòng -> BƯỚC 2 (Xuất các mục đã chọn) chỉ xuất đúng các
  dòng đó; TONG_HOP tính lại theo phần đã chọn; meta ghi "Kieu xuat" = "da chon".
- Không đánh dấu dòng nào rồi bấm BƯỚC 2 -> plugin từ chối với thông báo rõ.
- "Xuất Excel TOÀN BỘ" xuất toàn bộ kết quả lần quét hiện tại.
- Nhấp đúp 1 dòng kết quả -> zoom tới đúng đối tượng trên bản vẽ.

### Kiểm thử MTOBANG
- Sau 1 lượt quét, gõ MTOBANG -> tạo DWG mới (không sửa bản vẽ gốc) có bảng
  tổng hợp theo hệ thống/mã vật tư, khớp dữ liệu vừa quét.

### Kiểm thử Excel
- Đủ 5 sheet đúng tên.
- Không có file Excel trống không rõ nguyên nhân (chỉ xuất khi dữ liệu hợp lệ).
- Tiếng Việt hiển thị đúng (EPPlus UTF-8).

### Kiểm thử truy vết
- Từ 1 dòng trong `CHI_TIET` (Handle) chạy `MTOZOOM` -> đối tượng còn tồn tại
  phải được chọn/zoom đúng; đối tượng đã xóa -> thông báo không tìm thấy.

### Kiểm thử an toàn
- Chạy toàn bộ các ca trên file DWG gốc (có hash trước/sau) -> file không đổi.
- Không treo/không dừng AutoCAD trong suốt bộ ca.

## Tiêu chí nghiệm thu (từ đề tài)

| Nhóm | Tiêu chí đạt |
|---|---|
| Đọc dữ liệu | 100% đối tượng thuộc loại hỗ trợ được đọc đúng hoặc ghi vào DS lỗi; không bỏ sót. |
| Model/Layout | Không tính lặp đối tượng Model qua viewport; đối tượng vẽ trên Layout thống kê đúng. |
| Xref | 3 chế độ đúng; thiếu/unload/lặp/chèn lặp nhận biết hoặc cảnh báo. |
| Phân loại | >95% trên 5 bản vẽ thực tế sau khi cấu hình; còn lại vào CHUA_PHAN_LOAI. |
| Khối lượng | Khớp 100% với cách tính đã phê duyệt; sai lệch truy được tới đối tượng + quy tắc. |
| Excel | 5 sheet, không file trống không rõ nguyên nhân, tiếng Việt đúng, xuất đúng tập dòng đã chọn. |
| Truy vết | Tìm/zoom đúng đối tượng còn tồn tại. |
| Bảng trên bản vẽ | MTOBANG tạo bảng đúng dữ liệu lần quét, không sửa DWG gốc. |
| Hiệu quả | Same bộ vẽ giảm +50% thời gian so với thủ công (bấm giờ so sánh). |
| Ổn định | Không sửa file DWG; không treo AutoCAD toàn bộ bộ ca. |
| Tương thích | Chỉ ghi "Đã xác minh" với phiên bản đã cài/load/test đạt; còn lại ghi "Chưa xác minh". |

## Checklist trước demo cuối (Ngày 30)
- [ ] 5 bộ DWG + kết quả chuẩn (Kỹ sư M&E xác nhận bằng tay)
- [ ] Bộ quy tắc mẫu đã được phê duyệt
- [ ] So sánh thời gian thủ công vs plugin
- [ ] Trình báo cáo khả thi GĐ1 được phê duyệt
- [ ] Bản cài đặt + hướng dẫn cài/gỡ/dùng/xử lý lỗi