# Template khảo sát 05 bộ bản vẽ (Giai đoạn 1)

Dùng cho báo cáo SP01 (báo cáo khảo sát) trong đề tài R&D-CAD-QTO-01.
Điền đủ cho TỪNG bộ vẽ rồi tổng hợp vào cuối.

## Thông tin bộ vẽ

- [ ] Mã / Tên bộ vẽ: ______________
- [ ] Nhà thầu tư vấn: ______________ (hidden)
- [ ] Hệ M&E: Điện / Nước / HVAC / PCCC /_____
- [ ] Số file DWG: ____; dung lượng trung bình: ____
- [ ] Có các đặc điểm: Model/Layout, Xref (nested? n lần chèn?), dynamic block (block nào)

## Điền cho từng file trong bộ

| Nội dung | Giá trị |
|---|---|
| Số layer (không trùng) | |
| Số block definition | |
| Số block nội bộ + dynamic | |
| Số block thuộc Xref | |
| Kiểu geometry gặp (Line/Pline/Arc...) | |
| Đơn vị (DWGUNITS) | |
| Layouts (tên + viewport count) | |
| Xref: file nguồn / thiếu / unload / lặp | |
| Block/layer không quy chuẩn (VD trùng tên, tên rỗng, "|x") | |

## Ánh xạ gợi ý bộ quy tắc

| Layer/Block thực tế | Gợi ý vật tư/công việc | Đơn vị | Cách tính | Người xác nhận (M&E) |
|---|---|---|---|---|

## Rủi ro ghi nhận riêng

- [ ] Multiple block definitions dùng chung tên?
- [ ] Geometry nằm trong block nhưng phải tính riêng?
- [ ] Đơn vị gộp lẫn (1 file vẽ cả mm + m)?
- [ ] Xref vòng lặp? ______________________________________________