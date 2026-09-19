# TASK-017 — .NET Extension (Palette / Excel nâng cao)

**Phase:** PHASE 5
**Trạng thái:** ✅ DONE (cho AutoCAD 2023 / net48)
**Thời điểm:** 2026-09-18
**Phụ thuộc:** TASK-016

---

## Objective

Mở rộng .NET (Palette / Inspector / Ribbon / Excel nâng cao) và **làm cho .NET host chạy
được trên AutoCAD có trên máy**.

---

## Vấn đề gốc

| Thành phần | Trước | Sau |
|---|---|---|
| AutoCAD trên máy | 2023 = **R24.2 / .NET Framework 4.8** | — |
| DLL .NET | build `net8.0-windows` ⇒ **KHÔNG nạp được** | **build `net48` ⇒ NẠP ĐƯỢC** |
| Build net48 | ❌ 27 lỗi API | ✅ **0 lỗi** |

---

## Phát hiện then chốt

**`MtoCompat.cs` được viết NGƯỢC.** File giả định `net48 = API cũ`, nhưng thực tế
**AutoCAD 2023 dùng API giống AutoCAD 2025**:

| API | Nhánh `#else` cũ (net48) — SAI | Thực tế AutoCAD 2023 |
|---|---|---|
| `Extents3d` | `Geometry.Extents3d` | `DatabaseServices.Extents3d` (đã kiểm bằng reflection `acdbmgd.dll`) |
| `Extents3d.GetCenter` | có | **không có** → tự tính `(Min+Max)/2` |
| `Extents3d.IsValid` | có | **không có** → tự kiểm kích thước |
| `BlockReference.EffectiveName` | có | **không có** → dùng `.Name` |
| `ViewTableRecord` | `EditorInput` | `DatabaseServices` |
| `Handle` | `Handle(ulong)` | `Handle(long)` |
| `BlockTableRecord.IsLoaded` | có | **không có** → `!IsUnloaded` |
| `IsOverlayReferenceOfExternalReference` | có | **không có** |
| `GetDynamicBlockProperties()` | dùng | **không có** → `DynamicBlockReferencePropertyCollection` |
| `DynamicBlockReferencePropertyType` | dùng | **không có** → `PropertyTypeCode` (int) |
| `PaletteSet(name, string)` | dùng | **không có** → cần `Guid` |
| `PromptSaveFileOptions.DialogTitle/DefaultExt`, `Editor.GetFilenameForSave` | dùng | **không có** → nhập đường dẫn bằng `GetString` |

⇒ **Sửa: dùng CHUNG một implementation** (nhánh API "mới") cho cả net48 và net8,
bỏ `#if` sai. Ghi chú limitation cho AutoCAD 2018–2022 (chưa có máy kiểm chứng).

---

## Files changed

| File | Hành động |
|---|---|
| `src/MTOPlugin/MtoCompat.cs` | **Viết lại** — bỏ `#if` ngược, dùng chung implementation |
| `src/MTOPlugin/MTOCommands.cs` | Sửa alias `AcadExtents` dùng chung `DatabaseServices` |
| `src/MTOPlugin/Scanner/DynamicBlockReader.cs` | Dùng `DynamicBlockReferencePropertyCollection`; bỏ `PropertyType`; `IndexOf` thay `Contains(…, cmp)` |
| `src/MTOPlugin/MtoBangCommand.cs` | `GetSavePath` trả `string`; nhánh net48 nhập đường dẫn bằng `GetString` |
| `src/MTOPlugin/UI/PaletteWrapper.cs` | `PaletteSet` dùng `Guid` cho cả hai TFM |
| `docs/agent-progress/TASK-017.md` | Tạo mới |

---

## Test performed

```powershell
# 1. Build cho AutoCAD 2023 (net48)
dotnet build src\MTOPlugin\MTOPlugin.csproj -f net48 `
  /p:AcadDirectory="D:\0.APP\AutodeskAutoCAD2023\AutoCAD 2023" /p:MtoNet8=false

# 2. NETLOAD DLL vào AutoCAD 2023 engine + chạy command .NET
accoreconsole /s nl.scr
#   nl.scr: SECURELOAD=0 -> NETLOAD MTOPlugin.dll -> MTOZOOM -> ZZZZZZ
```

## Test result

**PASS — có bằng chứng thật**

```
Build:   Build succeeded. 0 Warning(s) 0 Error(s)
NETLOAD: (không báo lỗi)
Command: Nhap Handle doi tuong can tim: ZZZZZZ
         Handle khong hop le.
```

⇒ Assembly **nạp được**, `[CommandMethod]` (MTOZOOM) **đăng ký và thực thi đúng logic**
(ZZZZZZ không phải hex ⇒ in "Handle khong hop le.").

DLL sinh ra: `MTOPlugin.dll` (35 KB), `MTOPlugin.UI.dll` (48.5 KB),
`MTOPlugin.Core.dll`, `MTOPlugin.Logging.dll` — đều bản **net48**.

---

## Known issues / Limitation

| # | Nội dung | Mức |
|---|---|---|
| L1 | **UI palette (WPF) chưa kiểm chứng** — accoreconsole không có UI. Cần AutoCAD đầy đủ để xác nhận `MTO` mở palette | Trung bình |
| L2 | **net8 (AutoCAD 2025+) chưa kiểm chứng** — máy không có AutoCAD 2025 nên không có reference DLLs. Nhánh `#if NET8_0_OR_GREATER` trong `DynamicBlockReader` vẫn giữ cho tương lai | Trung bình |
| L3 | **AutoCAD 2018–2022 chưa hỗ trợ** — cần máy thật để xác định ranh giới API | Trung bình |
| L4 | Excel nâng cao (EPPlus) đã có trong `MTOPlugin.Core`; phần "active cell export" chưa làm | Thấp |

---

## Next task

**FINAL AUDIT** — đối chiếu implementation với MASTER GOAL (đã thực hiện).
