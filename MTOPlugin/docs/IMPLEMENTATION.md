# Ánh xạ yêu cầu chức năng -> code

Cập nhật: 2026-09-16

## Yêu cầu chức năng (FR)

| ID | Chức năng | Trạng thái | Vị trí code |
|---|---|---|---|
| FR01 | Chọn phạm vi | ✅ Đã triển khai | `AutoCadScanner.ResolveRecordsToScan`; `MainPanel` (6 radio) |
| FR02 | Đọc layer | ✅ Đã triển khai | `AutoCadScanner.ComputeLayerStats`; sheet CHI_TIET/TONG_HOP |
| FR03 | Đếm block | ✅ Đã triển khai | `AutoCadScanner.HandleBlockReference` (dynamic, attributes, scale, rotation) |
| FR04 | Đo hình học | ✅ Đã triển khai | Line/Polyline/Arc/Circle trong `ScanBlockTableRecord`; `UnitConverter` |
| FR05 | Quản lý Xref | ✅ Đã triển khai | `Core/Xref/XrefManager.cs` + `CollectXrefInfo` (3 chế độ) |
| FR06 | Bộ quy tắc | ✅ Đã triển khai | `Rules/RuleMatcher.cs`, `Rules/RuleSetLoader.cs` (JSON) |
| FR07 | Kết quả + chọn dòng xuất | ✅ Đã triển khai | `MainPanel`: BƯỚC 1 Quét+Phân loại → BƯỚC 2 Xuất Excel |
| FR08 | Xuất Excel | ✅ Đã triển khai | `Export/ExcelExporter.cs` (5 sheets) |
| FR09 | Truy vết | ✅ Đã triển khai | Lệnh `MTOZOOM`; nhấp đúp dòng kết quả |
| FR10 | Nhật ký | ✅ Đã triển khai | `Logging/SessionLog.cs` |
| FR11 | Bảng khối lượng trên bản vẽ | ✅ Đã triển khai | Lệnh `MTOBANG` tạo DWG mới |
| FR12 | Tương thích nhóm AutoCAD | ✅ net8; ⏳ net48 | `MtoCompat.cs` |

## Tính năng mới (Phase 1-6)

### Phase 1: Nền tảng cốt lõi

| Tính năng | Trạng thái | Vị trí code |
|-----------|------------|-------------|
| CountIfAttributeEquals | ✅ | `RuleDefinition.cs`, `ClassificationEngine.cs` |
| AttributeCondition | ✅ | `RuleDefinition.cs` |
| DynamicPropertyCondition | ✅ | `RuleCondition.cs`, `RuleMatcher.cs` |
| DynamicBlockReader interface | ✅ | `IDynamicBlockReader.cs` |
| Rule Editor UI | ✅ | `RuleEditorWindow.xaml/.cs` |
| LISP wrappers | ✅ | `lisp/mto-commands.lsp` |
| Unit Converter (18 units) | ✅ | `UnitConverter.cs`, `UnitInfo.cs` |
| Unit tests (86 cases) | ✅ | `tests/MTOPlugin.Tests/` |

### Phase 2-4: Rules mẫu

| Hệ thống | Số rules | Trạng thái |
|----------|----------|------------|
| Điện (HE-DIEN) | 33 | ✅ |
| Nước (HE-NUOC) | 23 | ✅ |
| Mạng LAN (HE-ELV-NET) | 14 | ✅ |
| Data Center (HE-ELV-DC) | 10 | ✅ |
| CCTV (HE-ELV-CCTV) | 6 | ✅ |
| Access Control (HE-ELV-ACC) | 6 | ✅ |
| Fire Alarm (HE-ELV-FA) | 7 | ✅ |
| PA (HE-ELV-PA) | 5 | ✅ |
| BMS (HE-ELV-BMS) | 3 | ✅ |
| Intercom (HE-ELV-INT) | 1 | ✅ |
| IPTV (HE-ELV-TV) | 1 | ✅ |
| **Tổng** | **110** | ✅ |

### Phase 5: Batch Processing

| Tính năng | Trạng thái | Vị trí code |
|-----------|------------|-------------|
| BatchEngine | ✅ | `Batch/BatchEngine.cs` |
| CsvExporter (Summary + Details) | ✅ | `Export/CsvExporter.cs` |
| Merge classifications | ✅ | `BatchEngine.cs` |
| Per-file export | ✅ | `BatchEngine.cs` |

### Phase 6: Integration & Polish

| Tính năng | Trạng thái | Vị trí code |
|-----------|------------|-------------|
| JSON validation | ✅ | `RuleSetLoader.ValidateJson()` |
| RuleSet validation | ✅ | `RuleSetLoader.ValidateRuleSet()` |
| Path sanitization | ✅ | `RuleSetLoader.SanitizePath()` |
| Localization (VI/EN) | ✅ | `Localization/LocalizationHelper.cs` |
| Systems metadata | ✅ | `RuleSet.Systems` |

## Bảng tuân thủ kỹ thuật

- ✅ Chỉ đọc bản vẽ (mọi `OpenMode.ForRead`)
- ✅ Core tách AutoLISP/API
- ✅ Quy tắc đứng file ngoài code (JSON)
- ✅ Lỗi 1 đối tượng không dừng cả lượt quét
- ✅ Khác biệt API AutoCAD 2025+ vs 2018-2024 gom trong `MtoCompat.cs`
- ✅ Installer 3 nhóm bundle
- ⏳ Bundle nhóm net48 chưa build được (chỉ có AutoCAD 2025)
- ⏳ Ma trận phiên bản chưa xác minh trên máy thật

## Test coverage

| File | Tests | Status |
|------|-------|--------|
| `RuleMatcherTests.cs` | 13 | ✅ PASSED |
| `ClassificationEngineTests.cs` | 13 | ✅ PASSED |
| `ExcelExporterTests.cs` | 3 | ✅ PASSED |
| `RuleSetLoaderTests.cs` | 12 | ✅ PASSED |
| `UnitConverterTests.cs` | 23 | ✅ PASSED |
| `IntegrationTests.cs` | 22 | ✅ PASSED |
| **Tổng** | **86** | ✅ ALL PASSED |

## Gaps còn lại

| # | Mức độ | Mô tả | Ước tính |
|---|--------|-------|----------|
| 1 | 🔴 Cao | AutoCAD integration tests trên máy thật | 2 tuần |
| 2 | 🔴 Cao | 5 bộ DWG test + kết quả chuẩn | 1 tuần |
| 3 | 🔴 Cao | So sánh thời gian thủ công vs plugin | 3 ngày |
| 4 | 🟡 Trung bình | Naming Convention Checker | 2 ngày |
| 5 | 🟡 Trung bình | DataCenter module chuyên biệt | 3 ngày |
| 6 | 🟡 Trung bình | PDF Report với charts | 3 ngày |
| 7 | 🟢 Thấp | Comparison mode | 3 ngày |
| 8 | 🟢 Thấp | Dark mode UI | 1 ngày |
