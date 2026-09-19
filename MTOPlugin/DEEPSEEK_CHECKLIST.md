# MTOPro - Checklist cho DeepSeek Harness

**Ngày:** 2026-09-16
**Trạng thái dự án:** Đã có base code MTOPlugin (v0.1.0), đang trong giai đoạn phát triển Phase 1
**Mục tiêu:** Xây dựng hệ thống bóc tách khối lượng M&E cho công ty xây lắp điện nước

---

## TỔNG QUAN

Repository: `MTOPlugin/`

**Cây thư mục chính:**
```
MTOPlugin/
├── src/
│   ├── MTOPlugin/              ← AutoCAD .NET plugin (C#, WPF)
│   │   ├── Scanner/
│   │   │   ├── AutoCadScanner.cs
│   │   │   ├── ScannerHostBridge.cs
│   │   │   └── DynamicBlockReader.cs    ← [MỚI] ĐÃ TẠO
│   │   ├── UI/
│   │   │   ├── MainPanel.xaml/.cs
│   │   │   └── RuleEditorWindow.xaml/.cs
│   │   ├── MTOCommands.cs
│   │   ├── MtoBangCommand.cs
│   │   ├── MtoCompat.cs
│   │   ├── ApplicationPlugin.cs
│   │   └── lisp/mto-commands.lsp
│   ├── MTOPlugin.Core/         ← Core engine (netstandard2.0)
│   │   ├── Classification/
│   │   ├── Export/
│   │   ├── Models/
│   │   ├── Rules/
│   │   ├── Session/
│   │   ├── Unit/
│   │   ├── Xref/
│   │   ├── Batch/
│   │   │   ├── BatchEngine.cs
│   │   │   ├── BatchOptions.cs
│   │   │   └── BatchResult.cs
│   │   └── IDynamicBlockReader.cs   ← [MỚI] ĐÃ TẠO
│   ├── MTOPlugin.UI/
│   └── MTOPlugin.Logging/
├── tests/
│   └── MTOPlugin.Tests/
├── config/
│   └── rules.sample.json       ← 97 rules, 11 hệ thống
├── scripts/
├── docs/
├── installer/
└── output/
```

---

## 1. ĐÃ LÀM GÌ (Trong phiên làm việc này)

### 1.1 Đã implement DynamicBlockReader ✅
- File: `src/MTOPlugin/Scanner/DynamicBlockReader.cs` (MỚI)
- Interface: `src/MTOPlugin.Core/IDynamicBlockReader.cs` (đã có sẵn)
- Methods:
  - `ReadDynamicPropertiesFromBlock(BlockReference, Transaction)` - đọc tất cả dynamic properties
  - `GetPropertyValue(prop)` - chuyển đổi giá trị theo type
  - `GetVisibilityStateName(BlockReference, Transaction)`
  - `GetPropertyByName(BlockReference, string, Transaction)`

### 1.2 Đã tích hợp DynamicBlockReader vào AutoCadScanner ✅
- Thêm field `private static readonly DynamicBlockReader _dynamicBlockReader`
- Trong `HandleBlockReference()`, populate `DynamicProperties` từ dynamic block
- File: `src/MTOPlugin/Scanner/AutoCadScanner.cs` (đã edit)

### 1.3 Đã tạo tài liệu SPEC.md ✅
- File: `MTOPlugin/SPEC.md` (~700 dòng)
- Bao gồm: kiến trúc, danh mục hệ thống M&E, quy ước đặt tên, rule engine, UI layout, kế hoạch 12 tuần

### 1.4 Đã tạo QUICKSTART.md ✅
- File: `MTOPlugin/QUICKSTART.md`
- Hướng dẫn nhanh cho DeepSeek bắt đầu

---

## 2. TRẠNG THÁI HIỆN TẠI

### 2.1 Build Status
⚠️ **CẢNH BÁO:** Build hiện tại **KHÔNG chạy được** trên máy này vì:
- Máy chỉ có AutoCAD 2025 → chỉ build được target `net8.0-windows`
- Tuy nhiên `dotnet build -p:MtoNet8=true` vẫn báo lỗi CS0246 (Transaction, BlockReference, Database... not found)
- Lỗi này là do **Assets file cache không khớp** - cần restore với đúng target trước khi build
- ĐÃ CHẠY THÀNH CÔNG trước đó: `dotnet build src\MTOPlugin\MTOPlugin.csproj -c Debug` (không có -p flag) → 0 errors

