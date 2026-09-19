# MÔ TẢ HỆ THỐNG — MTOPro (Bóc tách khối lượng M&E trên AutoCAD)

**Đề tài:** R&D-CAD-QTO-01 · **Phiên bản:** 1.0.0 · **Cập nhật:** 19/09/2026
**Môi trường xác thực:** AutoCAD 2023 (ACADVER 24.2), Windows 10/11 64-bit

---

## 1. Hệ thống này giải quyết vấn đề gì

Bóc tách khối lượng (quantity take-off) cho hệ **Điện – Nước – Điện nhẹ/ELV** hiện nay
làm **thủ công**: kỹ sư mở bản vẽ, đếm thiết bị, đo chiều dài cáp/ống, ghi ra Excel.
Cách này:

| Vấn đề | Hậu quả |
|---|---|
| Đếm tay hàng nghìn đối tượng | Sai sót, mất 2–5 ngày cho 1 bản vẽ lớn |
| Không có dấu vết (audit trail) | Không kiểm tra lại được con số |
| Mỗi người một cách ghi | Bảng khối lượng không nhất quán |
| Sửa bản vẽ → phải làm lại từ đầu | Tốn công gấp nhiều lần |

**MTOPro** tự động hoá: quét bản vẽ → nhận dạng theo bộ quy tắc → tính khối lượng
→ xuất bảng/Excel, có **dấu vết từng con số** (truy vết về đối tượng gốc).

---

## 2. Kiến trúc tổng thể

### 2.1 Nguyên tắc kiến trúc (đã chốt, không thay đổi)

```
LISP-first  →  LISP + AutoCAD Table  →  .NET chỉ khi thật cần
```

**Ưu tiên khi ra quyết định kỹ thuật:**

```
Độ tin cậy  →  Độ chính xác  →  Kiến trúc đơn giản  →  Dễ bảo trì  →  Mở rộng
```

**Hệ quả thiết kế:**

| Quyết định | Lý do |
|---|---|
| Logic nhận dạng/đếm/tính **nằm ở AutoLISP** | Chạy được cả trên AutoCAD cũ; test headless; không phụ thuộc build |
| `.NET` chỉ làm **UI panel + Rule Editor + xuất Excel** | Những việc LISP không làm tốt (giao diện, EPPlus) |
| **Không** chuyển logic sang .NET "cho tiện" | Tránh phụ thuộc phiên bản AutoCAD (.NET API đổi giữa các bản) |
| Dữ liệu trung tâm = **danh sách phẳng** association list | Đơn giản, dễ debug, dễ ghi/đọc file EDN-like |

### 2.2 Sơ đồ tầng

```
┌─────────────────────────────────────────────────────────────────────┐
│  NGƯỜI DÙNG (kỹ sư M&E)                                             │
│  Gõ lệnh MTO* trong AutoCAD  hoặc  mở panel .NET                    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
        ┌──────────────────────┴──────────────────────┐
        │                                             │
┌───────▼────────────────────────┐      ┌─────────────▼─────────────────┐
│  TẦNG 1 — AutoLISP (LÕI)       │      │  TẦNG 2 — .NET (GIAO DIỆN)     │
│  18 module · 27 lệnh           │      │  net48 cho AutoCAD 2023        │
│                                │      │                                │
│  • Chọn đối tượng (5 chế độ)   │      │  • MainPanel (WPF)             │
│  • Nhận dạng theo quy tắc      │      │  • RuleEditorWindow            │
│  • Tính khối lượng hình học    │      │  • Xuất Excel (EPPlus)         │
│  • Bảng khối lượng             │      │  • Quét song song / batch      │
│  • Xuất CSV                    │      │                                │
│  • Cập nhật hàng loạt + undo   │      │  ⚠️ KHÔNG chứa logic nghiệp vụ │
│  • Cấu hình theo bản vẽ        │      │                                │
│  • Tự động cập nhật            │      │                                │
└───────┬────────────────────────┘      └─────────────┬─────────────────┘
        │                                             │
        └──────────────────┬──────────────────────────┘
                           │
              ┌────────────▼─────────────┐
              │  DỮ LIỆU                 │
              │  • Bản vẽ DWG (nguồn)    │
              │  • rules.json (quy tắc)  │
              │  • DANH_MUC_VAT_TU.xlsx  │
              │  • .mtocfg (cấu hình)    │
              │  • NOD/XRecord trong DWG │
              │  • *MTO-DATA* (RAM)      │
              └──────────────────────────┘
```

