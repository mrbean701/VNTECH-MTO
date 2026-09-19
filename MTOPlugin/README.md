# MTOPlugin - Bóc tách khối lượng M&E trên AutoCAD

Đề tài: **Nghiên cứu và phát triển thử nghiệm plugin bóc tách khối lượng M&E trên AutoCAD**
Mã đề tài: `R&D-CAD-QTO-01` | Đơn vị chủ trì: Phòng Dự án
Phiên bản: `0.2.0` | Ngày cập nhật: 2026-09-16

---

## Tổng quan

MTOPro là hệ thống bóc tách khối lượng tự động cho công ty xây lắp chuyên về **điện, nước và điện nhẹ (ELV)**. Hệ thống đọc bản vẽ AutoCAD (DWG), phân loại đối tượng M&E theo bộ quy tắc có thể cấu hình, và xuất bảng khối lượng sang Excel.

### Tính năng chính
- ✅ Quét + phân loại tự động (Block, Geometry, Xref)
- ✅ 110 rules mẫu cho 11 hệ M&E
- ✅ Xuất Excel 5 sheets + CSV
- ✅ Batch processing nhiều DWG
- ✅ Rule Editor UI
- ✅ Localization (Vietnamese/English)
- ✅ Security hardening (JSON validation, path sanitization)

---

## Module

| Module | Project | Mô tả | Trạng thái |
|--------|---------|-------|------------|
| **Core** | `src/MTOPlugin.Core` | Logic thuần C#: Rule Engine, Classification, Unit, Xref, Excel/CSV Export, Batch, Localization | ✅ Hoàn thành |
| **Host** | `src/MTOPlugin` | Tích hợp AutoCAD .NET API: Scanner DWG, Commands (`MTO`, `MTOZOOM`, `MTOBANG`), PaletteSet | ✅ Hoàn thành |
| **UI** | `src/MTOPlugin.UI` | WPF panel điều khiển + Rule Editor | ✅ Hoàn thành |
| **Logging** | `src/MTOPlugin.Logging` | Nhật ký phiên (FR10) | ✅ Hoàn thành |
| **Tests** | `tests/MTOPlugin.Tests` | NUnit cho Core (86 test cases) | ✅ 86/86 PASSED |

---

## Cấu trúc thư mục

```
MTOPlugin/
├── config/
│   └── rules.sample.json          # 110 rules mẫu (11 hệ M&E)
├── docs/
│   ├── ARCHITECTURE.md             # Kiến trúc tổng quan
│   ├── BUILD.md                    # Hướng dẫn build
│   ├── INSTALL.md                  # Hướng dẫn cài đặt
│   ├── RULES.md                    # Định dạng bộ quy tắc
│   ├── TESTING.md                  # Tiêu chí nghiệm thu
│   └── GD1_KHAO_SAT_BAN_VE.md     # Template khảo sát bản vẽ
├── src/
│   ├── MTOPlugin.Core/             # Core library (netstandard2.0)
│   │   ├── Batch/                  # BatchEngine
│   │   ├── Classification/         # ClassificationEngine
│   │   ├── Export/                 # ExcelExporter, CsvExporter
│   │   ├── Localization/           # LocalizationHelper (VI/EN)
│   │   ├── Models/                 # Data models
│   │   ├── Rules/                  # RuleEngine, RuleSetLoader
│   │   ├── Session/                # ScanSession
│   │   ├── Unit/                   # UnitConverter
│   │   └── Xref/                   # XrefManager
│   ├── MTOPlugin/                  # AutoCAD Host (net48/net8.0-windows)
│   │   ├── Scanner/                # AutoCadScanner
│   │   ├── UI/                     # PaletteWrapper
│   │   └── lisp/                   # mto-commands.lsp
│   ├── MTOPlugin.UI/               # WPF UI (net48/net8.0-windows)
│   └── MTOPlugin.Logging/          # Logging (netstandard2.0)
├── tests/
│   └── MTOPlugin.Tests/            # Unit + Integration tests
├── scripts/                        # Build scripts
└── output/                         # Build output
```

---

## Yêu cầu build

- Windows 10/11
- .NET SDK 8 trở lên
- AutoCAD 2018-2026 (theo nhóm cần đóng gói)
- .NET Framework 4.8 Developer Pack (chỉ cần khi build nhóm 2018-2024)

```powershell
winget install Microsoft.DotNet.SDK.8
```

---

