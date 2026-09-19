# Hướng dẫn cài đặt MTOPlugin

> **Cách chuẩn (người dùng cuối):** chỉ cần **MỘT file** `MTOPlugin.Setup-0.1.0.exe`.
> Double-click → tự cài → mở lại AutoCAD → không cần thao tác gì thêm.

| Cách | Độ phức tạp | Khi nào dùng |
|---|---|---|
| **1. Bộ cài EXE (one-click)** | Không (chỉ click) | Người dùng cuối, triển khai hàng loạt |
| 2. Bundle tự load | Thấp | Cài tay cho máy cá nhân |
| 3. NETLOAD | Thấp | Kiểm thử nhanh tại chỗ |
| 4. Tự build EXE | Trung bình | Chỉ bộ phận phát triển |

> **Nguyên tắc quan trọng:** DLL của AutoCAD 2018-2022 / 2023-2024 là bản
> `net48`, còn **AutoCAD 2025-2026 phải dùng bản `net8.0-windows`**. Bộ cài EXE
> cài cả **3 nhóm**; mỗi AutoCAD tự nạp đúng nhóm của nó (qua `PackageContents.xml`)
> nên không xung đột. Khi cài thủ công phải dùng đúng nhóm (xem ma trận `BUILD.md`).
> AutoCAD 2025+ cài sẵn .NET 8 Desktop Runtime nên người dùng không cần cài gì thêm.

---

## 1. Bộ cài One-click EXE (khuyên dùng)

Yêu cầu: Windows 10/11 x64, AutoCAD đầy đủ 2018-2026 đã cài sẵn.
Không cần quyền Admin, không cần mở AutoCAD trước.

1. Nhận file `MTOPlugin.Setup-0.1.0.exe` (một file duy nhất, nội dung nhúng sẵn).
2. **Double-click** file EXE.
3. Chờ thông báo "Cài đặt hoàn tất".
4. Đóng và mở lại AutoCAD (nếu đang chạy).
5. Gõ lệnh `MTO` để dùng.