---

## 3. Thành phần hệ thống

### 3.1 Mười tám module AutoLISP

| # | Module | Vai trò |
|---|---|---|
| 1 | `mto-ui.lsp` | Banner, tiến trình, tên lệnh trên thanh trạng thái (DIESEL) |
| 2 | `mto-core.lsp` | Tiện ích nền: chuỗi, số, danh sách, data model, ghi/đọc file |
| 3 | `mto-select.lsp` | Chọn đối tượng (5 chế độ) + lọc theo layer |
| 4 | `mto-text.lsp` | Nhận dạng tiền tố văn bản (46 tiền tố, 3 hệ) |
| 5 | `mto-block.lsp` | Đếm block/block động + điều chỉnh thủ công |
| 6 | `mto-geometry.lsp` | Khối lượng hình học (7 loại) + **phát hiện đơn vị** |
| 7 | `mto-result.lsp` | Danh sách kết quả (6 cột) |
| 8 | `mto-csv.lsp` | Xuất CSV (15 cột, chuẩn RFC4180) |
| 9 | `mto-orphan.lsp` | Phát hiện đối tượng mồ côi (không khớp quy tắc nào) |
| 10 | `mto-table.lsp` | Bảng khối lượng (9 cột) + 2 backend: NATIVE / GRID |
| 11 | `mto-find.lsp` | Tìm & zoom tới đối tượng gốc |
| 12 | `mto-update.lsp` | Cập nhật hàng loạt TEXT/MTEXT/XData |
| 13 | `mto-undo.lsp` | Snapshot & khôi phục (undo hệ thống) |
| 14 | `mto-formula.lsp` | Công thức tùy chỉnh (không dùng `eval`) |
| 15 | `mto-subtotal.lsp` | Tổng phụ & khấu trừ theo khoá |
| 16 | `mto-floor.lsp` | Tầng / khu vực / vùng |
| 17 | `mto-config.lsp` | Cấu hình theo bản vẽ (`.mtocfg` + NOD trong DWG) |
| 18 | `mto-selfup.lsp` | **Module cập nhật tự động** (kiểm tra/tải/kích hoạt/rollback) |

Module `mto-loader.lsp` là **bộ nạp** — tự đọc `version.json`, nạp 18 module theo thứ tự,
báo lỗi nếu thiếu file.

### 3.2 Hai mươi bảy lệnh

| Nhóm | Lệnh |
|---|---|
| **Chọn & quét** | `MTOSEL` |
| **Nhận dạng** | `MTOTEXT` · `MTOBLK` · `MTOBLKMAN` · `MTOGEO` |
| **Kết quả** | `MTOLIST` · `MTOCSV` · `MTOTABLE` · `MTOTESTNATIVE` |
| **Kiểm tra chất lượng** | `MTOORPHAN` · `MTOFIND` · `MTOGOTO` · `MTOXCHECK` |
| **Hiệu chỉnh** | `MTOUPDATE` · `MTOFORMULA` · `MTOSUB` · `MTODED` · `MTOFLOOR` |
| **Undo** | `MTOSNAP` · `MTOUNDO` · `MTOSNAPSHOW` |
| **Cấu hình** | `MTOCFG` |
| **Trợ giúp & giao diện** | `MTOHELP` · `MTOTITLE` |
| **Cập nhật** | `MTOVERSION` · `MTOUPGRADECHECK` · `MTOUPGRADE` |

### 3.3 Quy mô mã nguồn

| Hạng mục | Số lượng |
|---|---|
| Module AutoLISP | **18** (+ `mto-loader.lsp`) |
| Lệnh | **27** |
| Test file | **18** |
| Test tự động | **700/700 PASS** |
| Nhánh `.NET` | 4 project (`MTOPlugin`, `.Core`, `.UI`, `.Logging`) |

---

## 4. Luồng xử lý dữ liệu

