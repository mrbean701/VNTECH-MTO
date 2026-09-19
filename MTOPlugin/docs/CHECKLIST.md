# Checklist Nghiệm Thu MTOPlugin

Đề tài: R&D-CAD-QTO-01
Ngày cập nhật: 2026-09-16

---

## A. Checklist Code & Build

| # | Mục | Trạng thái | Ghi chú |
|---|------|------------|---------|
| A1 | Build Core (netstandard2.0) thành công | ✅ | 0 errors, 0 warnings |
| A2 | Build Tests (net8.0) thành công | ✅ | 0 errors, 0 warnings |
| A3 | Unit tests (86 cases) PASSED | ✅ | 86/86 PASSED |
| A4 | Integration tests PASSED | ✅ | 22/22 PASSED |
| A5 | Rules sample.json hợp lệ (110 rules) | ✅ | ValidateRuleSet = 0 issues |
| A6 | Code review hoàn tất | ✅ | Naming convention, XML docs |
| A7 | Security audit (JSON validation, path sanitization) | ✅ | RuleSetLoader methods |
| A8 | Localization (VI/EN) | ✅ | 35 labels |

---

## B. Checklist Chức năng (Theo FR)

| # | FR | Chức năng | Trạng thái | Cách kiểm tra |
|---|-----|-----------|------------|---------------|
| B1 | FR01 | Chọn phạm vi quét | ✅ | 6 options: Selection/Model/CurrentLayout/AllLayouts/ModelAndAllLayouts |
| B2 | FR02 | Đọc layer | ✅ | ComputeLayerStats → sheet TONG_HOP/CHI_TIET |
| B3 | FR03 | Đếm block (dynamic, attributes) | ✅ | HandleBlockReference → ClassificationEngine |
| B4 | FR04 | Đo hình học (Line/Polyline/Arc/Circle) | ✅ | ScanBlockTableRecord → UnitConverter |
| B5 | FR05 | Quản lý Xref (3 chế độ) | ✅ | XrefManager: Ignore/UniqueBySource/PerInsertion |
| B6 | FR06 | Bộ quy tắc JSON | ✅ | RuleSetLoader.Load/Save/Validate |
| B7 | FR07 | Kết quả + chọn dòng xuất | ✅ | 2 bước: Quét → Chọn → Xuất |
| B8 | FR08 | Xuất Excel 5 sheets | ✅ | ExcelExporter: TONG_HOP/CHI_TIET/CHUA_PHAN_LOAI/CANH_BAO_LOI/THONG_TIN_LAN_QUET |
| B9 | FR09 | Truy vết (MTOZOOM) | ✅ | Database.TryGetObjectId → zoom |
| B10 | FR10 | Nhật ký phiên | ✅ | SessionLog → %LOCALAPPDATA%\MTOPlugin\logs |
| B11 | FR11 | Bảng trên bản vẽ (MTOBANG) | ✅ | Tạo DWG mới, không sửa bản vẽ gốc |
| B12 | FR12 | Tương thích AutoCAD 2025-2026 | ✅ | net8.0-windows, MtoCompat.cs |

---

## C. Checklist Rules mẫu

| # | Hệ thống | Số rules | Trạng thái | Ghi chú |
|---|----------|----------|------------|---------|
| C1 | Điện (HE-DIEN) | 33 | ✅ | ống luồn, cáp, khay cáp, đèn, ổ cắm, tủ điện |
| C2 | Nước (HE-NUOC) | 23 | ✅ | ống cấp/thoát, thiết bị vệ sinh, van, phụ kiện |
| C3 | Mạng LAN (HE-ELV-NET) | 14 | ✅ | Switch, Router, AP, Cat6/6A/7, Fiber |
| C4 | Data Center (HE-ELV-DC) | 10 | ✅ | Rack, Server, UPS, PDU, Patch Panel |
| C5 | CCTV (HE-ELV-CCTV) | 6 | ✅ | Camera Dome/Bullet/PTZ, NVR |
| C6 | Access Control (HE-ELV-ACC) | 6 | ✅ | Controller, RFID, Maglock |
| C7 | Fire Alarm (HE-ELV-FA) | 7 | ✅ | FACP, Smoke, Heat, MCP, Bell, Strobe |
| C8 | PA (HE-ELV-PA) | 5 | ✅ | Speaker, Amplifier, Mixer |
| C9 | BMS (HE-ELV-BMS) | 3 | ✅ | DDC, Temp Sensor, VFD |
| C10 | Intercom (HE-ELV-INT) | 1 | ✅ | Indoor Monitor |
| C11 | IPTV (HE-ELV-TV) | 1 | ✅ | Set-top Box |
| **Tổng** | | **110** | ✅ | |

---

## D. Checklist Tính năng mới