Bộ cài tự động:
- Nhận diện mọi AutoCAD 2018-2026 (registry), cài **3 bundle**
  `MTOPlugin.2018-2022.bundle` + `MTOPlugin.2023-2024.bundle` +
  `MTOPlugin.2025-2026.bundle` vào `%APPDATA%\Autodesk\ApplicationPlugins\`
- Đăng ký plugin cho các phiên bản AutoCAD tìm thấy
  (registry `...\Applications\...`)
- Cài bộ quy tắc mẫu `rules.json` lần đầu (không ghi đè khi đã tồn tại)
- Ghi nhật ký: `%LOCALAPPDATA%\MTOPlugin\logs\setup.log`

**Gỡ cài:** chạy `MTOPlugin.Setup-0.1.0.exe --uninstall-silent`
hoặc xóa các thư mục `MTOPlugin.*.bundle` trong `%APPDATA%\Autodesk\ApplicationPlugins`.

**Dùng ở chế độ dòng lệnh:**
```powershell
MTOPlugin.Setup-0.1.0.exe --check            # kiểm tra môi trường (không cài)
MTOPlugin.Setup-0.1.0.exe --install-silent   # cài không hiện cửa sổ
MTOPlugin.Setup-0.1.0.exe --uninstall-silent # gỡ không hiện cửa sổ
```
Lỗi "không thấy payload" = file EXE đang bị build khi chưa có nhóm DLL → báo bộ
phận phát triển chạy lại `scripts\build-installer.ps1`.

---

## 2. Cài thủ công bằng bundle (không có EXE)

Copy nguyên thư mục bundle đúng nhóm vào `%APPDATA%\Autodesk\ApplicationPlugins\`:

- `MTOPlugin.2025-2026.bundle` dành cho AutoCAD 2025-2026 (bản .NET 8)
- `MTOPlugin.2023-2024.bundle` dành cho AutoCAD 2023-2024
- `MTOPlugin.2018-2022.bundle` dành cho AutoCAD 2018-2022

(Có thể cài cả ba.) Mở lại AutoCAD → tự load → gõ `MTO`.
Gỡ: xóa thư mục bundle đó.

Cấu trúc bundle:
```
MTOPlugin.<nhóm>.bundle\
├── PackageContents.xml     ← khai báo dải phiên bản (R22.0-R24.1 / R24.2-R24.3 / R25.0-R26.0)
└── Contents\Windows\MTOPlugin.dll (+ Core, UI, Logging, EPPlus, LSJSON, ...)
```

---

## 3. NETLOAD (test nhanh, cho kỹ thuật)

1. Build đúng nhóm AutoCAD đang dùng (xem `BUILD.md`):
   AutoCAD 2025+ → `src\MTOPlugin\bin\Release\net8.0-windows\`,
   AutoCAD 2018-2024 → `src\MTOPlugin\bin\Release\net48\`.
2. Để cả bộ DLL cùng thư mục: MTOPlugin, Core, UI, Logging, EPPlus, LSJSON.
3. AutoCAD → `NETLOAD` → chọn `MTOPlugin.dll`.
4. `MTO`.
Hạn chế: phải nạp lại mỗi lần mở AutoCAD.

---

## 4. Tự tạo bộ cài EXE (bộ phận phát triển)

Chạy trên máy có .NET SDK 8 (hoặc Visual Studio) + đã build được nhóm DLL:

```powershell
.\scripts\build.ps1 -AcadVersion 2025
.\scripts\deploy-bundle.ps1 -AcadVersion 2025
.\scripts\build-installer.ps1
```

Để bộ cài có đủ 3 nhóm: lặp lại build+deploy cho `-AcadVersion 2023`, `2020`.
Bước cuối gộp các bundle + bộ quy tắc mẫu vào `output\MTOPlugin.Setup.payload.zip`
rồi nhúng thẳng vào file EXE: `output\MTOPlugin.Setup-0.1.0.exe`.

---

## Xử lý sự cố thường gặp

| Lỗi | Nguyên nhân | Giải pháp |
|---|---|---|
| EXE báo không thấy payload | EXE build khi chưa có nhóm DLL | Bộ phận phát triển chạy lại build-installer.ps1 sau khi build+deploy đủ nhóm |
| Cài xong gõ MTO không có lệnh | Load lỗi khởi động / nhầm nhóm DLL | Xem `%LOCALAPPDATA%\MTOPlugin\logs`; dùng EXE bản mới nhất |
| "dependency is not present" | Thiếu DLL đi kèm (chỉ gặp cài tay) | Dùng EXE; cài tay phải đủ Core/UI/Logging/EPPlus/LSJSON cùng thư mục |
| BadImageFormat | Nhầm x86/x64, hoặc nhầm nhóm (dùng DLL net48 trên AutoCAD 2025) | Dùng EXE (tự chọn nhóm) |
| Bundle không tự nạp | AppAutoLoad tắt / sai thư mục | Kiểm tra `%APPDATA%\Autodesk\ApplicationPlugins`; bật auto-load trong APPLOAD |
| Export không có dữ liệu | Bản vẽ rỗng trong phạm vi | Bảo vệ có chủ đích; chọn phạm vi có dữ liệu |

---

## Nhật ký và cấu hình

- Nhật ký bộ cài EXE: `%LOCALAPPDATA%\MTOPlugin\logs\setup.log`
- Nhật ký phiên plugin: `%LOCALAPPDATA%\MTOPlugin\logs\*.log`
- Bộ quy tắc: `%LOCALAPPDATA%\MTOPlugin\config\rules.json` (mẫu: `config\rules.sample.json`)
- Lệnh kiểm tra: `MTOZOOM <handle>` tìm đối tượng theo Handle (dạng hex)
- Lệnh tạo bảng nhanh: `MTOBANG` tạo bảng tổng hợp trên bản vẽ mới (dữ liệu lấy từ
  lần quét gần nhất trong phiên)