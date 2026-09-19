# MTOPro - Quick Start Guide for DeepSeek

## Repository Location
```
D:\13. Duong Trong Thang\Tai lieu\1. Du an chuan hoa quy trinh\quantity take-off\MTOPlugin\
```

## Key Files for Development

| File | Purpose |
|------|---------|
| `SPEC.md` | **FULL project specification** - Read this first |
| `src/MTOPlugin/` | Main AutoCAD .NET plugin (C#, WPF) |
| `src/MTOPlugin.Core/` | Core engine: rule matching, classification, Excel export |
| `src/MTOPlugin.UI/` | WPF panel UI |
| `config/rules.sample.json` | Sample rules file (extend this first) |
| `scripts/create-user-guide.ps1` | Word doc generator |

## Current State (v0.1.0)

The existing MTOPlugin already has:
- ✅ Core scanning: blocks, geometry (Line/Polyline/Arc/Circle)
- ✅ Rule engine (JSON-based, 5 calculation types)
- ✅ Excel export (5 sheets)
- ✅ 2-step workflow: scan → select rows → export
- ✅ MTOBANG command (summary table on new DWG)
- ✅ Multi-target: AutoCAD 2018-2024 (net48), 2025-2026 (net8)
- ✅ Xref 3 modes
- ✅ Session logging
- ✅ Unit conversion (mm/cm/m/ft/in)

## Priority Tasks for DeepSeek

### START HERE: Phase 1 - Core Foundation (Weeks 1-2)

1. **Rule Editor UI** (`src/MTOPlugin.UI/RuleEditor`)
   - Add dialog to create/edit/delete rules inside WPF panel
   - JSON schema already exists in SPEC.md Section 5

2. **Dynamic Block Property Reader** (`src/MTOPlugin/DynamicBlockReader`)
   - Read visibility states, length parameters from dynamic blocks
   - Use AutoCAD .NET API: `GetDynamicBlockProperties()`

3. **LISP Wrapper** (`src/MTOPlugin/Lisp/`)
   - Add `defun MTO`, `defun MTOSCAN`, `defun MTOEXPORT`
   - AutoLISP → .NET bridge

4. **Extended Calculation Types**
   - Add `CountIfAttributeEquals` (count blocks where attribute = value)
   - Add `SumLengthCeilingStep` (round up to standard lengths)

### Then: Phase 2 - Electrical + Plumbing (Weeks 3-4)

5. **Extend `config/rules.sample.json`**
   - Add rules for electrical: lighting, outlets, panels, cables, conduits, cable trays
   - Add rules for plumbing: pipes, valves, fixtures
   - Add layer patterns: `EL-COND-*`, `EL-CAB-*`, `PLB-PIPE-*`, etc.

6. **Attribute Extraction**
   - Block attributes: WATTAGE, RATING, SIZE, MODEL
   - Add to `BlockReferenceInfo.Attributes` dictionary

### Then: Phase 3 - ELV Networks + Data Center (Weeks 5-6)

7. **ELV Rules** (see SPEC.md Section 3.3 for full list)
   - Network: switches, routers, APs, patch panels
   - Data Center: servers, UPS, racks, PDUs
   - CCTV: cameras, NVRs
   - Access Control: controllers, readers, locks
   - Fire Alarm: detectors, MCPs, sirens
   - PA: speakers, amplifiers
   - BMS: controllers, sensors

### Then: Phase 4 - Batch + Reporting (Weeks 7-10)

8. **Batch Processing** (`src/MTOPlugin.Batch`)
   - Multi-file DWG scanning
   - Merged Excel output
   - Progress UI

9. **PDF Export** (optional)
   - Use QuestPDF or similar

## Build Commands

```powershell
# Build
dotnet build MTOPlugin.sln -c Debug

# Test
dotnet test MTOPlugin.sln

# Deploy bundle for AutoCAD 2025
.\scripts\deploy-bundle.ps1 -AcadVersion 2025 -Config Release

# Build installer
.\scripts\build-installer.ps1
```

## Code Conventions

- C# 12, .NET 8
- Namespace: `MTOPro.{Module}.{Class}`
- See `SPEC.md` Section 11.1 for full conventions

## Naming Convention (Critical!)

```
Layer pattern examples:
  EL-COND-WALL-DN20       → Electrical Conduit Wall DN20
  EL-CAB-3C-2.5mm2       → Electrical Cable 3-Core 2.5mm2
  PLB-PIPE-PPR-DN25       → Plumbing Pipe PPR DN25
  ELV-NET-CAB-CAT6A       → ELV Network Cable Cat6A
  ELV-CAM-DOME-4MP        → ELV Camera Dome 4MP

Block naming:
  EL-LIGHT-DL-10W-40K     → Electrical Light Downlight 10W 4000K
  ELV-NET-POE-24P         → ELV Network Switch PoE 24 Port
```

## Architecture Overview

```
AutoCAD
  ├── MTOCommands (.NET) → WPF Panel
  │       ├── RuleEditor dialog
  │       └── Scan options UI
  ├── AutoCadScanner → ScanResult
  │       ├── Block scanning
  │       ├── Geometry scanning (Line/Polyline/Arc/Circle)
  │       └── Xref handling
  └── MTOPlugin.Core
          ├── RuleMatcher → matches entities to rules
          ├── ClassificationEngine → applies rules
          └── ExcelExporter → 5-sheet export
```

## Important Notes

1. **AutoCAD 2025+ uses .NET 8**, older versions use .NET Framework 4.8
2. Use `MtoCompat.cs` for API differences between versions
3. The `Handle` constructor changed in AutoCAD 2025 (long vs ulong)
4. PaletteSet constructor changed (Guid vs string)
5. See `SPEC.md` Section 2.4 for bundle groups

## Next Action

Read `SPEC.md` completely, then start with:
1. Rule Editor UI (most valuable immediate feature)
2. Extend `rules.sample.json` with 20-30 sample rules
3. Add attribute extraction to block scanning

## Questions?

- Full details: See `SPEC.md`
- Current code: See `src/MTOPlugin/`
- Sample rules: See `config/rules.sample.json`