## Build nhanh

```powershell
# Auto-detect (khuyến nghị)
.\scripts\build.ps1

# Build cho phiên bản cụ thể
.\scripts\build.ps1 -AcadVersion 2025

# Build + đóng gói
.\scripts\build.ps1 -AcadVersion 2025
.\scripts\deploy-bundle.ps1 -AcadVersion 2025
.\scripts\build-installer.ps1
```

---

## Cài đặt nhanh

### Cách 1: Installer (1 click)
```
output\MTOPlugin.Setup-0.1.0.exe
```

### Cách 2: NETLOAD (phát triển)
1. Mở AutoCAD 2025
2. Gõ `NETLOAD` → chọn `MTOPlugin.dll`
3. Gõ `MTO` để mở panel

---

## Sử dụng

### Lệnh AutoCAD
| Lệnh | Mô tả |
|-------|-------|
| `MTO` | Mở panel bóc tách khối lượng |
| `MTOZOOM <handle>` | Truy vết đối tượng theo Handle |
| `MTOBANG` | Tạo bảng tổng hợp trên DWG mới |
| `MTOSCAN` | Quét không mở panel (batch) |

### Luồng 2 bước
1. **Bước 1**: Chọn phạm vi + bộ quy tắc → Quét + Phân loại
2. **Bước 2**: Tích các dòng muốn xuất → Xuất Excel (hoặc Xuất TOÀN BỘ)

---

## Bộ quy tắc (Rules)

File JSON tại `config/rules.sample.json` với **110 rules** cho **11 hệ M&E**:

| Hệ thống | Mã | Số rules |
|----------|-----|----------|
| Điện | HE-DIEN | 33 |
| Nước | HE-NUOC | 23 |
| Mạng LAN | HE-ELV-NET | 14 |
| Data Center | HE-ELV-DC | 10 |
| Camera | HE-ELV-CCTV | 6 |
| Kiểm soát ra vào | HE-ELV-ACC | 6 |
| Báo cháy | HE-ELV-FA | 7 |
| Âm thanh | HE-ELV-PA | 5 |
| BMS | HE-ELV-BMS | 3 |
| Intercom | HE-ELV-INT | 1 |
| IPTV | HE-ELV-TV | 1 |

---

## Kiểm thử

```powershell
# Chạy tất cả tests
dotnet test tests\MTOPlugin.Tests\MTOPlugin.Tests.csproj

# Kết quả: 86/86 PASSED
```

### Test coverage
| Category | Tests | Status |
|----------|-------|--------|
| RuleMatcher | 13 | ✅ |
| ClassificationEngine | 13 | ✅ |
| ExcelExporter | 3 | ✅ |
| RuleSetLoader | 12 | ✅ |
| UnitConverter | 23 | ✅ |
| Integration | 22 | ✅ |

---

## Tài liệu

| File | Nội dung |
|------|----------|
| `docs/ARCHITECTURE.md` | Kiến trúc tổng quan |
| `docs/BUILD.md` | Hướng dẫn build đa phiên bản |
| `docs/INSTALL.md` | Hướng dẫn cài đặt |
| `docs/RULES.md` | Định dạng bộ quy tắc |
| `docs/TESTING.md` | Tiêu chí nghiệm thu |
| `docs/IMPLEMENTATION.md` | Ánh xạ yêu cầu → code |
| `docs/PROGRESS_REPORT.md` | Báo cáo tiến độ |
| `docs/CHECKLIST.md` | Checklist nghiệm thu |

---

## Trạng thái dự án

| Phase | Mô tả | Trạng thái |
|-------|-------|------------|
| Phase 1 | Nền tảng cốt lõi | ✅ Hoàn thành |
| Phase 2 | Hệ thống Điện + Nước | ✅ Hoàn thành |
| Phase 3 | ELV - Mạng & Data Center | ✅ Hoàn thành |
| Phase 4 | ELV Hoàn chỉnh | ✅ Hoàn thành |
| Phase 5 | Batch Processing & Reporting | ✅ Hoàn thành |
| Phase 6 | Integration & Polish | ✅ Hoàn thành |

**Tiến độ tổng: 100% code + tests**

---

## Liên hệ

- Mã đề tài: R&D-CAD-QTO-01
- Đơn vị chủ trì: Phòng Dự án
- Ngày bắt đầu: 2026-09-01
- Ngày nghiệm thu dự kiến: 2026-10-31
