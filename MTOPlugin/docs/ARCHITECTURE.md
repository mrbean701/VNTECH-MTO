# Kiến trúc plugin MTO

Cập nhật: 2026-09-16

## Tổng quan

```
┌────────────────────────────────────────────────────────────────────┐
│                        AutoCAD Host                                 │
│  MTOCommands (MTO / MTOZOOM / MTOBANG)                              │
│        │                                                            │
│        ▼                                                            │
│  PaletteWrapper ──> WPF MainPanel (MTOPlugin.UI)                    │
│        │         HostScanHandler / HostZoomHandler                   │
│        │                                                            │
│        │    ┌─────────────────────────────────┐                     │
│        │    │    RuleEditorWindow (WPF)        │                     │
│        │    │    CRUD rules, filter, validate  │                     │
│        │    └─────────────────────────────────┘                     │
│        │                                                            │
│        ▼                                                            │
│  ScannerHostBridge ──> AutoCadScanner (đọc DWG)                     │
│        │                 (Block, Layer, Geometry,                    │
│        │                  Xref, Model/Layout, DynamicBlock)          │
│        ▼                                                            │
└────────┬───────────────────────────────────────────────────────────┘
         │ ScanResult (models thuần C#)
         ▼
┌────────────────────────────────────────────────────────────────────┐
│                       MTOPlugin.Core                                │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐            │
│  │RuleMatcher    │  │ClassifyEngine │  │ExcelExporter  │            │
│  │(wildcard/regex│  │(Priority,     │  │(5 sheets)     │            │
│  │layer, block,  │  │conditions,    │  │               │            │
│  │dynamic prop)  │  │CountIfAttr)   │  │               │            │
│  └──────────────┘  └──────────────┘  └───────────────┘            │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐            │
│  │UnitConverter  │  │XrefManager   │  │SessionManager │            │
│  │(18 units)     │  │(3 modes)     │  │               │            │
│  └──────────────┘  └──────────────┘  └───────────────┘            │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐            │
│  │BatchEngine    │  │CsvExporter   │  │Localization   │            │
│  │(multi-DWG,    │  │(Summary +    │  │(VI/EN,        │            │
│  │merge)         │  │Details)      │  │35 labels)     │            │
│  └──────────────┘  └──────────────┘  └───────────────┘            │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Rules & Data                                │  │
│  │  rules.json (110 rules, 11 systems)                           │  │
│  │  RuleSetLoader (JSON validation, path sanitization)            │  │
│  │  ScanSession (in-memory)                                       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

## Nguyên tắc thiết kế

1. **Core không phụ thuộc AutoCAD**: toàn bộ luật, tính toán, xuất Excel/CSV
   nằm ở `MTOPlugin.Core` (netstandard2.0), test được bằng NUnit thuần.
2. **Host mỏng**: `src/MTOPlugin` chỉ chịu trách nhiệm đọc AutoCAD API,
   chuyển thành `ScanResult`, và cài các delegate cho UI.
3. **Chỉ đọc, không sửa bản vẽ**: mọi `GetObject` đều ở `OpenMode.ForRead`;
   không có app command nào đối tượng write vào database.
4. **Cấu hình/quy tắc tách khỏi code**: rule set là file JSON (`config/rules.sample.json`).
5. **Xử lý lỗi theo đối tượng**: mỗi entity bọc `try/catch`; lỗi 1 đối tượng
   ghi vào `ScanWarning` rồi tiếp tục, không dừng cả lượt quét.

## Module chi tiết

### MTOPlugin.Core (netstandard2.0)

| Namespace | Class | Chức năng |
|-----------|-------|-----------|
| `Rules` | `RuleSet` | Tập hợp rules, metadata (name, version, systems) |
| `Rules` | `RuleDefinition` | Định nghĩa 1 rule (code, conditions, calculation) |
| `Rules` | `RuleCondition` | Điều kiện khớp (layer, block, attributes, dynamic) |
| `Rules` | `RuleMatcher` | So khớp rule vs entity (wildcard, regex, attributes) |
| `Rules` | `RuleSetLoader` | Load/Save/Validate JSON rules |
| `Classification` | `ClassificationEngine` | Phân loại entities theo rules |
| `Classification` | `ClassificationResult` | Kết quả phân loại (Summary, Details, Unclassified) |
| `Export` | `ExcelExporter` | Xuất Excel 5 sheets |
| `Export` | `CsvExporter` | Xuất CSV (Summary + Details) |
| `Batch` | `BatchEngine` | Xử lý batch nhiều DWG |
| `Unit` | `UnitConverter` | Chuyển đổi đơn vị (18 units) |
| `Xref` | `XrefManager` | Quản lý Xref (3 chế độ) |
| `Session` | `ScanSession` | Lưu trữ kết quả quét |
| `Localization` | `LocalizationHelper` | Đa ngôn ngữ (VI/EN) |
| `Models` | `BlockReferenceInfo` | Thông tin block reference |
| `Models` | `GeometryInfo` | Thông tin geometry |
| `Models` | `ScanResult` | Kết quả quét |
| `Models` | `UnitInfo` | Thông tin đơn vị |

### MTOPlugin (Host - net48/net8.0-windows)

| Class | Chức năng |
|-------|-----------|
| `MTOCommands` | Lệnh MTO, MTOZOOM |
| `MtoBangCommand` | Lệnh MTOBANG |
| `AutoCadScanner` | Đọc DWG entities |
| `ScannerHostBridge` | Kết nối Host ↔ Core |
| `PaletteWrapper` | WPF PaletteSet |
| `MtoCompat` | Compatibility layer (net48/net8) |

### MTOPlugin.UI (net48/net8.0-windows)

| Class | Chức năng |
|-------|-----------|
| `MainPanel` | Panel chính (quét, phân loại, xuất) |
| `RuleEditorWindow` | Dialog chỉnh sửa rules |

## Luồng dữ liệu

```
1. User mở DWG → MTO command → WPF Panel hiện ra
2. User chọn: scope, Xref mode, rules file, đơn vị, output path
3. BƯỚC 1: Quét + Phân loại
   └→ AutoCadScanner.Scan() → ScanResult
   └→ ClassificationEngine.Classify(scanResult, ruleSet) → ClassificationResult
   └→ Hiển thị bảng kết quả trên panel
