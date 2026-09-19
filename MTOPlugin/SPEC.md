# MTOPro - Hệ Thống Bóc Tách Khối Lượng M&E Cho Công Ty Xây Lắp

**Phiên bản:** 1.0-draft  
**Ngày:** 2026-09-16  
**Loại tài liệu:** Project Specification & Technical Blueprint  
**Mục đích:** Tài liệu chi tiết để tiếp tục phát triển dự án trên DeepSeek

---

## MỤC LỤC

1. [Tổng Quan Dự Án](#1-tổng-quan-dự-án)
2. [Kiến Trúc Hệ Thống](#2-kiến-trúc-hệ-thống)
3. [Danh Mục Hệ Thống M&E](#3-danh-mục-hệ-thống-me)
4. [Quy Ước Đặt Tên Layer & Block](#4-quy-ước-đặt-tên-layer--block)
5. [Rule Engine - Thiết Kế Chi Tiết](#5-rule-engine---thiết-kế-chi-tiết)
6. [Kết Quả Xuất Excel](#6-kết-quả-xuất-excel)
7. [Giao Diện Người Dùng](#7-giao-diện-người-dùng)
8. [Lệnh AutoCAD / LISP](#8-lệnh-autocad--lisp)
9. [Cấu Trúc Dữ Liệu & Models](#9-cấu-trúc-dữ-liệu--models)
10. [Kế Hoạch Triển Khai Theo Giai Đoạn](#10-kế-hoạch-triển-khai-theo-giai-đoạn)
11. [Tiêu Chuẩn Kỹ Thuật](#11-tiêu-chuẩn-kỹ-thuật)
12. [Công Nghệ & Tools](#12-công-nghệ--tools)
13. [Testing & Quality Assurance](#13-testing--quality-assurance)
14. [Biểu Mẫu & Template](#14-biểu-mẫu--template)
15. [Rủi Ro & Mitigation](#15-rủi-ro--mitigation)

---

## 1. Tổng Quan Dự Án

### 1.1 Tên Dự Án & Mã Số

| Trường | Giá trị |
|---------|---------|
| Tên dự án | **MTOPro** |
| Mã đề tài | R&D-CAD-QTO-01 |
| Phiên bản hiện tại | 0.1.0 (developer preview) |
| Phiên bản đích | 1.0.0 (production) |
| Repository | `MTOPlugin/` (đã có base code) |

### 1.2 Tầm Nhìn (Vision)

> **MTOPro** là hệ thống bóc tách khối lượng tự động cho công ty xây lắp chuyên về **điện, nước và điện nhẹ (ELV)**. Hệ thống đọc bản vẽ AutoCAD (DWG), phân loại đối tượng M&E theo bộ quy tắc có thể cấu hình, và xuất bảng khối lượng sang Excel với độ chính xác >95%, giảm 50%+ thời gian so với đếm thủ công.

### 1.3 Đối Tượng Sử Dụng

| STT | Vai trò | Nhu cầu chính |
|-----|---------|----------------|
| 1 | Kỹ sư M&E | Đếm thiết bị, đo chiều dài ống/cáp/nhựa |
| 2 | Cán bộ định lượng (QS) | Tổng hợp khối lượng vào BOQ |
| 3 | Kỹ sư dự toán | Kiểm tra khối lượng vs bản vẽ |
| 4 | Quản lý công trình | Đối chiếu khối lượng thực tế |
| 5 | Bộ phận thầu | Chuẩn bị hồ sơ thầu |

### 1.4 Phạm Vi Dự Án

#### ✅ Trong phạm vi (In Scope)
- Quét và phân loại đối tượng: block, line, polyline, arc, circle
- Rule engine JSON có thể cấu hình
- Xuất Excel 5 sheet (Tổng hợp, Chi tiết, Chưa phân loại, Cảnh báo, Thông tin lần quét)
- Luồng 2 bước: Quét → Chọn dòng → Xuất
- Lệnh MTOBANG tạo bảng tổng hợp trên DWG mới
- Hỗ trợ Xref 3 chế độ
- Hỗ trợ AutoCAD 2018–2026 (.NET Framework 4.8 và .NET 8)
- Unit conversion (mm, cm, m, ft, in)
- Session logging
- Multi-file batch processing
- Giao diện sửa rule trực tiếp trong panel

#### ❌ Ngoài phạm vi (Out of Scope) - Giai đoạn 1
- BIM (Revit) integration
- Cloud/saas platform
- Mobile app
- Tính toán kết cấu, ACAD LT plugin
- ERP/Database integration
- PDF export

### 1.5 Mối Quan Hệ Với Code Hiện Có

Dự án này **mở rộng từ MTOPlugin hiện tại**. Các thành phần giữ lại:

| Thành phần | Mô tả |
|------------|-------|
| `MTOPlugin.Core` | Engine phân loại, rule, export Excel (giữ nguyên) |
| `MTOPlugin` host | AutoCAD integration (giữ, bổ sung thêm LISP commands) |
| `MTOPlugin.UI` | WPF panel (mở rộng thêm UI cho rule editor, batch) |
| `MtoCompat.cs` | Compatibility layer cho AutoCAD 2025+ vs 2018-2024 |

Các thành phần **bổ sung mới**:

| Thành phần | Mô tả |
|------------|-------|
| `MTOPlugin.Lisp` | AutoLISP wrapper để gọi .NET commands từ LISP |
| `MTOPlugin.Batch` | Engine xử lý nhiều file DWG |
| `MTOPlugin.RuleEditor` | UI cho phép tạo/sửa rule trực tiếp trong panel |
| `MTOPlugin.Reports` | Module xuất báo cáo mở rộng (PDF, CSV) |
| `MTOPlugin.DataCenter` | Module chuyên biệt cho phòng máy chủ |
| `MTOPlugin.DynamicBlock` | Đọc property từ dynamic blocks |

---

## 2. Kiến Trúc Hệ Thống

### 2.1 Tổng Quan Kiến Trúc

```
┌─────────────────────────────────────────────────────────────────┐
│                        AutoCAD Host                              │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │ LISP Layer  │  │ .NET Commands │  │ WPF MainPanel (UI)     │ │
│  │ (defun MTO) │  │ MTO, MTOZOOM │  │ RuleEditor, BatchUI    │ │
│  │ (defun MTB) │  │ MTOBANG      │  │ ScanOptions, Export    │ │
│  └──────┬──────┘  └──────┬───────┘  └───────────┬────────────┘ │
│         │                 │                       │               │
│         └─────────────────┼───────────────────────┘               │
│                           ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    ScannerHostBridge                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐   │  │
│  │  │AutoCadScanner│  │BatchScanner │  │DynamicBlockReader│   │  │
│  │  │(Block/Geom) │  │(Multi-DWG)  │  │(Property Read)  │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────┘   │  │
│  └──────────────────────────┬───────────────────────────────┘  │
│                             ▼                                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                       MTOPlugin.Core                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │  │
│  │  │RuleMatcher    │  │ClassifyEngine │  │ExcelExporter  │  │  │
│  │  │(wildcard/regex│  │(Priority,     │  │(5 sheets +   │  │  │
│  │  │layer, block)  │  │conditions)    │  │Batch export)  │  │  │
│  │  └──────────────┘  └──────────────┘  └───────────────┘  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │  │
│  │  │UnitConverter │  │XrefManager   │  │SessionManager │  │  │
│  │  └──────────────┘  └──────────────┘  └───────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    Data Layer                               │  │
│  │  rules.json (per-project)   config/rules.sample.json       │  │
│  │  ScanSession (in-memory)    Export templates               │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Luồng Dữ Liệu

```
1. User mở DWG → MTO command → WPF Panel hiện ra
2. User chọn: scope (model/layout), Xref mode, rules file, đơn vị, output path
3. BƯỚC 1: Quét + Phân loại
   └→ AutoCadScanner.Scan() → ScanResult
   └→ ClassificationEngine.Classify(scanResult, ruleSet) → ClassificationResult
   └→ Hiển thị bảng kết quả trên panel (TONG_HOP summary rows)
4. User đánh dấu (tick) các dòng muốn xuất
5. BƯỚC 2: Xuất các mục đã chọn / Xuất TOÀN BỘ
   └→ ExcelExporter.ExportSelected() / ExportAll()
   └→ File .xlsx được lưu
6. (Tùy chọn) MTOBANG → tạo bảng tổng hợp trên DWG mới
```

### 2.3 Module Chính

| Module | Namespace | Chức năng |
|--------|-----------|------------|
| **Core** | `MTOPro.Core` | Rule engine, classification, export |
| **Scanner** | `MTOPro.Scanner` | Đọc DWG entities |
| **Batch** | `MTOPro.Batch` | Xử lý nhiều file |
| **UI** | `MTOPro.UI` | WPF panel, rule editor |
| **Lisp** | `MTOPro.Lisp` | AutoLISP wrappers |
| **DynamicBlock** | `MTOPro.DynamicBlock` | Dynamic block property reader |
| **DataCenter** | `MTOPro.DataCenter` | Specialized for server room |
| **Reports** | `MTOPro.Reports` | PDF, CSV, extended exports |

### 2.4 Multi-Target Build Architecture

| Nhóm Bundle | AutoCAD | TFM | ngôn ngữ |
|-------------|---------|-----|----------|
| A | 2018–2022 (R22.0–R24.1) | net48 | C# |
| B | 2023–2024 (R24.2–R24.3) | net48 | C# |
| C | 2025–2026 (R25.0–R26.0) | net8.0-windows | C# |

**Lưu ý:** Máy build hiện tại chỉ có AutoCAD 2025 → chỉ build được nhóm C. Cần máy có AutoCAD 2018–2024 để build nhóm A và B.

---

## 3. Danh Mục Hệ Thống M&E

### 3.1 HỆ THỐNG ĐIỆN (Power)

#### 3.1.1 Chiếu Sáng (Lighting)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Đèn LED downlight | `EL-LIGHT-DL-*` | cái | Count |
| 2 | Đèn LED panel | `EL-LIGHT-PNL-*` | cái | Count |
| 3 | Đèn LED track | `EL-LIGHT-TRK-*` | cái | Count |
| 4 | Đèn âm trần (compact) | `EL-LIGHT-CMP-*` | cáí | Count |
| 5 | Đèn Exit | `EL-LIGHT-EXIT-*` | cái | Count |
| 6 | Đèn khẩn cấp (emergency) | `EL-LIGHT-EM-*` | cái | Count |
| 7 | Đèn ngoài trời | `EL-LIGHT-OUT-*` | cái | Count |
| 8 | Đèn trang trí | `EL-LIGHT-DEC-*` | cái | Count |
| 9 | ballast | `EL-BALLAST-*` | cái | Count |
| 10 | Driver LED | `EL-DRIVER-*` | cái | Count |

#### 3.1.2 Ổ Cắm & Công Tắc (Power Outlet & Switch)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Ổ cắm 1 phích | `EL-OUT-1P-*` | cái | Count |
| 2 | Ổ cắm 2 phích | `EL-OUT-2P-*` | cái | Count |
| 3 | Ổ cắm 3 phích | `EL-OUT-3P-*` | cái | Count |
| 4 | Ổ cắm công nghiệp | `EL-OUT-IND-*` | cái | Count |
| 5 | Ổ cắm âm sàn | `EL-OUT-FLR-*` | cái | Count |
| 6 | Công tắc 1 way | `EL-SW-1W-*` | cái | Count |
| 7 | Công tắc 2 way | `EL-SW-2W-*` | cái | Count |
| 8 | Công tắc dimmer | `EL-SW-DIM-*` | cái | Count |
| 9 | Ổ cắm USB | `EL-OUT-USB-*` | cái | Count |

#### 3.1.3 Tủ Điện (Panel Board)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Tủ điện chính | `EL-PNL-MDB-*` | cái | Count |
| 2 | Tủ phân phối | `EL-PNL-DB-*` | cái | Count |
| 3 | Tủ MCCB | `EL-PNL-MCCB-*` | cái | Count |
| 4 | Tủ ATS | `EL-PNL-ATS-*` | cái | Count |
| 5 | CB module | `EL-CB-*-*` | cái | Count |
| 6 | RCCB/ELCB | `EL-RCCB-*` | cái | Count |
| 7 | Contactor | `EL-CON-*-*` | cái | Count |
| 8 | Timer | `EL-TIMER-*` | cái | Count |

#### 3.1.4 Dây & Cáp Điện (Wire & Cable)

| STT | Loại | Layer prefix | Đơn vị | Cách tính |
|-----|------|-------------|---------|-----------|
| 1 | Cáp điện 1 lõi | `EL-CAB-1C-*` | m | SumLength |
| 2 | Cáp điện 2 lõi | `EL-CAB-2C-*` | m | SumLength × 2 |
| 3 | Cáp điện 3 lõi | `EL-CAB-3C-*` | m | SumLength × 3 |
| 4 | Cáp điện 4 lõi | `EL-CAB-4C-*` | m | SumLength × 4 |
| 5 | Cáp nguồn | `EL-CAB-PWR-*` | m | SumLength |
| 6 | Dây dẫn | `EL-WIRE-*` | m | SumLength |
| 7 | Cáp chống cháy | `EL-CAB-FR-*` | m | SumLength |

#### 3.1.5 Ống Luồn Dây (Conduit)

| STT | Loại | Layer prefix | Đơn vị | Cách tính |
|-----|------|-------------|---------|-----------|
| 1 | Ống âm tường | `EL-COND-WALL-*` | m | SumLength |
| 2 | Ống âm sàn | `EL-COND-SLAB-*` | m | SumLength |
| 3 | Ống nổi | `EL-COND-EXP-*` | m | SumLength |
| 4 | Ống ruột gà | `EL-COND-FLX-*` | m | SumLength |
| 5 | Ống HDPE | `EL-COND-HDPE-*` | m | SumLength |

#### 3.1.6 Khay Cáp (Cable Tray)

| STT | Loại | Layer prefix | Đơn vị | Cách tính |
|-----|------|-------------|---------|-----------|
| 1 | Khay cáp JIS | `EL-TRAY-J-*` | m | SumLength |
| 2 | Khay cáp ladder | `EL-TRAY-L-*` | m | SumLength |
| 3 | Khay cáp perforated | `EL-TRAY-P-*` | m | SumLength |
| 4 | Máng cáp | `EL-RACEWAY-*` | m | SumLength |
| 5 | Thanh C | `EL-TRUNK-C-*` | m | SumLength |

#### 3.1.7 Nối Dây & Hộp Đấu Nối

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Hộp nối | `EL-JBOX-*` | cái | Count |
| 2 | Hộp pulling | `EL-PBOX-*` | cái | Count |
| 3 | Đầu cos | `EL-LUG-*` | cái | Count |
| 4 | Mối nối | `EL-SPLICE-*` | cái | Count |

---

### 3.2 HỆ THỐNG NƯỚC (Plumbing)

#### 3.2.1 Ống Cấp Nước

| STT | Loại | Layer prefix | Đơn vị | Cách tính |
|-----|------|-------------|---------|-----------|
| 1 | Ống PVC-C | `PLB-PIPE-PVC-C-*` | m | SumLength |
| 2 | Ống PPR | `PLB-PIPE-PPR-*` | m | SumLength |
| 3 | Ống HDPE | `PLB-PIPE-HDPE-*` | m | SumLength |
| 4 | Ống INOX | `PLB-PIPE-INOX-*` | m | SumLength |
| 5 | Ống đồng | `PLB-PIPE-CU-*` | m | SumLength |
| 6 | Ống luồn trong tường | `PLB-PIPE-WALL-*` | m | SumLength |
| 7 | Ống luồn trong sàn | `PLB-PIPE-SLAB-*` | m | SumLength |

#### 3.2.2 Ống Thoát Nước

| STT | Loại | Layer prefix | Đơn vị | Cách tính |
|-----|------|-------------|---------|-----------|
| 1 | Ống thoát PVC | `PLB-DRAIN-PVC-*` | m | SumLength |
| 2 | Ống thoát HDPE | `PLB-DRAIN-HDPE-*` | m | SumLength |
| 3 | Ống thông hơi | `PLB-VENT-*` | m | SumLength |
| 4 | Ống rống (soil) | `PLB-SOIL-*` | m | SumLength |
| 5 | Ống xả | `PLB-WASTE-*` | m | SumLength |

#### 3.2.3 Thiết Bị Vệ Sinh

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Bồn cầu | `PLB-FIX-WC-*` | cái | Count |
| 2 | Chậu rửa (lavabo) | `PLB-FIX-LAV-*` | cái | Count |
| 3 | Chậu rửa bát | `PLB-FIX-SINK-*` | cái | Count |
| 4 | Bồn tiểu | `PLB-FIX-UR-*` | cái | Count |
| 5 | Vòi lavabo | `PLB-FIX-VALV-LAV-*` | cái | Count |
| 6 | Vòi rửa bát | `PLB-FIX-VALV-SNK-*` | cái | Count |
| 7 | Vòi sen | `PLB-FIX-SHOWER-*` | cái | Count |
| 8 | Bồn tắm | `PLB-FIX-BATH-*` | cái | Count |
| 9 | Chậu rửa mặt (column) | `PLB-FIX-COL-*` | cái | Count |
| 10 | Gương | `PLB-FIX-MIRR-*` | cái | Count |

#### 3.2.4 Van

| STT | Loại | Block prefix | Đơn vị | Cách tính |
|-----|------|-------------|---------|-----------|
| 1 | Van cổng | `PLB-VALVE-GATE-*` | cái | Count |
| 2 | Van bi | `PLB-VALVE-BALL-*` | cái | Count |
| 3 | Van một chiều | `PLB-VALVE-CHECK-*` | cái | Count |
| 4 | Van giảm áp | `PLB-VALVE-PRV-*` | cái | Count |
| 5 | Van cân bằng | `PLB-VALVE-BAL-*` | cái | Count |
| 6 | Van xả tay | `PLB-VALVE-DRAIN-*` | cái | Count |
| 7 | Van điện từ | `PLB-VALVE-SOL-*` | cái | Count |

#### 3.2.5 Phụ Kiện Ống

| STT | Phụ kiện | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Co 90° | `PLB-FIT-ELB90-*` | cái | Count + Angle detection |
| 2 | Co 45° | `PLB-FIT-ELB45-*` | cái | Count + Angle detection |
| 3 | Tê | `PLB-FIT-TEE-*` | cái | Count |
| 4 | Cút nối | `PLB-FIT-CPL-*` | cái | Count |
| 5 | Tê giảm | `PLB-FIT-RED-*` | cái | Count |
| 6 | Nippel | `PLB-FIT-NIP-*` | cái | Count |
| 7 | Van một chiều | `PLB-FIT-CHK-*` | cái | Count |
| 8 | Bẫy mùi (P-trap) | `PLB-FIT-PTRAP-*` | cái | Count |

#### 3.2.6 Bơm & Bể Chứa

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Bơm nước | `PLB-PUMP-*` | cái | Count |
| 2 | Bồn nước | `PLB-TANK-*` | cái | Count |
| 3 | Bể xử lý nước | `PLB-FILTER-*` | cái | Count |
| 4 | Máy nước nóng | `PLB-GEY-*` | cái | Count |

---

### 3.3 HỆ THỐNG ĐIỆN NHẸ (ELV)

#### 3.3.1 Mạng Máy Tính (LAN)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Switch Core | `ELV-NET-CORE-*` | cái | Count |
| 2 | Switch Distribution | `ELV-NET-DIST-*` | cái | Count |
| 3 | Switch Access | `ELV-NET-ACC-*` | cái | Count |
| 4 | Switch PoE | `ELV-NET-POE-*` | cái | Count |
| 5 | Router | `ELV-NET-RTR-*` | cái | Count |
| 6 | Firewall | `ELV-NET-FW-*` | cái | Count |
| 7 | Load Balancer | `ELV-NET-LB-*` | cái | Count |
| 8 | WiFi Controller | `ELV-NET-WLC-*` | cái | Count |
| 9 | Access Point | `ELV-NET-AP-*` | cái | Count |
| 10 | IP Phone | `ELV-NET-PHONE-*` | cái | Count |

#### 3.3.2 Server Room / Data Center

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Server Rack | `ELV-DC-RACK-*` | cái | Count |
| 2 | Server | `ELV-DC-SRV-*` | cái | Count |
| 3 | Storage/NAS | `ELV-DC-STOR-*` | cái | Count |
| 4 | UPS | `ELV-DC-UPS-*` | cái | Count |
| 5 | PDU | `ELV-DC-PDU-*` | cái | Count |
| 6 | KVM Switch | `ELV-DC-KVM-*` | cái | Count |
| 7 | Patch Panel | `ELV-DC-PP-*` | cái | Count (port) |
| 8 | ODF (Fiber) | `ELV-DC-ODF-*` | cái | Count (port) |
| 9 | Switch Data Center | `ELV-DC-SW-*` | cái | Count |
| 10 | Firewall Data Center | `ELV-DC-FW-*` | cái | Count |

#### 3.3.3 Cáp & Vật Tư Mạng

| STT | Loại | Layer prefix | Đơn vị | Cách tính |
|-----|------|-------------|---------|-----------|
| 1 | Cáp Cat6 | `ELV-CAB-CAT6-*` | m | SumLength |
| 2 | Cáp Cat6A | `ELV-CAB-CAT6A-*` | m | SumLength |
| 3 | Cáp Cat7 | `ELV-CAB-CAT7-*` | m | SumLength |
| 4 | Cáp Fiber MM OM3 | `ELV-CAB-FOMM3-*` | m | SumLength |
| 5 | Cáp Fiber MM OM4 | `ELV-CAB-FOMM4-*` | m | SumLength |
| 6 | Cáp Fiber SM | `ELV-CAB-FOSM-*` | m | SumLength |
| 7 | Patch Cord Cat6 | `ELV-PATCH-CAT6-*` | sợi | Count |
| 8 | Patch Cord Fiber | `ELV-PATCH-FO-*` | sợi | Count |

#### 3.3.4 Camera Giám Sát (CCTV)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Camera Dome | `ELV-CAM-DOME-*` | cái | Count |
| 2 | Camera Bullet | `ELV-CAM-BUL-*` | cái | Count |
| 3 | Camera PTZ | `ELV-CAM-PTZ-*` | cái | Count |
| 4 | Camera Cube | `ELV-CAM-CUBE-*` | cái | Count |
| 5 | Camera Fisheye | `ELV-CAM-FISH-*` | cái | Count |
| 6 | Đầu ghi NVR | `ELV-CAM-NVR-*` | cái | Count |
| 7 | Màn hình giám sát | `ELV-CAM-MON-*` | cái | Count |
| 8 | PoE Switch (CCTV) | `ELV-CAM-POE-*` | cái | Count |

#### 3.3.5 Kiểm Soát Ra Vào (Access Control)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Controller trung tâm | `ELV-ACC-CTRL-*` | cái | Count |
| 2 | Đầu đọc thẻ RFID | `ELV-ACC-RDR-*` | cái | Count |
| 3 | Đầu đọc vân tay | `ELV-ACC-FP-*` | cái | Count |
| 4 | Đầu đọc khuôn mặt | `ELV-ACC-FACE-*` | cái | Count |
| 5 | Khóa điện từ (Maglock) | `ELV-ACC-MAG-*` | cái | Count |
| 6 | Nút Exit | `ELV-ACC-EXIT-*` | cái | Count |
| 7 | Cảm biến cửa | `ELV-ACC-DSEN-*` | cái | Count |
| 8 | Bộ chấm công | `ELV-ACC-TA-*` | cái | Count |
| 9 | Barrier gate | `ELV-ACC-BAR-*` | cái | Count |

#### 3.3.6 Báo Cháy (Fire Alarm)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Tủ trung tâm FACP | `ELV-FA-PANEL-*` | cái | Count |
| 2 | Đầu báo khói | `ELV-FA-SMOKE-*` | cái | Count |
| 3 | Đầu báo nhiệt | `ELV-FA-HEAT-*` | cái | Count |
| 4 | Đầu báo beam | `ELV-FA-BEAM-*` | cái | Count |
| 5 | Nút nhấn MCP | `ELV-FA-MCP-*` | cái | Count |
| 6 | Chuông báo | `ELV-FA-BELL-*` | cái | Count |
| 7 | Còi báo | `ELV-FA-SIREN-*` | cái | Count |
| 8 | Đèn strobe | `ELV-FA-STRB-*` | cái | Count |
| 9 | Module liên kết | `ELV-FA-IMOD-*` | cái | Count |
| 10 | Cách ly (Isolator) | `ELV-FA-ISO-*` | cái | Count |

#### 3.3.7 Âm Thanh Thông Báo (PA)

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Loa âm trần | `ELV-PA-SPK-CL-*` | cái | Count |
| 2 | Loa nén (horn) | `ELV-PA-SPK-HN-*` | cái | Count |
| 3 | Loa hộp | `ELV-PA-SPK-BOX-*` | cái | Count |
| 4 | Amplifier | `ELV-PA-AMP-*` | cái | Count |
| 5 | Mixer Amplifier | `ELV-PA-MIXER-*` | cái | Count |
| 6 | Micro cầm tay | `ELV-PA-MIC-HH-*` | cái | Count |
| 7 | Micro bàn | `ELV-PA-MIC-STD-*` | cái | Count |
| 8 | Zone Selector | `ELV-PA-ZONE-*` | cái | Count |
| 9 | Bộ phát nhạc BGM | `ELV-PA-BGM-*` | cái | Count |
| 10 | Volume Control | `ELV-PA-VOL-*` | cái | Count |

#### 3.3.8 Truyền Hình / IPTV

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | IPTV Server | `ELV-TV-SRV-*` | cái | Count |
| 2 | Set-top Box | `ELV-TV-STB-*` | cái | Count |
| 3 | Màn hình | `ELV-TV-MON-*` | cái | Count |
| 4 | HDMI Extender | `ELV-TV-EXT-*` | cái | Count |

#### 3.3.9 Intercom / Chuông Cửa

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Màn hình trong nhà | `ELV-INT-IND-*` | cái | Count |
| 2 | Camera chuông cửa | `ELV-INT-DB-*` | cái | Count |
| 3 | Bảng gọi cổng | `ELV-INT-GATE-*` | cái | Count |

#### 3.3.10 BMS / Tòa Nhà Thông Minh

| STT | Thiết bị | Block prefix | Đơn vị | Cách tính |
|-----|----------|-------------|---------|-----------|
| 1 | Server BMS | `ELV-BMS-SRV-*` | cái | Count |
| 2 | DDC Controller | `ELV-BMS-DDC-*` | cái | Count |
| 3 | PLC | `ELV-BMS-PLC-*` | cái | Count |
| 4 | Cảm biến nhiệt độ | `ELV-BMS-TEMP-*` | cái | Count |
| 5 | Cảm biến ẩm | `ELV-BMS-HUM-*` | cái | Count |
| 6 | Cảm biến áp suất | `ELV-BMS-PRES-*` | cái | Count |
| 7 | Biến tần VFD | `ELV-BMS-VFD-*` | cái | Count |
| 8 | Touch Panel | `ELV-BMS-TP-*` | cái | Count |

---

## 4. Quy Ước Đặt Tên Layer & Block

### 4.1 Quy Tắc Chung

```
[Prefix]-[Loai]-[ThuocTinh]-[KichThuoc]
```

| Quy tắc | Ví dụ |
|---------|-------|
| Layer dùng cho geometry (đường ống, cáp) | `EL-COND-WALL-DN20` |
| Block dùng cho thiết bị (đếm) | `EL-LIGHT-DL-10W` |
| Ngăn cách bằng `-` (dashes) | Không dùng `_` hay space |
| Kích thước ghi rõ đơn vị | `EL-COND-WALL-DN20` (DN = danh nghĩa) |
| Wildcard pattern `*` để match nhiều | `EL-LIGHT-DL-*` = tất cả downlight |
| Không dùng tiếng Việt có dấu | Dùng tiếng Việt không dấu hoặc tiếng Anh |

### 4.2 Layer Naming Convention

#### Hệ Thống Điện (Power)

```
EL-              → Prefix điện
  COND-          → Conduit (ống luồn)
    WALL-        → Ống âm tường
    SLAB-        → Ống âm sàn
    EXP-         → Ống nổi
    FLX-         → Ống ruột gà
  CAB-           → Cable (cáp điện)
    1C-          → 1 lõi
    2C-          → 2 lõi
    3C-          → 3 lõi
    4C-          → 4 lõi
    PWR-         → Nguồn
  TRAY-          → Cable tray
    J-           → JIS
    L-           → Ladder
    P-           → Perforated
  LIGHT-         → Dây chiếu sáng
  OUT-           → Dây ổ cắm
  SW-            → Dây công tắc
```

**Ví dụ đầy đủ:** `EL-COND-WALL-DN20`, `EL-CAB-3C-25mm2`, `EL-TRAY-J-100x50`

#### Hệ Thống Nước (Plumbing)

```
PLB-             → Prefix nước
  PIPE-          → Ống
    PVC-C-       → PVC-C
    PPR-         → PPR
    HDPE-        → HDPE
    INOX-        → INOX
    CU-          → Đồng
    WALL-        → Ống âm tường
    SLAB-        → Ống âm sàn
  DRAIN-         → Ống thoát
    PVC-         → PVC
    HDPE-        → HDPE
  VENT-          → Ống thông hơi
  FIT-           → Phụ kiện (co, tê)
    ELB90-       → Co 90°
    ELB45-       → Co 45°
    TEE-         → Tê
    RED-         → Giảm
```

**Ví dụ đầy đủ:** `PLB-PIPE-PPR-DN25`, `PLB-DRAIN-PVC-DN50`, `PLB-FIT-ELB90-DN25`

#### Hệ Thống Điện Nhẹ (ELV)

```
ELV-             → Prefix ELV
  NET-           → Mạng
    CAB-         → Cáp mạng
      CAT6-      → Cat6
      CAT6A-     → Cat6A
      FOMM3-     → Fiber MM OM3
      FOMM4-     → Fiber MM OM4
      FOSM-      → Fiber SM
  CAM-           → Camera
  ACC-           → Access Control
  FA-            → Fire Alarm
    CAB-         → Cáp báo cháy
  PA-            → PA/Amplifier
  TV-            → IPTV
  INT-           → Intercom
  BMS-           → BMS
  DC-            → Data Center
    CAB-         → Cáp data center
```

**Ví dụ đầy đủ:** `ELV-NET-CAB-CAT6A`, `ELV-CAM-DOME-4MP`, `ELV-FA-SMOKE-ADW`

### 4.3 Block Naming Convention

```
[System]-[Type]-[Model]-[Variant]
```

**Ví dụ:**

| Block | Mô tả |
|-------|-------|
| `EL-LIGHT-DL-10W-40K` | Đèn downlight LED 10W 4000K |
| `EL-OUT-2P-16A-IP44` | Ổ cắm 2 phích 16A IP44 |
| `EL-PNL-MDB-400A` | Tủ điện chính 400A |
| `PLB-FIX-WC-TOTO-CW` | Bồn cầu TOTO |
| `ELV-CAM-DOME-4MP-SD` | Camera dome 4MP có SD |
| `ELV-ACC-RDR-RFID-125K` | Đầu đọc RFID 125kHz |

### 4.4 Thuộc Tính Block Quan Trọng Cần Trích Xuất

| Hệ | Block | Attributes cần đọc |
|----|-------|-------------------|
| Lighting | `EL-LIGHT-DL-*` | WATTAGE, COLOR_TEMP, BRAND |
| Power | `EL-OUT-*` | RATING, TYPE, PIN_COUNT |
| Panel | `EL-PNL-*-*` | RATING, CIRCUIT_COUNT, BRAND |
| CCTV | `ELV-CAM-*-*` | RESOLUTION, MODEL, IP |
| Access | `ELV-ACC-RDR-*` | READER_TYPE, FREQUENCY |
| Fire Alarm | `ELV-FA-*-*` | TYPE, ADDRESS, ZONE |
| Server | `ELV-DC-SRV-*` | CPU, RAM, STORAGE, POWER |
| Switch | `ELV-NET-ACC-*` | POE_PORTS, TOTAL_PORTS |

---

## 5. Rule Engine - Thiết Kế Chi Tiết

### 5.1 Rule Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "MTORuleSet",
  "version": "1.0",
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "version": { "type": "string" },
    "description": { "type": "string" },
    "createdBy": { "type": "string" },
    "lastModified": { "type": "string", "format": "date-time" },
    "systems": {
      "type": "array",
      "items": { "$ref": "#/definitions/system" }
    },
    "rules": {
      "type": "array",
      "items": { "$ref": "#/definitions/rule" }
    }
  },
  "definitions": {
    "system": {
      "type": "object",
      "properties": {
        "code": { "type": "string" },
        "name": { "type": "string" },
        "description": { "type": "string" },
        "unit": { "type": "string" }
      }
    },
    "rule": {
      "type": "object",
      "required": ["code", "systemCode", "materialCode", "materialName", "unit", "conditions", "calculation", "priority", "status"],
      "properties": {
        "code": { "type": "string" },
        "version": { "type": "string" },
        "description": { "type": "string" },
        "systemCode": { "type": "string" },
        "materialCode": { "type": "string" },
        "materialName": { "type": "string" },
        "specification": { "type": "string" },
        "unit": { "type": "string" },
        "conditions": { "$ref": "#/definitions/conditions" },
        "calculation": {
          "type": "string",
          "enum": ["Count", "SumLength", "SumLengthTimesFactor", "SumLengthCeilingStep", "SumAttributeValue", "CountIfAttributeEquals"]
        },
        "factor": { "type": "number" },
        "ceilingStep": { "type": "number" },
        "sumAttribute": { "type": "string" },
        "attributeCondition": { "$ref": "#/definitions/attributeCondition" },
        "priority": { "type": "integer", "minimum": 1, "maximum": 1000 },
        "status": { "type": "string", "enum": ["Active", "Draft", "Paused"] },
        "approvedBy": { "type": "string" },
        "approvedAt": { "type": "string", "format": "date-time" },
        "notes": { "type": "string" }
      }
    },
    "conditions": {
      "type": "object",
      "properties": {
        "entityKind": {
          "type": "string",
          "enum": ["block", "geometry", "any"]
        },
        "layers": { "type": "string" },
        "layerRegex": { "type": "string" },
        "blockNames": { "type": "string" },
        "blockNameRegex": { "type": "string" },
        "effectiveBlockNames": { "type": "string" },
        "attributes": { "type": "string" },
        "geometryKinds": { "type": "string" },
        "linetypes": { "type": "string" },
        "colorIndexes": { "type": "string" },
        "requireDynamicBlock": { "type": "boolean" },
        "dynamicProperty": {
          "type": "object",
          "properties": {
            "propertyName": { "type": "string" },
            "operator": { "type": "string", "enum": ["equals", "contains", "greaterThan", "lessThan"] },
            "value": { "type": "string" }
          }
        }
      }
    },
    "attributeCondition": {
      "type": "object",
      "properties": {
        "attribute": { "type": "string" },
        "operator": { "type": "string", "enum": ["equals", "notEquals", "contains", "greaterThan", "lessThan"] },
        "value": { "type": "string" },
        "action": { "type": "string", "enum": ["include", "exclude", "extract"] }
      }
    }
  }
}
```

### 5.2 Calculation Types Chi Tiết

| Type | Mô tả | Ví dụ | Công thức |
|------|--------|-------|-----------|
| `Count` | Đếm mỗi đối tượng = 1 | Đếm đèn, ổ cắm | `count` |
| `SumLength` | Tổng chiều dài geometry | Ống nước, cáp điện | `∑ length` |
| `SumLengthTimesFactor` | Tổng × hệ số | Cáp 3 lõi: factor=3 | `∑ length × factor` |
| `SumLengthCeilingStep` | Làm tròn lên theo bước | Thanh cáp 3m: bước=3 | `ceil(∑ length / step) × step` |
| `SumAttributeValue` | Tổng giá trị attribute | Tổng công suất đèn | `∑ attr.value` |
| `CountIfAttributeEquals` | Đếm nếu attribute khớp | Đếm đèn 10W | `count where attr == value` |

### 5.3 Ví Dụ Rules Đầy Đủ

```json
{
  "name": "MTO Rules - Cong Ty Xay Lap Dien Nuoc",
  "version": "1.0",
  "description": "Bo quy tac chuan cho he thong dien, nuoc, dien nhe",
  "createdBy": "Phong Du An - IT",
  "lastModified": "2026-09-16T00:00:00",
  "systems": [
    { "code": "HE-DIEN", "name": "He thong dien", "description": "Dien chieu sang, o cam, tu dien", "unit": "" },
    { "code": "HE-NUOC", "name": "He thong nuoc", "description": "Cap nuoc, thoat nuoc", "unit": "" },
    { "code": "HE-ELV-NET", "name": "Mang may tinh", "description": "Switch, router, AP", "unit": "" },
    { "code": "HE-ELV-CCTV", "name": "Camera giam sat", "description": "Camera, NVR", "unit": "" },
    { "code": "HE-ELV-ACC", "name": "Kiem soat ra vao", "description": "Access control", "unit": "" },
    { "code": "HE-ELV-FA", "name": "Bao chay", "description": "Fire alarm", "unit": "" },
    { "code": "HE-ELV-PA", "name": "Am thanh thong bao", "description": "PA system", "unit": "" }
  ],
  "rules": [
    {
      "code": "R-DIEN-001",
      "version": "1.0",
      "description": "Ong luon dien PVC am tuong",
      "systemCode": "HE-DIEN",
      "materialCode": "VL-DIEN-001",
      "materialName": "Ong PVC day 20mm",
      "specification": "PVC D20",
      "unit": "m",
      "conditions": {
        "entityKind": "geometry",
        "layers": "EL-COND-WALL-DN20;EL-COND-WALL-*",
        "geometryKinds": "Polyline;Polyline2D;Polyline3D;Line"
      },
      "calculation": "SumLength",
      "factor": 1.0,
      "priority": 100,
      "status": "Active",
      "approvedBy": "KS-Nguyen Van A",
      "approvedAt": "2026-09-01T00:00:00"
    },
    {
      "code": "R-DIEN-002",
      "version": "1.0",
      "description": "Den LED downlight",
      "systemCode": "HE-DIEN",
      "materialCode": "VL-DIEN-101",
      "materialName": "Den LED downlight 10W",
      "specification": "10W, 4000K, 900lm",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "EL-LIGHT-DL-10W*;EL-LIGHT-DL-*",
        "attributes": "WATTAGE=10*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-DIEN-003",
      "version": "1.0",
      "description": "Cap dien 3 loi",
      "systemCode": "HE-DIEN",
      "materialCode": "VL-DIEN-201",
      "materialName": "Cap dien 3 loi 2.5mm2",
      "specification": "CV 3x2.5mm2",
      "unit": "m",
      "conditions": {
        "entityKind": "geometry",
        "layers": "EL-CAB-3C-*;EL-CAB-PWR-*",
        "geometryKinds": "Polyline;Polyline2D;Polyline3D;Line"
      },
      "calculation": "SumLengthTimesFactor",
      "factor": 3.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-DIEN-004",
      "version": "1.0",
      "description": "Khay cap JIS 100x50",
      "systemCode": "HE-DIEN",
      "materialCode": "VL-DIEN-301",
      "materialName": "Khay cap JIS 100x50",
      "specification": "100x50mm",
      "unit": "m",
      "conditions": {
        "entityKind": "geometry",
        "layers": "EL-TRAY-J-100x50;EL-TRAY-J-*",
        "geometryKinds": "Polyline;Polyline2D;Polyline3D;Line"
      },
      "calculation": "SumLength",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-NUOC-001",
      "version": "1.0",
      "description": "Ong nuoc PPR am tuong DN25",
      "systemCode": "HE-NUOC",
      "materialCode": "VL-NUOC-001",
      "materialName": "Ong PPR D25",
      "specification": "PPR DN25",
      "unit": "m",
      "conditions": {
        "entityKind": "geometry",
        "layers": "PLB-PIPE-PPR-DN25;PLB-PIPE-WALL-*",
        "geometryKinds": "Polyline;Polyline2D;Polyline3D;Line"
      },
      "calculation": "SumLength",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-NUOC-002",
      "version": "1.0",
      "description": "Van bi DN25",
      "systemCode": "HE-NUOC",
      "materialCode": "VL-NUOC-101",
      "materialName": "Van bi DN25",
      "specification": "Brass, 16bar",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "PLB-VALVE-BALL-DN25;PLB-VALVE-BALL-*",
        "attributes": "SIZE=DN25"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-NUOC-003",
      "version": "1.0",
      "description": "Bon cau",
      "systemCode": "HE-NUOC",
      "materialCode": "VL-NUOC-201",
      "materialName": "Bon cau cat dua",
      "specification": "TOTO CW922J",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "PLB-FIX-WC-*;PLB-FIX-WC-TOTO-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-NET-001",
      "version": "1.0",
      "description": "Switch Access 24 port PoE",
      "systemCode": "HE-ELV-NET",
      "materialCode": "VL-ELV-001",
      "materialName": "Switch PoE 24 port",
      "specification": "24GE PoE+, 370W",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-NET-POE-24*;ELV-NET-ACC-24*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-NET-002",
      "version": "1.0",
      "description": "Cap Cat6A",
      "systemCode": "HE-ELV-NET",
      "materialCode": "VL-ELV-101",
      "materialName": "Cap Cat6A",
      "specification": "Cat6A, S/FTP",
      "unit": "m",
      "conditions": {
        "entityKind": "geometry",
        "layers": "ELV-NET-CAB-CAT6A*;ELV-CAB-CAT6A*",
        "geometryKinds": "Polyline;Polyline2D;Polyline3D;Line"
      },
      "calculation": "SumLength",
      "factor": 1.05,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-NET-003",
      "version": "1.0",
      "description": "Access Point",
      "systemCode": "HE-ELV-NET",
      "materialCode": "VL-ELV-201",
      "materialName": "Access Point WiFi 6",
      "specification": "AX1800, Ceiling mount",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-NET-AP-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-CCTV-001",
      "version": "1.0",
      "description": "Camera Dome 4MP",
      "systemCode": "HE-ELV-CCTV",
      "materialCode": "VL-ELV-301",
      "materialName": "Camera IP Dome 4MP",
      "specification": "4MP, IR 30m, IP67",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-CAM-DOME-4MP*;ELV-CAM-DOME-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-CCTV-002",
      "version": "1.0",
      "description": "Dau ghi NVR",
      "systemCode": "HE-ELV-CCTV",
      "materialCode": "VL-ELV-302",
      "materialName": "NVR 32 kenh",
      "specification": "32CH, 4HDD, 4K",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-CAM-NVR-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-ACC-001",
      "version": "1.0",
      "description": "Dau doc the RFID",
      "systemCode": "HE-ELV-ACC",
      "materialCode": "VL-ELV-401",
      "materialName": "Dau doc the RFID",
      "specification": "125kHz, Wiegand",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-ACC-RDR-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-ACC-002",
      "version": "1.0",
      "description": "Khoa dien tu maglock",
      "systemCode": "HE-ELV-ACC",
      "materialCode": "VL-ELV-402",
      "materialName": "Khoa dien tu 280kg",
      "specification": "280kgf, 12V",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-ACC-MAG-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-FA-001",
      "version": "1.0",
      "description": "Dau bao khoi",
      "systemCode": "HE-ELV-FA",
      "materialCode": "VL-ELV-501",
      "materialName": "Dau bao khoi dua len",
      "specification": "Addressable, 24V",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-FA-SMOKE-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-FA-002",
      "version": "1.0",
      "description": "Nut nhan MCP",
      "systemCode": "HE-ELV-FA",
      "materialCode": "VL-ELV-502",
      "materialName": "Nut nhan khan",
      "specification": "Addressable, IP67",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-FA-MCP-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-PA-001",
      "version": "1.0",
      "description": "Loa am tran 6W",
      "systemCode": "HE-ELV-PA",
      "materialCode": "VL-ELV-601",
      "materialName": "Loa am tran 6W",
      "specification": "6W, 100V, Ceiling",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-PA-SPK-CL-6W*;ELV-PA-SPK-CL-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-PA-002",
      "version": "1.0",
      "description": "Amplifier 120W",
      "systemCode": "HE-ELV-PA",
      "materialCode": "VL-ELV-602",
      "materialName": "Amplifier 120W",
      "specification": "120W, 100V",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-PA-AMP-120W*;ELV-PA-AMP-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-DC-001",
      "version": "1.0",
      "description": "Tu rack 42U",
      "systemCode": "HE-ELV-DC",
      "materialCode": "VL-ELV-701",
      "materialName": "Tu rack 42U",
      "specification": "42U, 600x1000mm",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-DC-RACK-42U*;ELV-DC-RACK-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    },
    {
      "code": "R-ELV-DC-002",
      "version": "1.0",
      "description": "UPS 10kVA",
      "systemCode": "HE-ELV-DC",
      "materialCode": "VL-ELV-702",
      "materialName": "UPS 10kVA Online",
      "specification": "10kVA, 10kW, 30min",
      "unit": "cái",
      "conditions": {
        "entityKind": "block",
        "blockNames": "ELV-DC-UPS-10K*;ELV-DC-UPS-*"
      },
      "calculation": "Count",
      "factor": 1.0,
      "priority": 100,
      "status": "Active"
    }
  ]
}
```

---

## 6. Kết Quả Xuất Excel

### 6.1 Cấu Trúc File Excel

```
MTO_Export_[DwgName]_[YYYYMMDD]_[HHMMSS].xlsx
```

### 6.2 Sheet Definitions

#### Sheet 1: TONG_HOP (Summary)

| STT | Column | Mô tả |
|-----|--------|-------|
| 1 | Ma he | System code (HE-DIEN, HE-NUOC, HE-ELV-*) |
| 2 | Ten he | Tên hệ thống |
| 3 | Ma vat tu | Material code |
| 4 | Ten vat tu | Material name |
| 5 | Quy cach | Specification |
| 6 | Don vi | Unit (m, cái, bộ) |
| 7 | Khoi luong | Tổng khối lượng |
| 8 | So doi tuong | Số lượng đối tượng đã quét |
| 9 | Trang thai | Status message |
| 10 | Ghi chu | Notes |

#### Sheet 2: CHI_TIET (Details)

| STT | Column | Mô tả |
|-----|--------|-------|
| 1 | STT | Số thứ tự |
| 2 | File | Tên file DWG |
| 3 | Xref nguon | Tên Xref nếu có |
| 4 | Layout/Tang | Layout name hoặc tầng |
| 5 | Layer | Layer name |
| 6 | Loai | Loại entity (Block, Line, Polyline...) |
| 7 | Block | Block name |
| 8 | Block hoat dong | Effective name (dynamic block) |
| 9 | Thuoc tinh | Attributes (KEY=VALUE) |
| 10 | Chieu dai goc | Chiều dài gốc (đơn vị bản vẽ) |
| 11 | Don vi goc | Đơn vị gốc |
| 12 | Chieu dai quy doi | Chiều dài đã quy đổi |
| 13 | Don vi quy doi | Đơn vị xuất |
| 14 | Cach tinh | Calculation type |
| 15 | Ma quy tac | Rule code matched |
| 16 | Ma he | System code |
| 17 | Ma vat tu | Material code |
| 18 | Ten vat tu | Material name |
| 19 | Quy cach | Specification |
| 20 | Don vi tinh | Unit |
| 21 | Khoi luong | Khối lượng |
| 22 | Handle | Handle đối tượng (hex) |
| 23 | Vi tri X | Position X |
| 24 | Vi tri Y | Position Y |
| 25 | Vi tri Z | Position Z |

#### Sheet 3: CHUA_PHAN_LOAI (Unclassified)

| STT | Column | Mô tả |
|-----|--------|-------|
| 1 | STT | Số thứ tự |
| 2 | File | Tên file DWG |
| 3 | Handle | Handle đối tượng |
| 4 | Layer | Layer name |
| 5 | Loai | Entity type |
| 6 | Block | Block name |
| 7 | Block hoat dong | Effective block name |
| 8 | Thuoc tinh | Attributes |
| 9 | Chieu dai goc | Chiều dài gốc |
| 10 | Layout/Tang | Layout/Tầng |
| 11 | Nguon | Xref source |
| 12 | Nguyen nhan | Lý do không khớp rule |
| 13 | Goi y anh xa | Gợi ý rule có thể khớp |

#### Sheet 4: CANH_BAO_LOI (Warnings)

| STT | Column | Mô tả |
|-----|--------|-------|
| 1 | Ma canh bao | Warning code (W001, E001...) |
| 2 | Muc do | Severity (INFO, WARNING, ERROR) |
| 3 | Noi dung | Warning message |
| 4 | File | File DWG |
| 5 | Layout | Layout name |
| 6 | Layer | Layer |
| 7 | Handle | Handle đối tượng |
| 8 | Xu ly | Suggested action |

#### Sheet 5: THONG_TIN_LAN_QUET (Scan Info)

| STT | Nội dung | Giá trị |
|-----|----------|---------|
| 1 | Ten ban ve | Tên file DWG |
| 2 | Duong dan day du | Full path |
| 3 | Thoi gian chay | Timestamp |
| 4 | Nguoi chay | Username |
| 5 | Phien ban plugin | Plugin version |
| 6 | Phien ban bo quy tac | Rule set version |
| 7 | Pham vi quet | Scope (Model/Layout...) |
| 8 | Che do Xref | Xref mode |
| 9 | Tong so doi tuong quet | Total scanned |
| 10 | So doi tuong phan loai | Classified count |
| 11 | So doi tuong chua phan loai | Unclassified count |
| 12 | Ti le phan loai | Classification rate % |
| 13 | Don vi nguon | Source unit (DWG units) |
| 14 | Don vi xuat | Export unit |
| 15 | Thoi gian quet (ms) | Scan duration |
| 16 | So loi | Error count |
| 17 | Kieu xuat | Export type (toan bo / da chon) |
| 18 | So muc da xuat | Number of items exported |
| 19 | File rules su dung | Rules file path |
| 20 | Hash rules | SHA256 hash of rules file |

---

## 7. Giao Diện Người Dùng

### 7.1 Main Panel Layout (WPF)

```
┌─────────────────────────────────────────────────────────────────┐
│  MTOPro - He Thong Boc Tach Khoi Luong M&E              [_][X] │
├─────────────────────────────────────────────────────────────────┤
│  ┌─ PHẠM VI QUÉT ──────────────────────────────────────────┐   │
│  │  ○ Vùng chọn   ● Model   ○ Layout hiện tại   ○ Tất cả   │   │
│  │  ○ Model + Layout hiện tại   ○ Model + Tất cả Layout    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ XREF ───────────────────────────────────────────────────┐   │
│  │  ○ Bỏ qua (Ignore)                                       │   │
│  │  ○ Một lần mỗi nguồn (UniqueBySource) ← recommended    │   │
│  │  ○ Theo từng lần chèn (PerInsertion)                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ CẤU HÌNH ───────────────────────────────────────────────┐   │
│  │  Bo quy tac: [________________________] [Browse...]     │   │
│  │  Don vi: [mm ▼]  →  Xuat: [m ▼]                        │   │
│  │  File xuat: [________________________] [Browse...]       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ BƯỚC 1: QUÉT + PHÂN LOẠI ──────────────────────────────┐   │
│  │                                                         │   │
│  │     [  QUÉT + PHÂN LOẠI  ]  ← Big primary button       │   │
│  │                                                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ KẾT QUẢ ───────────────────────────────────────────────┐   │
│  │  Tong so: 1,234  |  Da phan loai: 1,100  |  Chua: 134  │   │
│  │  ═══════════════════════════════════════════════════    │   │
│  │  ☑ Da chon: 45 muc  (tich chon de xuat)                │   │
│  │  ┌──────────────────────────────────────────────────┐    │   │
│  │  │ ☐ HE-DIEN | Den LED Downlight 10W | cái | 25     │    │   │
│  │  │ ☑ HE-DIEN | Ong PVC D20 | m | 156.5             │    │   │
│  │  │ ☐ HE-ELV-NET | Switch PoE 24P | cái | 3         │    │   │
│  │  │ ☑ HE-ELV-CCTV | Camera Dome 4MP | cái | 12       │    │   │
│  │  │ ...                                                │    │   │
│  │  └──────────────────────────────────────────────────┘    │   │
│  │  [Chon Tat Ca] [Bo Chon] [Chon Theo He] [Chon Theo Loai]│   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ BƯỚC 2: XUẤT ─────────────────────────────────────────┐   │
│  │                                                         │   │
│  │  [ XUẤT CAC MUC DA CHỌN ]  [ XUẤT TOÀN BỘ ]          │   │
│  │                                                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ LOG ───────────────────────────────────────────────────┐   │
│  │  [INFO] 10:23:45 - Bat dau quet...                      │   │
│  │  [INFO] 10:23:46 - Quet 1250 doi tuong...               │   │
│  │  [WARN] 10:23:47 - 12 doi tuong khong phan loai         │   │
│  └──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│  Lenh: MTO | MTOBANG | MTOZOOM [handle]           [Tro giup]   │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Rule Editor Dialog

```
┌─ RULE EDITOR ─────────────────────────────────────────────────┐
│  Bo quy tac: rules.sample.json                    [Luu] [Huy]  │
├────────────────────────────────────────────────────────────────┤
│  [+ Them Rule]  [Nhap tu JSON]  [Xuat JSON]  [Kiem tra]       │
│                                                                 │
│  ┌─ FILTER ─────────────────────────────────────────────────┐  │
│  │ Tim kiem: [________________]  He thong: [Tat ca ▼]       │  │
│  │ Loai: [Tat ca ▼]  Trang thai: [Active ▼]               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─ RULE LIST ─────────────────────────────────────────────┐  │
│  │ ☐ R-DIEN-001  | Ong luon dien...      | Active | P:100  │  │
│  │ ☑ R-DIEN-002  | Den LED downlight...   | Active | P:100  │  │
│  │ ☐ R-NUOC-001  | Ong nuoc PPR...        | Active | P:100  │  │
│  │ ☑ R-ELV-NET-001 | Switch PoE...       | Active | P:100  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─ EDIT RULE ─────────────────────────────────────────────┐  │
│  │ Ma quy tac: [R-DIEN-002       ]  Version: [1.0        ]  │  │
│  │ He thong: [HE-DIEN           ▼]                          │  │
│  │ Ma vat tu: [VL-DIEN-101      ]                          │  │
│  │ Ten vat tu: [Den LED downlight 10W                      ]  │  │
│  │ Quy cach: [10W, 4000K, 900lm                            ]  │  │
│  │ Don vi: [cái ▼]                                         │  │
│  │                                                             │  │
│  │ LOAI DOI TUONG:  ● Block  ● Geometry  ○ Any               │  │
│  │                                                             │  │
│  │ Layers: [EL-LIGHT-DL-*]  (semicolon, wildcard *)         │  │
│  │ Block names: [EL-LIGHT-DL-10W*]                          │  │
│  │ Attributes: [WATTAGE=10*]                                 │  │
│  │                                                             │  │
│  │ Cach tinh: [Count              ▼]                          │  │
│  │ He so (factor): [1.0]   Buoc lam tron: [0.0]             │  │
│  │ Thuoc tinh tinh tong: [____________]                      │  │
│  │                                                             │  │
│  │ Do uu tien: [100]  ○ Active  ○ Draft  ○ Paused          │  │
│  │                                                             │  │
│  │ [Kiem tra rule nay] → Xem truoc ket qua                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### 7.3 Batch Processing Dialog

```
┌─ BATCH PROCESSING ────────────────────────────────────────────┐
│                                                              │
│  ┌─ FILE LIST ────────────────────────────────────────────┐  │
│  │  [+ Them File]  [+ Them Thu muc]  [Xoa]  [Xoa Tat Ca]  │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │ ☑ C:\Projects\ABC\Dien.dwg              | 2.3MB  │   │  │
│  │  │ ☑ C:\Projects\ABC\Nuoc.dwg             | 1.8MB  │   │  │
│  │  │ ☐ C:\Projects\ABC\PCCC.dwg              | 0.9MB  │   │  │
│  │  │ ☑ C:\Projects\ABC\ELV.dwg              | 3.1MB  │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ CẤU HÌNH CHUNG ───────────────────────────────────────┐  │
│  │  Bo quy tac: [rules.sample.json          ] [Browse...] │  │
│  │  Don vi xuat: [m ▼]                                     │  │
│  │  Output folder: [C:\MTO_Export\          ] [Browse...]  │  │
│  │  Ten file: [MTO_Batch_[DATE]_[TIME]]                   │  │
│  │                                                             │  │
│  │  ☐ Tao 1 file Excel tong hop (gop ket qua)               │  │
│  │  ☐ Tao nhieu file Excel (moi DWG 1 file)                 │  │
│  │  ☐ Tao thu muc cho moi DWG (file + assets)             │  │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─ TIEN DO ───────────────────────────────────────────────┐  │
│  │  [████████████░░░░░░░░░] 12/25 files (48%)             │  │
│  │  File hien tai: ELV.dwg                                  │  │
│  │  Thoi gian con lai: ~2 phut                             │  │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│              [ Bat Dau ]    [ Dung ]    [ Dong ]             │
└──────────────────────────────────────────────────────────────┘
```

### 7.4 MTOBANG - Bảng Tổng Hợp Trên Bản Vẽ

```
┌─────────────────────────────────────────────────────────┐
│  MTOBANG - Tao Bang Tong Hop Tren Ban Ve Moi           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Ten bang: [Bang Khoi Luong Tong Hop          ]       │
│  Vi tri:   [Pick point tren ban ve...]    [OK]        │
│                                                         │
│  Noi dung:  ● Tat ca he thong  ○ Chi he thong:        │
│             [HE-DIEN ▼]                                │
│                                                         │
│  Cot hien thi: ☑ Ten vat tu   ☑ Don vi   ☑ Khoi luong │
│              ☑ Ma vat tu    ☐ Quy cach   ☐ Ghi chu    │
│                                                         │
│  ☐ Chen logo cong ty        ☐ Chen ngay thang          │
│                                                         │
│                    [ OK ]    [ Cancel ]                 │
└─────────────────────────────────────────────────────────┘
```

---

## 8. Lệnh AutoCAD / LISP

### 8.1 Danh Sách Lệnh

| Lệnh | Class | Mô tả |
|------|-------|-------|
| `MTO` | `MTOCommands` | Mở panel chính |
| `MTOZOOM` | `MTOCommands` | Zoom tới đối tượng theo handle |
| `MTOBANG` | `MtoBangCommand` | Tạo bảng tổng hợp trên DWG mới |
| `MTOSCAN` | `MTOScanCommand` | Quét không mở panel (batch-friendly) |
| `MTOEXPORT` | `MTOExportCommand` | Xuất Excel không mở panel |
| `MTORULES` | `MTORulesCommand` | Mở rule editor dialog |
| `MTOBATCH` | `MTOBatchCommand` | Mở batch processing dialog |
| `MTOSTATUS` | `MTOStatusCommand` | Hiện trạng thái plugin |

### 8.2 AutoLISP Wrapper Functions

```lisp
; MTO - Mo panel
(defun c:MTO ()
  (command "._NETLOAD" "MTOPlugin.dll")
  (command "MTO")
)

; MTOSCAN - Quet khong mo panel
(defun c:MTOSCAN (fn)
  (command "._NETLOAD" "MTOPlugin.dll")
  (command "MTOSCAN" fn)
)

; MTOEXPORT - Xuat Excel
(defun c:MTOEXPORT (rules outfile)
  (command "._NETLOAD" "MTOPlugin.dll")
  (command "MTOEXPORT" rules outfile)
)

; MTOBANG - Tao bang tong hop
(defun c:MTOBANG ()
  (command "._NETLOAD" "MTOPlugin.dll")
  (command "MTOBANG")
)
```

### 8.3 MTOZOOM Usage

```
Command: MTOZOOM <handle>
Example: MTOZOOM 1A3B2C4D

→ Zoom to object with Handle = 1A3B2C4D
→ Object is selected and zoomed to fit viewport
→ If object not found: "Object not found in current drawing"
```

---

## 9. Cấu Trúc Dữ Liệu & Models

### 9.1 Core Models (MTOPlugin.Core)

```
Models/
├── Enums.cs
│   ├── ScanScope           (SelectionSet, Model, LayoutCurrent, LayoutAll, ModelPlusCurrent, ModelPlusAll)
│   ├── XrefMode           (Ignore, UniqueBySource, PerInsertion)
│   ├── SpaceKind          (Model, Paper)
│   ├── GeometryKind        (Line, Polyline, Polyline2D, Polyline3D, Arc, Circle)
│   ├── EntityKind         (Block, Geometry, Any)
│   ├── CalculationKind    (Count, SumLength, SumLengthTimesFactor, SumLengthCeilingStep, SumAttributeValue, CountIfAttributeEquals)
│   ├── RuleStatus         (Active, Draft, Paused)
│   ├── WarningSeverity    (Info, Warning, Error)
│   └── UnitType           (mm, cm, m, ft, in)
│
├── ScanOptions.cs
│   ├── Scope              (ScanScope)
│   ├── XrefMode           (XrefMode)
│   ├── RuleSetPath        (string)
│   ├── SourceUnit         (DwgUnit)
│   ├── TargetUnit         (UnitType)
│   ├── OutputPath         (string)
│   ├── SelectionSet       (ObjectId[] - vùng chọn)
│   └── CancellationToken  (CancellationToken)
│
├── ScanWarning.cs
│   ├── Code               (string)
│   ├── Severity           (WarningSeverity)
│   ├── Message            (string)
│   ├── File               (string)
│   ├── Layout             (string)
│   ├── Layer              (string)
│   ├── Handle             (string)
│   └── SuggestedAction    (string)
│
├── ScanResult.cs
│   ├── Options            (ScanOptions)
│   ├── Blocks             (List<BlockReferenceInfo>)
│   ├── Geometries        (List<GeometryInfo>)
│   ├── Layers            (Dictionary<string, LayerStat>)
│   ├── Warnings          (List<ScanWarning>)
│   ├── Xrefs             (List<XrefReference>)
│   ├── TotalScanned      (int)
│   ├── DurationMs        (long)
│   └── ScanTime          (DateTime)
│
├── BlockReferenceInfo.cs
│   ├── BlockName          (string)
│   ├── EffectiveName      (string)  // Dynamic block active name
│   ├── IsDynamic         (bool)
│   ├── DynamicProperties  (Dictionary<string, object>)
│   ├── IsXref            (bool)
│   ├── XrefBlockName     (string)
│   ├── Layer             (string)
│   ├── ColorIndex        (short)
│   ├── Linetype          (string)
│   ├── ScaleX/Y/Z        (double)
│   ├── Rotation          (double)
│   ├── Position          (Point3d)
│   ├── Attributes        (Dictionary<string, string>)
│   ├── Identity          (ObjectIdentity)
│   └── RawLength         (double)   // For blocks that have length (cable tray, etc.)
│
├── GeometryInfo.cs
│   ├── Kind              (GeometryKind)
│   ├── Layer             (string)
│   ├── ColorIndex        (short)
│   ├── Linetype          (string)
│   ├── StartPoint        (Point3d)
│   ├── EndPoint          (Point3d)
│   ├── Length            (double)
│   ├── IsClosed          (bool)
│   ├── SegmentCount      (int)      // For polylines
│   ├── ArcRadius         (double)   // For arcs
│   ├── ArcAngle          (double)   // For arcs
│   ├── ArcLength         (double)   // For arcs
│   ├── CircleRadius      (double)   // For circles
│   └── Identity          (ObjectIdentity)
│
├── ObjectIdentity.cs
│   ├── Handle            (string)
│   ├── SourceFile        (string)
│   ├── Layout            (string)
│   ├── Space             (SpaceKind)
│   ├── IsFromXref        (bool)
│   ├── XrefBlockName     (string)
│   └── OwnerLayoutName   (string)
│
├── XrefReference.cs
│   ├── Name              (string)
│   ├── Path              (string)
│   ├── Status            (XrefStatus)
│   └── BlockTableRecordId(ObjectId)
│
├── LayoutInfo.cs
│   ├── Name              (string)
│   ├── BlockTableRecordId(ObjectId)
│   ├── IsModelSpace      (bool)
│   └── EntityCount       (int)
│
├── LayerStat.cs
│   ├── Name              (string)
│   ├── ObjectCount       (int)
│   ├── BlockCount        (int)
│   └── GeometryCount     (int)
│
├── DwgUnit.cs
│   ├── InsunitsValue     (short)
│   └── UnitName          (string)
```

### 9.2 Rule Models

```
Rules/
├── RuleDefinition.cs
│   ├── Code              (string)
│   ├── Version           (string)
│   ├── Description       (string)
│   ├── SystemCode        (string)
│   ├── MaterialCode      (string)
│   ├── MaterialName      (string)
│   ├── Specification     (string)
│   ├── Unit              (string)
│   ├── Calculation       (CalculationKind)
│   ├── Factor            (double)
│   ├── CeilingStep      (double)
│   ├── SumAttribute     (string)
│   ├── AttributeCondition(AttributeCondition)
│   ├── Conditions        (RuleCondition)
│   ├── Priority          (int)
│   ├── Status            (RuleStatus)
│   ├── ApprovedBy        (string)
│   ├── ApprovedAt        (DateTime?)
│   └── Notes             (string)
│
├── RuleCondition.cs
│   ├── EntityKind        (EntityKind)
│   ├── Layers            (string)   // semicolon-separated, wildcard
│   ├── LayerRegex        (string)
│   ├── BlockNames        (string)   // semicolon-separated, wildcard
│   ├── BlockNameRegex    (string)
│   ├── EffectiveBlockNames(string)
│   ├── Attributes        (string)   // KEY=VALUE; semicolon
│   ├── GeometryKinds     (string)   // semicolon-separated
│   ├── Linetypes         (string)
│   ├── ColorIndexes      (string)
│   ├── RequireDynamicBlock(bool)
│   └── DynamicProperty   (DynamicPropertyCondition)
│
├── DynamicPropertyCondition.cs
│   ├── PropertyName      (string)
│   ├── Operator          (string)
│   └── Value             (string)
│
├── AttributeCondition.cs
│   ├── Attribute         (string)
│   ├── Operator          (string)
│   ├── Value             (string)
│   └── Action            (string)
│
├── RuleSet.cs
│   ├── Name              (string)
│   ├── Version           (string)
│   ├── Description       (string)
│   ├── CreatedBy         (string)
│   ├── LastModified      (DateTime)
│   ├── Systems           (List<SystemDefinition>)
│   └── Rules             (List<RuleDefinition>)
│
└── RuleMatcher.cs
    ├── Match(rule, entity) → bool
    ├── MatchWildcard(pattern, name) → bool
    └── MatchRegex(pattern, name) → bool
```

### 9.3 Classification Models

```
Classification/
├── ClassificationEngine.cs
│   ├── Classify(scanResult, ruleSet) → ClassificationResult
│   └── ApplyRules(scanResult, rules) → void
│
├── ClassificationModels.cs
│   ├── ClassificationResult
│   │   ├── Summary        (List<SummaryRow>)
│   │   ├── Details        (List<ClassifiedDetail>)
│   │   ├── Unclassified   (List<UnclassifiedItem>)
│   │   ├── ClassificationRate (double)
│   │   └── DurationMs     (long)
│   │
│   ├── SummaryRow
│   │   ├── SystemCode     (string)
│   │   ├── SystemName     (string)
│   │   ├── MaterialCode   (string)
│   │   ├── MaterialName   (string)
│   │   ├── Specification  (string)
│   │   ├── Unit           (string)
│   │   ├── Quantity       (double)
│   │   ├── ObjectCount    (int)
│   │   ├── RuleCode       (string)
│   │   └── Status         (string)
│   │
│   ├── ClassifiedDetail
│   │   ├── RuleCode       (string)
│   │   ├── ObjectIdentity (ObjectIdentity)
│   │   ├── RawValue       (double)
│   │   ├── ConvertedValue (double)
│   │   ├── TargetUnit     (string)
│   │   └── IsSelected     (bool)  // For "export selected" feature
│   │
│   └── UnclassifiedItem
│       ├── ObjectIdentity (ObjectIdentity)
│       ├── ObjectType     (string)
│       ├── Reason         (string)
│       └── SuggestedRules (List<string>)
```

### 9.4 Export Models

```
Export/
├── ExcelExporter.cs
│   ├── ExportAll(result, outputPath) → void
│   ├── ExportSelected(result, selectedItems, outputPath) → void
│   ├── ExportBatch(results, outputFolder, options) → void
│   └── ExportTemplate(template, result, outputPath) → void
│
└── ExcelStyles.cs
    ├── HeaderStyle
    ├── DataStyle
    ├── NumberStyle
    ├── DateStyle
    └── BorderStyle
```

---

## 10. Kế Hoạch Triển Khai Theo Giai Đoạn

### Phase 1: Nền Tảng Cốt Lõi (Tuần 1-2)

**Mục tiêu:** Hoàn thiện core engine và UI cơ bản

| Task | Mô tả | Estimate |
|------|-------|----------|
| P1.1 | Nâng cấp Rule Engine: thêm CalculationKind mới, attribute extraction | 2 days |
| P1.2 | Thêm Rule Editor UI trong WPF panel | 3 days |
| P1.3 | Thêm dynamic block property reader (DynamicBlockReader) | 2 days |
| P1.4 | Thêm LISP wrapper functions (defun MTO, MTOSCAN, MTOEXPORT) | 1 day |
| P1.5 | Thêm giao diện chọn vùng quét nâng cao (FR01+) | 1 day |
| P1.6 | Thêm Unit Converter nâng cao (thêm các đơn vị Imperial) | 1 day |
| P1.7 | Viết unit test cho Core engine | 2 days |
| P1.8 | Code review và refactor | 1 day |

**Deliverables:**
- Rule Editor hoàn chỉnh trong panel
- Dynamic block property extraction
- LISP functions cho batch mode
- Unit tests: 50+ test cases

---

### Phase 2: Hệ Thống Điện + Nước (Tuần 3-4)

**Mục tiêu:** Đủ dùng cho công việc điện nước cơ bản

| Task | Mô tả | Estimate |
|------|-------|----------|
| P2.1 | Chuẩn hóa rules mẫu cho hệ điện (chiếu sáng, ổ cắm, tủ điện, dây/cáp, ống luồn, khay cáp) | 2 days |
| P2.2 | Chuẩn hóa rules mẫu cho hệ nước (cấp nước, thoát nước, thiết bị vệ sinh, van) | 2 days |
| P2.3 | Thêm attribute extraction cho block điện (WATTAGE, RATING, MODEL...) | 2 days |
| P2.4 | Thêm attribute extraction cho block nước (SIZE, TYPE...) | 1 day |
| P2.5 | Thêm SumLengthTimesFactor cho cáp điện nhiều lõi | 1 day |
| P2.6 | Thêm angle detection cho phụ kiện ống nước (co 45°/90°) | 2 days |
| P2.7 | Tạo sample DWG test cho điện nước | 1 day |
| P2.8 | Kiểm thử với bộ DWG thực tế | 2 days |

**Deliverables:**
- 50+ rules mẫu cho điện nước
- Sample rules.json chuẩn hóa
- Test DWG files
- Documentation: "Quick Start Guide - Dien Nuoc"

---

### Phase 3: Hệ Thống Điện Nhẹ - Lan Mang (Tuần 5-6)

**Mục tiêu:** Đủ cho hạ tầng mạng và server room

| Task | Mô tả | Estimate |
|------|-------|----------|
| P3.1 | Chuẩn hóa rules cho mạng LAN (switch, router, firewall, AP) | 1 day |
| P3.2 | Chuẩn hóa rules cho Data Center (server, UPS, rack, PDU) | 2 days |
| P3.3 | Chuẩn hóa rules cho cáp mạng (Cat6, Cat6A, fiber) | 1 day |
| P3.4 | Thêm Patch Panel port counting (24 port → 24 cái) | 2 days |
| P3.5 | Thêm ODF fiber counting (12 port → 12 sợi) | 1 day |
| P3.6 | Thêm nhân hệ số cho patch cord (1 sợi = 1 cái) | 1 day |
| P3.7 | Tạo module DataCenter specialized (server room features) | 3 days |
| P3.8 | Kiểm thử với bộ DWG Data Center thực tế | 2 days |

**Deliverables:**
- 30+ rules cho mạng và data center
- DataCenter module với specialized features
- Documentation: "Quick Start Guide - Mang & Data Center"

---

### Phase 4: ELV Hoàn Chỉnh (Tuần 7-8)

**Mục tiêu:** Phủ đầy các hệ ELV còn lại

| Task | Mô tả | Estimate |
|------|-------|----------|
| P4.1 | Chuẩn hóa rules cho CCTV (camera, NVR, monitor) | 1 day |
| P4.2 | Chuẩn hóa rules cho Access Control (controller, reader, lock) | 1 day |
| P4.3 | Chuẩn hóa rules cho Fire Alarm (smoke, heat, MCP, siren) | 1 day |
| P4.4 | Chuẩn hóa rules cho PA (speaker, amplifier, mic) | 1 day |
| P4.5 | Chuẩn hóa rules cho IPTV/Intercom | 1 day |
| P4.6 | Chuẩn hóa rules cho BMS (controller, sensor, VFD) | 1 day |
| P4.7 | Thêm Auto-naming convention checker (cảnh báo layer/block không chuẩn) | 2 days |
| P4.8 | Thêm "Suggested Rules" engine (AI-like suggestion for unclassified) | 3 days |
| P4.9 | Kiểm thử toàn diện tất cả hệ ELV | 2 days |

**Deliverables:**
- 60+ rules cho toàn bộ ELV
- Naming convention checker
- Rule suggestion engine
- Documentation: "Quick Start Guide - Dien Nhe (ELV)"

---

### Phase 5: Batch Processing & Reporting (Tuần 9-10)

**Mục tiêu:** Xử lý batch và xuất báo cáo nâng cao

| Task | Mô tả | Estimate |
|------|-------|----------|
| P5.1 | Thêm Batch Processing UI (multi-file selection) | 3 days |
| P5.2 | Thêm Batch Engine (xử lý nhiều DWG song song) | 3 days |
| P5.3 | Thêm Merged Excel output (gộp nhiều DWG vào 1 file) | 2 days |
| P5.4 | Thêm CSV export | 1 day |
| P5.5 | Thêm PDF report (summary + charts) | 3 days |
| P5.6 | Thêm comparison mode (so sánh 2 bản vẽ revision) | 3 days |
| P5.7 | Thêm wastage factor (%) cho mỗi rule | 1 day |
| P5.8 | Thêm labor hours estimation | 2 days |
| P5.9 | Stress test với 50+ DWG files | 1 day |
| P5.10 | Performance optimization (cache, parallel processing) | 2 days |

**Deliverables:**
- Batch Processing feature hoàn chỉnh
- CSV export
- PDF report với charts
- Comparison tool
- Performance optimization

---

### Phase 6: Integration & Polish (Tuần 11-12)

**Mục tiêu:** Hoàn thiện và tích hợp hệ thống

| Task | Mô tả | Estimate |
|------|-------|----------|
| P6.1 | Thêm Undo support (sau khi export) | 2 days |
| P6.2 | Thêm Rule versioning (git-like history) | 2 days |
| P6.3 | Thêm Rule import/export (share between projects) | 1 day |
| P6.4 | Thêm Auto-update rules from cloud/shared folder | 2 days |
| P6.5 | Thêm Configuration profiles (dev/staging/prod) | 1 day |
| P6.6 | Thêm dark mode cho UI | 1 day |
| P6.7 | Localization (Vietnamese + English UI) | 2 days |
| P6.8 | Comprehensive documentation (PDF + HTML) | 3 days |
| P6.9 | Security audit (validate JSON, sanitize paths) | 1 day |
| P6.10 | Final integration testing | 2 days |

**Deliverables:**
- Production-ready v1.0.0
- Complete documentation
- Security hardened
- Localization support

---

### Tổng Kết Timeline

| Phase | Mô tả | Duration | Week |
|-------|-------|----------|------|
| 0 | Hiện tại (base code) | - | Tuần 0 |
| 1 | Nền tảng Cốt Lõi | 2 weeks | Tuần 1-2 |
| 2 | Điện + Nước | 2 weeks | Tuần 3-4 |
| 3 | ELV - Mạng & Data Center | 2 weeks | Tuần 5-6 |
| 4 | ELV Hoàn Chỉnh | 2 weeks | Tuần 7-8 |
| 5 | Batch & Reporting | 2 weeks | Tuần 9-10 |
| 6 | Integration & Polish | 2 weeks | Tuần 11-12 |
| **Total** | | **12 weeks** | |

---

## 11. Tiêu Chuẩn Kỹ Thuật

### 11.1 Quy Tắc Viết Code

| Tiêu chí | Quy định |
|----------|----------|
| Ngôn ngữ | C# 10+, .NET 6/8 |
| Convention | C# Coding Conventions (Microsoft) |
| Namespace | `MTOPro.{Module}.{SubModule}` |
| Class naming | PascalCase: `ExcelExporter`, `RuleMatcher` |
| Method naming | PascalCase: `ExportAll()`, `Classify()` |
| Private field | `_camelCase` hoặc `camelCase` |
| Constant | `UPPER_SNAKE_CASE` |
| Interface | `I` prefix: `IExporter`, `IMatcher` |
| File naming | Same as class: `ExcelExporter.cs` |
| Brace style | Allman (newline before brace) |
| Indent | 4 spaces (no tabs) |
| Max line length | 120 characters |
| Usings | Alphabetical, `System.` first, then third-party |

### 11.2 Git Convention

| Loại commit | Prefix | Ví dụ |
|------------|--------|-------|
| Feature | `feat:` | `feat: add batch processing UI` |
| Bug fix | `fix:` | `fix: handle null attribute in rule matcher` |
| Refactor | `refactor:` | `refactor: extract unit converter to separate class` |
| Docs | `docs:` | `docs: update README with new commands` |
| Test | `test:` | `test: add cases for SumLengthTimesFactor` |
| Build | `build:` | `build: update to .NET 8` |
| Perf | `perf:` | `perf: optimize scanning 10k entities` |

### 11.3 Naming Convention Blocks/Layers (Chuẩn Công Ty)

```
// ELECTRICAL
EL-COND-{TYPE}-{SIZE}      // Conduit: EL-COND-WALL-DN20
EL-CAB-{CORES}-{SIZE}      // Cable: EL-CAB-3C-2.5mm2
EL-TRAY-{TYPE}-{SIZE}      // Tray: EL-TRAY-J-100x50
EL-LIGHT-{TYPE}-{WATT}     // Light: EL-LIGHT-DL-10W
EL-OUT-{TYPE}-{RATING}     // Outlet: EL-OUT-2P-16A
EL-PNL-{TYPE}-{RATING}     // Panel: EL-PNL-MDB-400A

// PLUMBING
PLB-PIPE-{MATERIAL}-{SIZE} // Pipe: PLB-PIPE-PPR-DN25
PLB-DRAIN-{MATERIAL}-{SIZE}// Drain: PLB-DRAIN-PVC-DN50
PLB-FIX-{TYPE}-{BRAND}     // Fixture: PLB-FIX-WC-TOTO
PLB-VALVE-{TYPE}-{SIZE}    // Valve: PLB-VALVE-BALL-DN25
PLB-FIT-{TYPE}-{SIZE}      // Fitting: PLB-FIT-ELB90-DN25

// ELV
ELV-NET-{TYPE}-{PORTS}     // Network: ELV-NET-POE-24P
ELV-CAM-{TYPE}-{RES}       // Camera: ELV-CAM-DOME-4MP
ELV-ACC-{TYPE}-{SPEC}      // Access: ELV-ACC-RDR-RFID
ELV-FA-{TYPE}-{SPEC}       // Fire Alarm: ELV-FA-SMOKE-ADDR
ELV-PA-{TYPE}-{WATT}       // PA: ELV-PA-SPK-CL-6W
ELV-DC-{TYPE}-{SIZE}       // Data Center: ELV-DC-RACK-42U
```

### 11.4 Performance Requirements

| Metric | Target |
|--------|--------|
| Scan 1000 entities | < 2 seconds |
| Scan 10000 entities | < 15 seconds |
| Scan 100000 entities | < 120 seconds |
| Excel export 5000 rows | < 5 seconds |
| Memory usage (100k entities) | < 500 MB |
| Startup time (AutoCAD load) | < 3 seconds |

---

## 12. Công Nghệ & Tools

### 12.1 Development Stack

| Component | Technology | Version |
|-----------|------------|---------|
| Language | C# | 12 |
| Runtime | .NET | 8.0 |
| AutoCAD API | Autodesk.AutoCAD.Runtime | 2025 (net8) |
| CAD Binding | AutoCAD .NET API | 2025 |
| UI Framework | WPF | .NET 8 |
| Testing | NUnit | 3.x |
| Excel Library | EPPlus | 7.x |
| JSON | System.Text.Json | Built-in |
| Logging | Serilog | 3.x |
| DI Container | Microsoft.Extensions.DependencyInjection | 8.x |
| Build | dotnet CLI / MSBuild | 8.0 |
| Installer | Inno Setup | 6.x |

### 12.2 External Dependencies

| Package | Purpose | License |
|---------|---------|---------|
| EPPlus | Excel export | Polyform Noncommercial |
| Serilog | Logging | Apache 2.0 |
| Newtonsoft.Json | JSON (backup) | MIT |
| Microsoft.Extensions.DependencyInjection | DI | MIT |
| NUnit + NUnit3TestAdapter | Unit testing | NUnit |

### 12.3 Recommended IDE Setup

- **Visual Studio 2022** với:
  - ReSharper (hoặc JetBrains Rider)
  - VS Extensions:
    - "Productivity Power Tools"
    - "EditorConfig"
  - Autodesk AutoCAD .NET Wizard

- **JetBrains Rider** (alternative):
  - Built-in C# 12 support
  - Built-in Unity support (not needed but good)

### 12.4 Build Commands

```powershell
# Development
dotnet build MTOPro.sln -c Debug

# Release
dotnet build MTOPro.sln -c Release

# Test
dotnet test MTOPro.sln -c Debug

# Deploy bundle (AutoCAD 2025)
.\scripts\deploy-bundle.ps1 -AcadVersion 2025 -Config Release

# Build installer
.\scripts\build-installer.ps1

# Clean
dotnet clean MTOPro.sln && Remove-Item -Recurse -Force src/*/bin, src/*/obj
```

---

## 13. Testing & Quality Assurance

### 13.1 Test Categories

| Level | Scope | Tools |
|-------|-------|-------|
| Unit Test | Core logic (RuleMatcher, ClassificationEngine, UnitConverter) | NUnit |
| Integration Test | Scanner → Core flow | NUnit + Mock AutoCAD |
| System Test | Full workflow in AutoCAD | Manual + Scripted |
| Performance Test | Large DWG (100k entities) | dotnet benchmark |
| Regression Test | Compare before/after changes | Auto-regression scripts |

### 13.2 Test Coverage Targets

| Module | Target Coverage |
|--------|----------------|
| RuleMatcher | >90% |
| ClassificationEngine | >90% |
| UnitConverter | >95% |
| ExcelExporter | >80% |
| Overall | >75% |

### 13.3 Test Cases Mẫu

```csharp
// RuleMatcherTests.cs
[Test]
public void MatchWildcard_SingleAsterisk_MatchesCorrectly()
{
    var matcher = new RuleMatcher();
    Assert.IsTrue(matcher.MatchWildcard("EL-LIGHT-*", "EL-LIGHT-DL-10W"));
    Assert.IsTrue(matcher.MatchWildcard("EL-LIGHT-*", "EL-LIGHT-PNL-20W"));
    Assert.IsFalse(matcher.MatchWildcard("EL-LIGHT-*", "EL-OUT-2P-16A"));
}

[Test]
public void MatchLayer_WithSemicolonOr_MatchesMultiple()
{
    var matcher = new RuleMatcher();
    Assert.IsTrue(matcher.MatchWildcard("EL-COND-WALL-*;EL-COND-SLAB-*", "EL-COND-WALL-DN20"));
    Assert.IsTrue(matcher.MatchWildcard("EL-COND-WALL-*;EL-COND-SLAB-*", "EL-COND-SLAB-DN25"));
}

// ClassificationEngineTests.cs
[Test]
public void Classify_WithSumLengthTimesFactor_CalculatesCorrectly()
{
    var result = new ScanResult();
    result.Geometries.Add(new GeometryInfo {
        Kind = GeometryKind.Polyline,
        Layer = "EL-CAB-3C-2.5mm2",
        Length = 100.0
    });
    
    var rule = CreateRule(CalculationKind.SumLengthTimesFactor, factor: 3.0);
    
    var classified = engine.Classify(result, ruleSet);
    
    Assert.AreEqual(300.0, classified.Summary[0].Quantity); // 100 * 3
}

// ExcelExporterTests.cs
[Test]
public void Export_WithSelectedItems_OnlyExportsSelected()
{
    var result = CreateClassificationResult();
    result.Details[0].IsSelected = false;
    result.Details[1].IsSelected = true;
    
    exporter.ExportSelected(result, selectedItems, outputPath);
    
    // Verify only selected items in Excel
}
```

---

## 14. Biểu Mẫu & Template

### 14.1 Sample rules.sample.json Structure

```json
{
  "name": "MTOPro Rules - Cong Ty [Ten]",
  "version": "1.0.0",
  "description": "Bo quy tac chuan cho he thong dien, nuoc, dien nhe",
  "createdBy": "Phong Du An",
  "lastModified": "2026-09-16T00:00:00",
  "systems": [
    { "code": "HE-DIEN", "name": "He thong dien", "unit": "" },
    { "code": "HE-NUOC", "name": "He thong nuoc", "unit": "" },
    { "code": "HE-ELV-NET", "name": "Mang may tinh", "unit": "" },
    { "code": "HE-ELV-CCTV", "name": "Camera giam sat", "unit": "" },
    { "code": "HE-ELV-ACC", "name": "Kiem soat ra vao", "unit": "" },
    { "code": "HE-ELV-FA", "name": "Bao chay", "unit": "" },
    { "code": "HE-ELV-PA", "name": "Am thanh thong bao", "unit": "" },
    { "code": "HE-ELV-DC", "name": "Phong may chu", "unit": "" }
  ],
  "rules": []
}
```

### 14.2 Block Library Template (Excel)

```
BlockName,Description,System,Unit,Attributes,Layer,Size,Wattage,Model
EL-LIGHT-DL-10W-40K,Den LED downlight 10W 4000K,HE-DIEN,cái,WATTAGE=10;COLOR_TEMP=4000,EL-LIGHT-DL-*,,
EL-LIGHT-DL-7W-40K,Den LED downlight 7W 4000K,HE-DIEN,cái,WATTAGE=7;COLOR_TEMP=4000,EL-LIGHT-DL-*,,
EL-OUT-2P-16A-IP44,O cam 2 phich 16A IP44,HE-DIEN,cái,RATING=16A;TYPE=2P;IP=44,EL-OUT-*,,,16A
ELV-NET-POE-24P,Switch PoE 24 port,HE-ELV-NET,cái,PORTS=24;POE_PORTS=24,ELV-NET-POE-*,,,24
ELV-CAM-DOME-4MP,Camera dome 4MP,HE-ELV-CCTV,cái,RESOLUTION=4MP;IP=67,ELV-CAM-DOME-*,,4MP,
```

---

## 15. Rủi Ro & Mitigation

| ID | Rủi ro | Mức độ | Mitigation |
|----|--------|--------|------------|
| R1 | Block/Layer naming không chuẩn trong bản vẽ thực tế | Cao | Thêm naming convention checker + suggestion engine |
| R2 | Performance chậm với DWG lớn (100k+ entities) | Trung bình | Parallel processing + caching + pagination |
| R3 | Không build được net48 (thiếu AutoCAD 2018-2024) | Cao | Máy build riêng hoặc CI/CD với nhiều AutoCAD versions |
| R4 | Rule conflicts (nhiều rule cùng khớp) | Trung bình | Priority system + clear conflict resolution |
| R5 | Memory leak khi quét nhiều file liên tiếp | Thấp | Proper disposal + GC hints |
| R6 | Excel file locked by other process | Thấp | Retry logic + user notification |
| R7 | JSON rule file corrupted | Thấp | Schema validation on load + backup file |
| R8 | User không quen với workflow 2 bước | Trung bình | Tooltip + quick start guide + video tutorial |

---

## Phụ Lục

### A. Glossary

| Thuật ngữ | Định nghĩa |
|-----------|------------|
| MTO | Material Take-Off - Bóc tách khối lượng |
| BOQ | Bill of Quantities - Bảng khối lượng |
| ELV | Extra Low Voltage - Điện nhẹ |
| QS | Quantity Surveyor - Cán bộ định lượng |
| DWG | Drawing file format của AutoCAD |
| Xref | External Reference - Bản vẽ tham chiếu ngoài |
| MEP | Mechanical, Electrical, Plumbing |
| FR | Functional Requirement |
| Rule | Quy tắc phân loại đối tượng |

### B. References

- Autodesk AutoCAD .NET API Documentation
- TCVN 6077:2012 - Ký hiệu quy ước trang thiết bị kỹ thuật
- TCVN 5738:2021 - Hệ thống báo cháy tự động
- TIA/EIA-568 - Structured Cabling Standard
- IEC 61140 - Classification of low voltages

### C. Liên Hệ & Hỗ Trợ

| Kênh | Thông tin |
|-------|-----------|
| Email | support@congty.com |
| Hotline | 090XXXXXXX |
| Documentation | docs/USER_GUIDE.md |
| Issue Tracker | GitHub Issues |

---

**Tài liệu này được tạo để chuyển giao cho DeepSeek cho việc tiếp tục phát triển dự án MTOPro. Vui lòng đọc kỹ Section 3 (Danh Mục Hệ Thống M&E) và Section 10 (Kế Hoạch Triển Khai) trước khi bắt đầu code.**