### 2.2 Cách build đúng
```powershell
# Build cho AutoCAD 2025 (net8.0-windows) - đã xác minh OK
dotnet build src\MTOPlugin\MTOPlugin.csproj -c Debug

# Build cho AutoCAD 2025 (net8.0-windows) - Release
dotnet build src\MTOPlugin\MTOPlugin.csproj -c Release

# Build toàn bộ solution
dotnet build MTOPlugin.sln -c Release

# Deploy bundle cho AutoCAD 2025
.\scripts\deploy-bundle.ps1 -AcadVersion 2025 -Config Release

# Build installer
.\scripts\build-installer.ps1
```

### 2.3 Các thành phần đã có & đang thiếu

| Thành phần | Trạng thái | Ghi chú |
|------------|-------------|----------|
| Rule Editor UI (WPF) | ✅ ĐÃ CÓ | `RuleEditorWindow.xaml/.cs` hoàn chỉnh |
| DynamicBlockReader | ✅ ĐÃ IMPLEMENT | `DynamicBlockReader.cs` + tích hợp AutoCadScanner |
| LISP wrappers | ⚠️ CẦN SỬA | `mto-commands.lsp` tồn tại, nhưng MTOEXPORT chỉ là stub |
| BatchEngine | ✅ ĐÃ CÓ | `BatchEngine.cs` đầy đủ, nhưng **chưa có UI** |
| CalculationKinds | ✅ ĐÃ CÓ | Cả 6 loại (Count, SumLength, SumLengthTimesFactor, SumLengthCeilingStep, SumAttributeValue, CountIfAttributeEquals) |
| rules.sample.json | ✅ ĐÃ CÓ | 97 rules, 11 hệ thống (HE-DIEN, HE-NUOC, HE-ELV-*) |
| Unit tests | ❌ CHƯA CÓ | Cần viết NUnit tests |
| Batch UI | ❌ CHƯA CÓ | Engine có sẵn, cần thêm WPF dialog |
| LISP MTOEXPORT | ❌ CHƯA IMPLEMENT | Chỉ là prompt "use panel" |

---

## 3. CHECKLIST CÔNG VIỆC CHO DEEPSEEK

### 3.1 CRITICAL - Phải làm trước

#### [ ] 3.1.1 Sửa build system
**Vấn đề:** Máy này chỉ có AutoCAD 2025, nhưng build với `-p:MtoNet8=true` không resolve đúng Acad DLLs.
**Giải pháp:** Kiểm tra lại project.assets.json và đảm bảo restore đúng target trước build.
**Lệnh test:**
```powershell
dotnet restore src\MTOPlugin\MTOPlugin.csproj
dotnet build src\MTOPlugin\MTOPlugin.csproj -c Debug
```
**File cần xem:** `src\MTOPlugin/MTOPlugin.csproj` (TargetFrameworks property)

#### [ ] 3.1.2 Fix LISP MTOEXPORT command
**Vấn đề:** `mto-commands.lsp` line 44-50 chỉ prompt user dùng panel, không export thực sự.
**Cần làm:** Implement thực sự MTOEXPORT bằng cách gọi .NET `ExcelExporter.Export()` từ AutoLISP.
**File:** `src/MTOPlugin/lisp/mto-commands.lsp`

#### [ ] 3.1.3 Verify DynamicBlockReader build và hoạt động
**Đã làm:** Tạo `DynamicBlockReader.cs` + tích hợp vào AutoCadScanner.
**Cần làm:** Đảm bảo build được, kiểm tra AutoCAD 2025 API (`GetDynamicBlockProperties()`) hoạt động.
**File:** `src/MTOPlugin/Scanner/DynamicBlockReader.cs`

---

### 3.2 HIGH PRIORITY - Làm tiếp

#### [ ] 3.2.1 Add Batch UI to MainPanel
**Đã có:** `BatchEngine.cs` hoàn chỉnh với methods:
- `ProcessFiles(string[] files, BatchOptions opts)` 
- `ProcessFilesMerged(string[] files, BatchOptions opts)`
- `GetProgress()` 
- `Cancel()`

**Cần thêm:**
- WPF dialog giống SPEC Section 7.3 (Batch Processing Dialog)
- Button "Batch" trên MainPanel để mở dialog
- Integration với BatchEngine

**File cần tạo:**
- `src/MTOPlugin.UI/BatchDialog.xaml`
- `src/MTOPlugin.UI/BatchDialog.xaml.cs`

**File cần sửa:**
- `src/MTOPlugin.UI/MainPanel.xaml` - thêm button
- `src/MTOPlugin.UI/MainPanel.xaml.cs` - thêm event handler

#### [ ] 3.2.2 Add Unit Tests
**Cần viết tests cho:**
1. `RuleMatcher` - wildcard matching, regex matching, attribute conditions
2. `ClassificationEngine` - all 6 CalculationKinds
3. `UnitConverter` - all unit conversions (mm/cm/m/ft/in)
4. `ExcelExporter` - export with selected items, empty data rejection