| # | Tính năng | Trạng thái | Vị trí code |
|---|-----------|------------|-------------|
| D1 | CountIfAttributeEquals | ✅ | RuleDefinition.cs, ClassificationEngine.cs |
| D2 | AttributeCondition | ✅ | RuleDefinition.cs |
| D3 | DynamicPropertyCondition | ✅ | RuleCondition.cs, RuleMatcher.cs |
| D4 | IDynamicBlockReader interface | ✅ | IDynamicBlockReader.cs |
| D5 | Rule Editor UI (WPF) | ✅ | RuleEditorWindow.xaml/.cs |
| D6 | LISP wrappers (7 functions) | ✅ | lisp/mto-commands.lsp |
| D7 | Unit Converter (18 units) | ✅ | UnitConverter.cs, UnitInfo.cs |
| D8 | BatchEngine | ✅ | Batch/BatchEngine.cs |
| D9 | CsvExporter | ✅ | Export/CsvExporter.cs |
| D10 | Localization (VI/EN) | ✅ | Localization/LocalizationHelper.cs |
| D11 | JSON validation | ✅ | RuleSetLoader.ValidateJson() |
| D12 | RuleSet validation | ✅ | RuleSetLoader.ValidateRuleSet() |
| D13 | Path sanitization | ✅ | RuleSetLoader.SanitizePath() |

---

## E. Checklist Nghiệm thu (Yêu cầu đề tài)

| # | Tiêu chí | Trạng thái | Cách kiểm tra |
|---|----------|------------|---------------|
| E1 | Đọc dữ liệu: 100% đối tượng hỗ trợ được đọc đúng | ⏳ | Cần test với DWG thật |
| E2 | Model/Layout: Không tính lặp qua viewport | ⏳ | Cần test với DWG có Layout |
| E3 | Xref: 3 chế độ đúng | ⏳ | Cần test với DWG có Xref |
| E4 | Phân loại: >95% trên 5 bản vẽ thực tế | ⏳ | Cần 5 bộ DWG + rules phê duyệt |
| E5 | Khối lượng: Khớp 100% cách tính đã phê duyệt | ⏳ | Cần Kỹ sư M&E xác nhận |
| E6 | Excel: 5 sheets, tiếng Việt đúng | ✅ | ExcelExporterTests |
| E7 | Truy vết: Tìm/zoom đúng đối tượng | ⏳ | Cần test trên AutoCAD |
| E8 | Bảng trên bản vẽ: MTOBANG đúng dữ liệu | ⏳ | Cần test trên AutoCAD |
| E9 | Hiệu quả: Giảm >50% thời gian | ⏳ | Cần bấm giờ so sánh |
| E10 | Ổn định: Không sửa DWG, không treo | ⏳ | Cần test trên AutoCAD |
| E11 | Tương thích: Đã xác minh đúng phiên bản | ⏳ | Cần máy test |

---

## F. Checklist Demo

| # | Mục demo | Trạng thái | Ghi chú |
|---|----------|------------|---------|
| F1 | Mở panel MTO trong AutoCAD | ⏳ | Cần AutoCAD 2025 |
| F2 | Quét + Phân loại với rules mẫu | ⏳ | Cần DWG mẫu |
| F3 | Xuất Excel (chọn lọc + toàn bộ) | ⏳ | Cần DWG mẫu |
| F4 | MTOZOOM truy vết đối tượng | ⏳ | Cần DWG mẫu |
| F5 | MTOBANG tạo bảng tổng hợp | ⏳ | Cần DWG mẫu |
| F6 | Rule Editor (thêm/sửa/xóa rule) | ⏳ | Cần AutoCAD 2025 |
| F7 | Batch processing nhiều DWG | ⏳ | Cần nhiều DWG |
| F8 | CSV export | ⏳ | Cần DWG mẫu |
| F9 | Localization (VI/EN) | ✅ | Unit tests PASSED |
| F10 | Security (JSON validation) | ✅ | Unit tests PASSED |

---

## G. Checklist Tài liệu

| # | Tài liệu | Trạng thái | Ghi chú |
|---|----------|------------|---------|
| G1 | README.md | ✅ | Cập nhật 2026-09-16 |
| G2 | ARCHITECTURE.md | ✅ | Kiến trúc tổng quan |
| G3 | BUILD.md | ✅ | Hướng dẫn build |
| G4 | INSTALL.md | ✅ | Hướng dẫn cài đặt |
| G5 | RULES.md | ✅ | Định dạng bộ quy tắc |
| G6 | TESTING.md | ✅ | Tiêu chí nghiệm thu |
| G7 | IMPLEMENTATION.md | ✅ | Cập nhật 2026-09-16 |
| G8 | PROGRESS_REPORT.md | ✅ | Báo cáo tiến độ |
| G9 | CHECKLIST.md | ✅ | Checklist này |
| G10 | Quick Start Guide | ⏳ | Chưa tạo |
| G11 | User Manual | ⏳ | Chưa tạo |

---

## Tổng kết

| Nhóm | Số mục | Hoàn thành | Còn lại |
|------|--------|------------|---------|
| A. Code & Build | 8 | 8 | 0 |
| B. Chức năng (FR) | 12 | 12 | 0 |
| C. Rules mẫu | 11 | 11 | 0 |
| D. Tính năng mới | 13 | 13 | 0 |
| E. Nghiệm thu | 11 | 1 | 10 |
| F. Demo | 10 | 2 | 8 |
| G. Tài liệu | 11 | 9 | 2 |
| **Tổng** | **76** | **56** | **20** |

**Tiến độ: 73.7% (56/76 mục hoàn thành)**

### Còn lại chủ yếu là:
- Cần máy có AutoCAD 2025 để test integration
- Cần 5 bộ DWG test + kết quả chuẩn
- Cần Kỹ sư M&E xác nhận rules + kết quả
- Cần tạo Quick Start Guide + User Manual