```
① CHỌN          MTOSEL → 5 chế độ: tất cả / vùng chọn / layer / khung nhìn / xref
      │                    Kết quả: danh sách ename
      ▼
② NHẬN DẠNG      Với mỗi đối tượng, so với bộ quy tắc (rules.json):
      │            • TEXT/MTEXT → khớp tiền tố?  (VD "CABLE-" → cáp)
      │            • BLOCK      → khớp tên block/layer/thuộc tính?
      │            • Hình học   → khớp layer + loại?
      ▼
③ TÍNH KHỐI LƯỢNG
      │            • Đếm        → số lượng (block)
      │            • Hình học   → chiều dài / diện tích (vlax-curve)
      │            • Công thức  → LEN * 1.05 (hệ số hao hụt)
      │            • Đơn vị     → theo INSUNITS + phát hiện sai đơn vị
      ▼
④ LƯU TRỮ        *MTO-DATA* — danh sách phẳng các bản ghi:
      │            ((CODE . "ELV-CAM-DOME") (QTY . 51.0) (UNIT . "Bo")
      │             (LAYER . "SE.DOME CAMERA") (SRC . "e7a3f2") ...)
      ▼
⑤ TỔNG HỢP       MTOSUB (tổng phụ) · MTODED (khấu trừ) · MTOFLOOR (theo tầng)
      │            → QTY ròng = tổng − khấu trừ (không âm)
      ▼
⑥ XUẤT           MTOLIST (xem) · MTOCSV (Excel) · MTOTABLE (bảng trong DWG)
      │            Panel .NET → xuất Excel trực tiếp (EPPlus)
      ▼
⑦ TRUY VẾT       MTOFIND / MTOGOTO → zoom tới đối tượng gốc (theo HANDLE)
```

### 4.1 Data model

Một bản ghi là **association list** (danh sách cặp khoá–giá trị):

```lisp
(("CODE"     . "ELV-CAM-DOME")
 ("CATEGORY" . "Thiet bi")
 ("TYPE"     . "Camera")
 ("DESC"     . "Camera dome IP")
 ("QTY"      . 51.0)
 ("LENGTH"   . 0.0)
 ("UNIT"     . "Bo")
 ("LAYER"    . "SE.DOME CAMERA")
 ("NOTES"    . "")
 ("SRC"      . ("e7a3f2" "a1b2c3" ...)))   ; HANDLE các đối tượng gốc
```

**Vì sao dùng association list (không dùng class/struct)?**
- AutoLISP không có struct; alist là cách tự nhiên
- Thêm khoá không phá code cũ
- Ghi/đọc file trực tiếp (`(princ ...)` / `(read ...)`) — không cần parser

---

## 5. Bộ quy tắc (rule engine)

### 5.1 Quy tắc là gì

Một **quy tắc** = điều kiện nhận dạng + cách tính khối lượng + thông tin vật tư.

```json
{
  "code": "ELV-CAM-DOME",
  "description": "Camera dome IP",
  "systemCode": "ELV",
  "materialName": "Camera dome",
  "unit": "Bo",
  "conditions": [{
    "entityKind": "block",
    "blockNames": ["SE.DOME CAMERA", "cam"],
    "layerRegex": "^SE\\.",
    "attributes": []
  }],
  "calculation": "count",
  "factor": 1.0
}
```

### 5.2 Ba loại tính toán

| Loại | Ý nghĩa | Dùng cho |
|---|---|---|
| `count` | Đếm số lượng | Thiết bị, phụ kiện |
| `length` / `area` / `volume` | Đo hình học | Cáp, ống, máng |
| `formula` | Công thức tự viết | `LEN * 1.05` (hao hụt), `LEN + 2` (dự phòng) |

### 5.3 Nguồn quy tắc

| File | Vai trò |
|---|---|
| `config/rules.sample.json` | **Bộ mẫu** — 110 quy tắc / 11 hệ thống (có tên giữ chỗ như `ELV-CAM-DOME-*`) |
| `config/rules.json` | **Bộ thật** của công ty — sinh từ `DANH_MUC_VAT_TU.xlsx` |
| `DANH_MUC_VAT_TU.xlsx` | **Template Excel** — kỹ sư điền vật tư, script chuyển thành `rules.json` |

Lệnh chuyển đổi:
```powershell
.\scripts\import-materials.ps1            # Excel → rules.json
.\scripts\import-materials.ps1 -DryRun    # chỉ kiểm tra, không ghi
```

---

## 6. Cấu hình theo bản vẽ

Mỗi bản vẽ có thể có cấu hình riêng, lưu **2 nơi** (đã kiểm chứng):

| Cách | Vị trí | Ưu điểm | Nhược điểm |
|---|---|---|---|
| **File `.mtocfg`** | Cạnh file DWG | Dễ xem/sửa/chia sẻ | Phải giữ kèm DWG |
| **NOD / XRecord** | Trong chính file DWG | Đi cùng DWG, không thất lạc | Khó sửa tay |

Lệnh `MTOCFG` quản lý cả hai. Khi mở bản vẽ, hệ thống tự nạp cấu hình.