**Lệnh chạy test:**
```powershell
dotnet test MTOPlugin.sln
```

**File cần tạo:** `tests/MTOPlugin.Tests/` với các test class:
- `RuleMatcherTests.cs`
- `ClassificationEngineTests.cs`
- `UnitConverterTests.cs`
- `ExcelExporterTests.cs`

#### [ ] 3.2.3 Thêm wastage factor (%) cho rules
**Cần thêm field** `wastagePercent` (double) vào `RuleDefinition.cs`
**Logic:** `finalQuantity = calculatedQuantity * (1 + wastagePercent / 100)`
**Áp dụng cho:** tất cả calculation types

---

### 3.3 MEDIUM PRIORITY - Làm sau

#### [ ] 3.3.1 Thêm attribute extraction nâng cao
**Hiện tại:** Đọc attributes từ block (ReadAttributes).
**Cần thêm:**
- Extract tất cả dynamic block properties vào Dictionary<string, object>
- Đọc visibility state name
- Đọc custom properties (如果 block có)

#### [ ] 3.3.2 Thêm Rule Import/Export
**Cần thêm:**
- Import rules từ CSV/Excel template
- Export rules ra CSV/Excel
- Validation trước khi import

#### [ ] 3.3.3 Thêm Rule Versioning
**Cần thêm:**
- Hash SHA256 của rules file
- So sánh rules version giữa các lần quét
- Backup rules trước khi ghi đè

#### [ ] 3.3.4 Performance Optimization
**Cần làm:**
- Parallel processing cho scan nhiều file
- Caching cho layer visibility check
- Batch reading cho attribute extraction

---

## 4. CHỨC NĂNG CẦN THÊM THEO SPEC (Phase 1-6)

### Phase 1: Nền tảng cốt lõi (Tuần 1-2) - ĐANG LÀM
| Task | Trạng thái | File |
|------|------------|------|
| P1.1 Rule Engine upgrade (thêm CalculationKind) | ✅ ĐÃ XONG | Core/Rules/ |
| P1.2 Rule Editor UI | ✅ ĐÃ XONG | UI/RuleEditorWindow.xaml |
| P1.3 DynamicBlock property reader | ✅ ĐÃ XONG | Scanner/DynamicBlockReader.cs |
| P1.4 LISP wrapper | ⚠️ CẦN SỬA | lisp/mto-commands.lsp |
| P1.5 Scan scope UI | ✅ ĐÃ XONG | UI/MainPanel |
| P1.6 Unit converter | ✅ ĐÃ XONG | Core/Unit/ |
| P1.7 Unit tests | ❌ CHƯA LÀM | tests/ |
| P1.8 Code review | ❌ CHƯA LÀM | - |

### Phase 2: Hệ thống điện + nước (Tuần 3-4)
| Task | Trạng thái |
|------|------------|
| P2.1 Chuẩn hóa rules mẫu cho điện | ✅ ĐÃ CÓ (97 rules) |
| P2.2 Chuẩn hóa rules mẫu cho nước | ✅ ĐÃ CÓ |
| P2.3 Attribute extraction cho block điện | ⚠️ CƠ BẢN |
| P2.4 SumLengthTimesFactor cho cáp nhiều lõi | ✅ ĐÃ XONG |
| P2.5 Angle detection cho phụ kiện ống nước | ❌ CHƯA |

### Phase 3: ELV - Mạng & Data Center (Tuần 5-6)
| Task | Trạng thái |
|------|------------|
| P3.1 Rules cho mạng LAN | ✅ ĐÃ CÓ |
| P3.2 Rules cho Data Center | ✅ ĐÃ CÓ |
| P3.3 Patch Panel port counting | ❌ CHƯA |
| P3.4 ODF fiber counting | ❌ CHƯA |

### Phase 4: ELV hoàn chỉnh (Tuần 7-8)
| Task | Trạng thái |
|------|------------|
| P4.1 Rules cho CCTV | ✅ ĐÃ CÓ |
| P4.2 Rules cho Access Control | ✅ ĐÃ CÓ |
| P4.3 Rules cho Fire Alarm | ✅ ĐÃ CÓ |
| P4.4 Rules cho PA | ✅ ĐÃ CÓ |
| P4.5 Auto-naming convention checker | ❌ CHƯA |
| P4.6 Suggested Rules engine | ❌ CHƯA |

### Phase 5: Batch & Reporting (Tuần 9-10)
| Task | Trạng thái |
|------|------------|
| P5.1 Batch Processing UI | ❌ CHƯA |
| P5.2 Merged Excel output | ⚠️ Engine có sẵn |
| P5.3 CSV export | ❌ CHƯA |
| P5.4 PDF report | ❌ CHƯA |
| P5.5 Comparison mode | ❌ CHƯA |
| P5.6 Wastage factor | ❌ CHƯA |