4. User đánh dấu (tick) các dòng muốn xuất
5. BƯỚC 2: Xuất
   └→ ExcelExporter.Export() / ExportTo()
   └→ File .xlsx được lưu
6. (Tùy chọn) MTOBANG → tạo bảng tổng hợp trên DWG mới
```

## Batch Processing

```
1. User chọn nhiều DWG files
2. BatchEngine.Process(scans, options)
   └→ ClassificationEngine.Classify() cho từng file
   └→ Merge classifications (nếu cần)
   └→ Export per-file hoặc merged
3. Kết quả: List<FileResult> + List<OutputFiles>
```

## Security

- **JSON validation**: `RuleSetLoader.ValidateJson()` kiểm tra syntax
- **RuleSet validation**: `RuleSetLoader.ValidateRuleSet()` kiểm tra required fields
- **Path sanitization**: `RuleSetLoader.SanitizePath()` chống path traversal
- **Input validation**: Kiểm tra null/empty ở mọi entry point

## Truy vết (FR09)

Mỗi dòng `CHI_TIET` có: sourceFile, Model/Layout, layer, loại, block, attribute,
Handle. Lệnh `MTOZOOM` dùng `Database.TryGetObjectId` từ Handle để chọn + zoom
đúng đối tượng.

## Nhật ký (FR10)

`SessionLog` ghi: thời gian, file, phạm vi, số đối tượng, lỗi, phiên bản
plugin, cấu hình dùng. Nằm tại `%LOCALAPPDATA%\MTOPlugin\logs\*.log`.

## Versioning & tương thích

Xem `docs/BUILD.md`. Một DLL không mặc nhiên tương thích toàn bộ AutoCAD
2018->2026; phải build theo nhóm và kiểm thử trên máy tương ứng.