---

## 7. Hệ thống cập nhật (module bổ sung)

```
NGUỒN:  https://raw.githubusercontent.com/mrbean701/VNTECH-MTO/main/MTOPlugin/release
        (raw GitHub — repo public, không cần token)
```

| Thành phần | File | Vai trò |
|---|---|---|
| Logic quyết định | `lisp/mto-selfup.lsp` | Đọc version, so sánh semver, kiểm manifest, quyết định, ghi log |
| Thao tác nặng | `installer/updater/UpdaterApp.cs` | Tải, băm SHA256, giải nén, backup, swap |
| Phát hành | `scripts/publish-update.ps1` | Đóng gói + băm + sinh manifest |
| Nguồn phiên bản | `version.json` | **Nguồn sự thật duy nhất** |

**Luồng 8 bước:**
```
đọc version → check manifest → so sánh semver → TẢI → VERIFY SHA256
→ verify cấu trúc (chống zip-slip) → BACKUP → STAGE → ACTIVATE
→ VALIDATE → (lỗi thì) ROLLBACK
```

**Ranh giới an toàn dữ liệu:**

| Loại | Ghi đè được? |
|---|---|
| `lisp\` `docs\` `tools\` `dll\` `version.json` | ✅ Có |
| `config\` (rules.json, update.json, template) | ⛔ **KHÔNG BAO GIỜ** |
| `*.dwg`, `*.mtocfg` | ⛔ **KHÔNG BAO GIỜ** |

Chi tiết: `docs/update/UPDATE_ARCHITECTURE.md`.

---

## 8. Yêu cầu môi trường

| Thành phần | Yêu cầu |
|---|---|
| AutoCAD | **2023** (đã xác thực) · hỗ trợ 2018–2026 qua bundle tương ứng |
| Windows | 10 / 11 (64-bit) |
| .NET Framework | **4.8** (có sẵn trên Windows 10/11) |
| Quyền | **Không cần Admin** |
| Khác | Không cần .NET SDK · Excel · Python |

⚠️ **`SECURELOAD`:** AutoCAD mặc định chặn `load` ngoài Trusted Locations.
Bộ cài tự thêm đường dẫn; nếu lệnh MTO* không chạy → xem `docs/update/INSTALLATION.md` mục 3.

---

## 9. Trạng thái & chất lượng

| Chỉ số | Giá trị |
|---|---|
| MASTER GOAL | **19/19 mục core** ✅ |
| Module UPDATE | **10/10 task**, 16/16 TEST PASS ✅ |
| Test tự động | **700/700 PASS** |
| Cổng LINT | 44/44 file OK |
| Bug thật đã sửa | **28** (B1–B22 core · B23–B28 module update) |
| Tài liệu | 20 file (14 `.md` + 6 `.docx`) |

**Limitation đã ghi nhận:**
- Chưa hỗ trợ đầy đủ dynamic block (EffectiveName) và block lồng
- Chưa kiểm thử trên AutoCAD 2018–2022 (mới xác thực 2023)
- `.NET` DLL build net48 cho 2023; các bản khác cần build lại

---

## 10. Bản đồ tài liệu

| Cần gì | Đọc file |
|---|---|
| Mới dùng lần đầu | `docs/HUONG_DAN_NGUOI_MOI.md` |
| Dùng chi tiết theo lệnh | `docs/HUONG_DAN_SU_DUNG.md` |
| Đo cáp & in bảng | `docs/HUONG_DAN_DO_CAP_VA_IN_BANG.md` |
| Hiểu tổng thể hệ thống | **file này** |
| Nhận bàn giao | `docs/BAN_GIAO.md` |
| Lập trình tiếp | `docs/DEV_ONBOARDING.md` |
| Nhập danh mục vật tư | `docs/HUONG_DAN_NHAP_DANH_MUC_VAT_TU.md` |
| Dùng Rule Editor | `docs/GIAI_THICH_RULE_EDITOR.md` |
| Cài đặt & cập nhật | `docs/update/INSTALLATION.md` |
| Phát hành bản mới | `docs/update/RELEASE_PROCESS.md` |
| Xử lý sự cố | `docs/update/UPDATE_TROUBLESHOOTING.md` |
| Lịch sử từng task | `docs/agent-progress/TASK-000..027.md` |
| Đối chiếu hoàn thành | `docs/agent-progress/FINAL_AUDIT.md` |

---

*Tài liệu thuộc đề tài R&D-CAD-QTO-01 — VNTECH.*