### Phase 6: Integration & Polish (Tuần 11-12)
| Task | Trạng thái |
|------|------------|
| P6.1 Undo support | ❌ CHƯA |
| P6.2 Rule versioning | ❌ CHƯA |
| P6.3 Dark mode UI | ❌ CHƯA |
| P6.4 Localization | ❌ CHƯA |

---

## 5. CÁC FILE QUAN TRỌNG CẦN ĐỌC

| File | Mô tả |
|------|--------|
| `SPEC.md` | Đặc tả đầy đủ dự án |
| `QUICKSTART.md` | Hướng dẫn bắt đầu nhanh |
| `src/MTOPlugin/Scanner/DynamicBlockReader.cs` | **[MỚI]** Dynamic block reader implementation |
| `src/MTOPlugin/Scanner/AutoCadScanner.cs` | Scanner chính (đã tích hợp DynamicBlockReader) |
| `src/MTOPlugin/lisp/mto-commands.lsp` | LISP wrappers - **CẦN SỬA MTOEXPORT** |
| `src/MTOPlugin.UI/MainPanel.xaml/.cs` | WPF panel chính |
| `src/MTOPlugin.Core/Batch/BatchEngine.cs` | Batch engine - **Engine hoàn chỉnh, cần UI** |
| `config/rules.sample.json` | 97 rules mẫu |
| `src/MTOPlugin.Core/Rules/RuleDefinition.cs` | Rule schema + 6 CalculationKinds |
| `src/MTOPlugin.Core/Classification/ClassificationEngine.cs` | Classification engine |
| `src/MTOPlugin.Core/Export/ExcelExporter.cs` | Excel exporter |

---

## 6. BUILD & TEST COMMANDS

```powershell
# Build plugin (đã xác minh OK)
dotnet build src\MTOPlugin\MTOPlugin.csproj -c Debug

# Build toàn bộ solution
dotnet build MTOPlugin.sln -c Release

# Run tests
dotnet test MTOPlugin.sln

# Deploy bundle cho AutoCAD 2025
.\scripts\deploy-bundle.ps1 -AcadVersion 2025 -Config Release

# Build installer
.\scripts\build-installer.ps1

# Run Word doc generator
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\create-user-guide.ps1
```

---

## 7. LƯU Ý QUAN TRỌNG

### 7.1 Về Build
- Máy build hiện tại chỉ có AutoCAD 2025 → chỉ build được target `net8.0-windows`
- Build target `net48` sẽ fail vì thiếu AutoCAD 2018-2024 DLLs
- Khi chạy `dotnet build` không có `-p:` flag → auto-detect AcadDirectory → chọn đúng target

### 7.2 Về DynamicBlockReader
- **ĐÃ implement** `ReadDynamicPropertiesFromBlock(BlockReference, Transaction)`
- **ĐÃ tích hợp** vào `HandleBlockReference()` trong AutoCadScanner
- Sử dụng AutoCAD .NET API: `BlockReference.GetDynamicBlockProperties()`
- Returns `DynamicBlockReferenceProperty` collection
- Đã xử lý các type: Distance, Integer, Boolean, String, Enumerated, Point

### 7.3 Về Edit tool
- **Edit tool KHÔNG hoạt động đúng với tiếng Việt** - làm hỏng diacritics
- **Giải pháp:** Dùng Write tool cho file có tiếng Việt, hoặc dùng PowerShell .NET để add BOM:
  ```powershell
  $text = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p))
  [System.IO.File]::WriteAllText($p, $text, (New-Object System.Text.UTF8Encoding $true))
  ```

### 7.4 Về PowerShell script encoding
- Script .ps1 cần UTF-8 with BOM để chạy đúng với tiếng Việt
- Đã fix `create-user-guide.ps1` bằng cách thêm BOM

---

## 8. BẮT ĐẦU TỪ ĐÂU

**Thứ tự ưu tiên cho DeepSeek:**

1. **Đầu tiên:** Fix build system để đảm bảo `dotnet build` chạy được
2. **Tiếp theo:** Fix LISP MTOEXPORT (implement thực export từ LISP)
3. **Tiếp theo:** Add Batch UI (WPF dialog + integration)
4. **Tiếp theo:** Add Unit Tests
5. **Sau đó:** Tiếp tục Phase 2-6 theo kế hoạch trong SPEC.md

---

**Tài liệu tham khảo:**
- `SPEC.md` - Đặc tả chi tiết (~700 dòng)
- `QUICKSTART.md` - Hướng dẫn nhanh
- `docs/` - Tài liệu người dùng (README, BUILD, INSTALL, ARCHITECTURE, TESTING, IMPLEMENTATION)
