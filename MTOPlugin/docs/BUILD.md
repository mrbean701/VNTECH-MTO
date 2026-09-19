# Hướng dẫn build theo phiên bản AutoCAD

## Vấn đề

AutoCAD 2018-2026 không dùng chung một bộ assembly API, và kể từ **AutoCAD 2025**
bộ API quản lý (managed) chuyển sang **.NET 8**:

- AutoCAD 2018-2024: .NET Framework 4.8 (`net48`).
- AutoCAD 2025-2026: **.NET 8** (`net8.0-windows`).

Một project host phải build đúng TFM với nhóm AutoCAD đích, còn một DLL `net48`
không thể tham chiếu assembly AutoCAD 2025 (lỗi CS1705), vì vậy cần **3 nhóm
bundle** riêng.

## Cách xác định đường dẫn AutoCAD

Mặc định `MTOPlugin.csproj` tự dò các đường dẫn phổ thông (2018 -> 2025) và tự
chọn TFM: chứa "AutoCAD 2025"/"AutoCAD 2026" -> `net8.0-windows`
(auto-set `MtoNet8=true`), ngược lại -> `net48`. Truyền tay khi cài nơi khác:

```powershell
dotnet build MTOPlugin.sln /p:AcadDirectory="D:\AutoCAD\2023"
dotnet build MTOPlugin.sln /p:AcadDirectory="D:\AutoCAD\2025" -p:MtoNet8=true
```

## Cài công cụ build

```powershell
winget install Microsoft.DotNet.SDK.8      # .NET SDK 8 (bắt buộc cho 2025/2026)
```

Build bằng `dotnet`/`dotnet msbuild` là đủ; không bắt buộc Visual Studio.
Nếu có Visual Studio vẫn ưu tiên dùng MSBuild của nó (qua `scripts/build.ps1`).

## Ma trận build

| Nhóm bundle | AutoCAD | Target .NET | API lưu ý (2025, net8) |
|---|---|---|---|
| `MTOPlugin.2018-2022.bundle` | 2018-2022 (R22.0-R24.1) | net48 | API cổ điển |
| `MTOPlugin.2023-2024.bundle` | 2023-2024 (R24.2-R24.3) | net48 | API cổ điển |
| `MTOPlugin.2025-2026.bundle` | 2025-2026 (R25.0-R26.0) | **net8.0-windows** | `Extents3d` chuyển sang `DatabaseServices`; `ViewTableRecord.CenterPoint`; `Handle(long)`; `PaletteSet.AddVisual`; xref qua `XrefStatus`; LayoutManager không còn `IsModelSpace`/`IsLoaded` |

Khác biệt net48/net8 được gom trong `src/MTOPlugin/MtoCompat.cs` (biên dịch có điều
kiện `#if NET8_0_OR_GREATER`), host chỉ cần gọi helper chung.

## Quy trình build một bản phát hành

```powershell
# 1. Build từng nhóm (mỗi nhóm một lệnh)
.\scripts\build.ps1 -AcadVersion 2025        # -> net8.0-windows
.\scripts\build.ps1 -AcadVersion 2023        # -> net48
.\scripts\build.ps1 -AcadVersion 2020        # -> net48

# 2. Đưa DLL vào bundle theo nhóm
.\scripts\deploy-bundle.ps1 -AcadVersion 2025
.\scripts\deploy-bundle.ps1 -AcadVersion 2023
.\scripts\deploy-bundle.ps1 -AcadVersion 2020

# 3. Gộp payload + nhúng vào file EXE cài đặt 1-click
#    -> output\MTOPlugin.Setup-0.1.0.exe (người dùng chỉ cần file này)
.\scripts\build-installer.ps1
```

`build-installer.ps1` tự kiểm tra bundle; nếu `MTOPlugin.dll` chưa có trong bundle
thì in cảnh báo rõ ràng. Máy không cài AutoCAD nhóm nào thì nhóm đó không có DLL
(bình thường); muốn bộ cài đầy đủ thì build+deploy đủ 3 nhóm.

## Kiểm thử

```powershell
.\scripts\run-tests.ps1       # chạy NUnit cho Core trên .NET 8 (dotnet test)
```

Project test chạy TFM `net8.0` (không dùng `net48` để tránh lỗi NUnit engine
"Unknown framework version" khi máy có .NET 8).

## Ghi chú quan trọng (theo đề tài)

- Một trình cài đặt chung chứa nhiều bản chương trình theo nhóm phiên bản.
- Không coi một DLL là mặc nhiên tương thích toàn bộ từ 2018 trở lên:
  AutoCAD 2025+ phải dùng DLL build `net8.0-windows`.
- Chỉ những phiên bản đã cài, load và chạy đạt bộ ca kiểm thử mới ghi "Đã xác minh".
- Các phiên bản còn lại ghi rõ "Chưa xác minh".

## Đã xác minh trên máy hiện tại

- Build `net8.0-windows` (AutoCAD 2025) qua `dotnet build`: **thành công, 0 lỗi**.
- Test Core `net8.0`: **17/17 passed**.
- `deploy-bundle.ps1 -AcadVersion 2025` → `MTOPlugin.2025-2026.bundle` (15 DLL).
- `build-installer.ps1` → EXE; `--check`; `--install-silent` cài 3 bundle + đăng ký R25.0.
- Nhóm 2018-2022 / 2023-2024: **chưa xác minh** (máy chưa cài AutoCAD các nhóm này).