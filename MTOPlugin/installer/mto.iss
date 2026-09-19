; =====================================================================
; Inno Setup script - MTOPlugin
; PHUONG AN THAY THE (khong bat buoc).
; Cach CHINH (khuyen dung): scripts\build-installer.ps1 tao
; 1 file EXE duy nhat (output\MTOPlugin.Setup-0.1.0.exe) khong can Inno.
; Dung issc khi muon bộ cài co giao dien Inno chuan.
;
; Cài bundle vào %APPDATA%\Autodesk\ApplicationPlugins (AutoCAD tự quét,
; tự load khi khởi động nếu biến AppAutoLoad = 1 - giá trị mặc định).
;
; Cách build:
;   1) Build DLL theo nhóm phiên bản (xem docs/BUILD.md)
;   2) Chạy scripts\deploy-bundle.ps1 -AcadVersion 2024
;      -> copy DLL + dependencies vào installer\bundles\MTOPlugin.2023-2026.bundle\Contents\Windows\
;      (bundle nhóm B: MTOPlugin.2018-2022.bundle)
;   3) iscc installer\mto.iss
; =====================================================================
#define AppName "MTOPlugin"
#define AppVersion "0.1.0"
#define AppPublisher "Phong Du an"

; Bundle mặc định trong script này = nhóm C (2023-2026).
; Muốn build bộ cài cho nhóm B (2018-2022), đổi dòng dưới thành:
;   MTOPlugin.2018-2022.bundle
#define BundleFolder "MTOPlugin.2023-2026.bundle"

[Setup]
AppId={{3B6A18DE-4C92-4E1B-9A46-1C2A5E8D9F02}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={userappdata}\Autodesk\ApplicationPlugins\{#BundleFolder}
DisableDirPage=yes
OutputDir=..\output
OutputBaseFilename=MTOPlugin-{#AppVersion}-{#BundleFolder}
UninstallDisplayName={#AppName}-{#BundleFolder}
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest

[Languages]
Name: "vietnamese"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{app}\Contents\Windows"

[Files]
; --- Nhóm DLL (được deploy-bundle.ps1 copy sẵn vào bundle) ---
Source: "bundles\{#BundleFolder}\Contents\Windows\*.dll"; DestDir: "{app}\Contents\Windows"
Source: "bundles\{#BundleFolder}\PackageContents.xml";     DestDir: "{app}"

; --- Bộ quy tắc mẫu (copy lần đầu; không ghi đè nếu đã chỉnh sửa) ---
Source: "..\config\rules.sample.json"; DestDir: "{userappdata}\MTOPlugin\config"; Flags: onlyifdoesntexist

; --- Ghi registry "Applications\..." cho từng phiên bản AutoCAD trong nhóm ---
; Phần này KHÔNG bắt buộc (bundle tự load). Chỉ cần nếu muốn plugin do AutoCAD
; PluginManager quản lý (hiện disable/enable trong APPLOAD). Do các R-key động
; nên [Code] bên dưới tự dò và ghi.

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
{---------------------------------------------------------------------}
{ Đăng ký bundle vào registry Applications của AutoCAD theo nhóm version   }
{---------------------------------------------------------------------}

// Nhóm phiên bản. Series dùng số thập phân: 22.0=2018, 23.0=2019,
// 23.1=2020, 24.0=2021, 24.1=2022, 24.2=2023, 24.3=2024, 25.0=2025, 26.0=2026
const
  MinSeries = 24.2;   // nhóm C: 2023
  MaxSeries = 26.0;   // nhóm C: 2026

function SeriesInRange(const RKey: string): Boolean;
var
  V, Lo, Hi: Double;
  OK: Boolean;
begin
  // RKey dang "R24.3" hoac "24.3"
  Lo := MinSeries;
  Hi := MaxSeries;
  V := 0;
  OK := False;
  if Length(RKey) > 1 then
    V := StrToFloatDef(Copy(RKey, 2, Length(RKey) - 1), 0);
  Result := (V > 0) and (V >= Lo) and (V <= Hi);
end;

function RegisterBundleKeys: Boolean;
var
  Base, AppsRoot, RKey, SubKey, Path: string;
  i: Integer;
  SubKeys: TArrayOfString;
begin
  Result := False;
  Base := 'Software\Autodesk\AutoCAD';
  if RegGetSubkeyNames(HKCU, Base, SubKeys) then
  begin
    for i := 0 to GetArrayLength(SubKeys) - 1 do
    begin
      RKey := SubKeys[i];
      if (Copy(RKey, 1, 1) = 'R') and SeriesInRange(RKey) then
      begin
        // AutoCAD language subkey, vd "ACAD-0000:804" / "ACAD-B000:804"
        AppsRoot := Base + '\' + RKey;
        if RegGetSubkeyNames(HKCU, AppsRoot, SubKeys) then
        begin
          for i := 0 to GetArrayLength(SubKeys) - 1 do
          begin
            if Copy(SubKeys[i], 1, 5) = 'ACAD-' then
            begin
              SubKey := AppsRoot + '\' + SubKeys[i] + '\Applications\'
                       + '{#BundleFolder}';
              Path := '{#BundleFolder}\Contents\Windows\MTOPlugin.dll';
              RegWriteStringValue(HKCU, SubKey, 'LOADER', Path);
              RegWriteStringValue(HKCU, SubKey, 'LOADCTRLS', '5');
              RegWriteStringValue(HKCU, SubKey, 'ZOOMLOADER', '0');
              Result := True;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    RegisterBundleKeys;
end;

procedure CurUninstallStepChanged(CurStep: TUninstallStep);
begin
  // Gỡ registry entry: plugin vẫn tự load qua folder, entry chỉ phục vụ
  // quản lý bởi APPLOAD nên để lại vô hại. Xóa thủ công nếu muốn sạch.
end;