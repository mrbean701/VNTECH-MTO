using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Xref;

namespace MTOPlugin.Scanner
{
    /// <summary>
    /// Quet du lieu tu file DWG dang mo trong AutoCAD va chuyen thanh ScanResult
    /// (cac model thuan C# kha nang truy vet). KHONG sua/xoa bat ky doi tuong nao.
    ///
    /// Ghi chu tranh tinh lap Model qua viewport: khi quet paper space (Layout),
    /// ta chi quet cac entity thuoc ben trong btr cua paper space. Cac doi tuong
    /// Model hien thi qua viewport khong bao gio thuoc btr paper space nen khong
    /// bi dem trung. Model space duoc quet dung mot lan.
    /// </summary>
    public static class AutoCadScanner
    {
        private const int MaxNestedDepth = 12;
        private static readonly DynamicBlockReader _dynamicBlockReader = new DynamicBlockReader();

        public static ScanResult Scan(Document doc, ScanOptions options)
        {
            var result = new ScanResult
            {
                DrawingFile = doc.Name,
                Options = options,
                RunAtUtc = DateTime.UtcNow
            };

            var sw = System.Diagnostics.Stopwatch.StartNew();
            try
            {
                using (var tr = doc.Database.TransactionManager.StartTransaction())
                {
                    result.Unit = DetectUnit(tr, doc.Database);
                    result.Options.Unit = result.Unit;

                    var xrefManager = new XrefManager(options.XrefMode);
                    var traversed = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

                    var records = ResolveRecordsToScan(doc, tr, options.Scope);
                    foreach (var item in records)
                    {
                        ScanBlockTableRecord(tr, item.RecordId, item.LayoutName, item.Source, item.FromXref,
                            xrefManager, result, traversed, 0);
                    }

                    CollectXrefInfo(tr, doc.Database, result);
                    Deduplicate(result);
                    result.Layers.AddRange(ComputeLayerStats(result));

                    tr.Commit();
                }
            }
            catch (Exception ex)
            {
                result.ErrorMessage = ex.Message;
                result.ErrorCount++;
                result.AddWarning(new ScanWarning
                {
                    Code = "SCAN_ERROR",
                    Message = ex.Message,
                    Severity = "Error"
                });
            }
            finally
            {
                sw.Stop();
                result.ScanDuration = sw.Elapsed;
            }

            return result;
        }

        // =========================================================================
        // Xac dinh cac record can quet theo scope
        // =========================================================================
        private struct RecordToScan
        {
            public ObjectId RecordId;
            public string LayoutName;
            public string Source;
            public bool FromXref;
        }

        private static List<RecordToScan> ResolveRecordsToScan(Document doc, Transaction tr, ScanScope scope)
        {
            var list = new List<RecordToScan>();
            var db = doc.Database;
            var layoutMgr = LayoutManager.Current;

            var modelLayout = layoutMgr.GetLayoutId("Model");

            void AddCurrentLayoutPaper()
            {
                var curLayoutId = layoutMgr.GetLayoutId(layoutMgr.CurrentLayout);
                if (curLayoutId == modelLayout) return;
                var layout = tr.GetObject(curLayoutId, OpenMode.ForRead) as Layout;
                if (layout == null) return;
                list.Add(new RecordToScan
                {
                    RecordId = layout.BlockTableRecordId,
                    LayoutName = layout.LayoutName,
                    Source = null,
                    FromXref = false
                });
            }

            switch (scope)
            {
                case ScanScope.Selection:
                    var selRes = doc.Editor.GetSelection(new PromptSelectionOptions
                    {
                        MessageForAdding = "Chon doi tuong can boc tach: "
                    });
                    if (selRes.Status == PromptStatus.OK)
                    {
                        foreach (ObjectId id in selRes.Value.GetObjectIds())
                        {
                            var entity = tr.GetObject(id, OpenMode.ForRead, false) as Entity;
                            if (entity == null) continue;
                            list.Add(new RecordToScan
                            {
                                RecordId = id,
                                LayoutName = GetOwnerLayoutName(tr, entity),
                                Source = null,
                                FromXref = false
                            });
                        }
                    }
                    break;

                case ScanScope.ModelSpace:
                    list.Add(new RecordToScan
                    {
                        RecordId = GetModelSpaceId(tr, db),
                        LayoutName = "Model",
                        Source = null,
                        FromXref = false
                    });
                    break;

                case ScanScope.CurrentLayout:
                    list.Add(new RecordToScan
                    {
                        RecordId = GetModelSpaceId(tr, db),
                        LayoutName = "Model",
                        Source = null,
                        FromXref = false
                    });
                    AddCurrentLayoutPaper();
                    break;

                case ScanScope.AllLayouts:
                    foreach (ObjectId layoutId in GetLayoutIds(tr, db))
                    {
                        if (layoutId == modelLayout) continue;
                        var layout = tr.GetObject(layoutId, OpenMode.ForRead) as Layout;
                        if (layout == null) continue;
                        list.Add(new RecordToScan
                        {
                            RecordId = layout.BlockTableRecordId,
                            LayoutName = layout.LayoutName,
                            Source = null,
                            FromXref = false
                        });
                    }
                    break;

                case ScanScope.ModelAndAllLayouts:
                default:
                    list.Add(new RecordToScan
                    {
                        RecordId = GetModelSpaceId(tr, db),
                        LayoutName = "Model",
                        Source = null,
                        FromXref = false
                    });
                    foreach (ObjectId layoutId in GetLayoutIds(tr, db))
                    {
                        if (layoutId == modelLayout) continue;
                        var layout = tr.GetObject(layoutId, OpenMode.ForRead) as Layout;
                        if (layout == null) continue;
                        list.Add(new RecordToScan
                        {
                            RecordId = layout.BlockTableRecordId,
                            LayoutName = layout.LayoutName,
                            Source = null,
                            FromXref = false
                        });
                    }
                    break;
            }

            return list;
        }

        private static ObjectId GetModelSpaceId(Transaction tr, Database db)
        {
            try
            {
                var bt = tr.GetObject(db.BlockTableId, OpenMode.ForRead, false) as BlockTable;
                if (bt != null) return bt[MtoCompat.ModelSpaceName];
            }
            catch (Exception) { }
            return ObjectId.Null;
        }

        private static IEnumerable<ObjectId> GetLayoutIds(Transaction tr, Database db)
        {
            var dict = tr.GetObject(db.LayoutDictionaryId, OpenMode.ForRead, false) as DBDictionary;
            if (dict == null) yield break;
            foreach (DBDictionaryEntry entry in dict)
                yield return entry.Value;
        }

        private static string GetOwnerLayoutName(Transaction tr, Entity entity)
        {
            try
            {
                var owner = tr.GetObject(entity.OwnerId, OpenMode.ForRead) as BlockTableRecord;
                if (owner != null)
                {
                    if (owner.IsLayout) return owner.Name;
                    if (MtoCompat.IsModelSpace(owner)) return "Model";
                }
            }
            catch (Exception) { }
            return "?";
        }

        // =========================================================================
        // Quet mot block table record
        // =========================================================================
        private static void ScanBlockTableRecord(Transaction tr, ObjectId recordId,
            string layoutName, string sourceFile, bool fromXref,
            XrefManager xrefManager, ScanResult result, HashSet<string> traversed, int depth)
        {
            if (depth > MaxNestedDepth)
            {
                result.AddWarning(new ScanWarning
                {
                    Code = "NEST_DEPTH",
                    Message = "Vuot do sau long nhau toi da (" + MaxNestedDepth + ") tai record handle " + recordId.Handle,
                    Layout = layoutName, SourceFile = sourceFile, Severity = "Warning"
                });
                return;
            }

            var btr = tr.GetObject(recordId, OpenMode.ForRead) as BlockTableRecord;
            if (btr == null) return;

            foreach (ObjectId entId in btr)
            {
                try
                {
                    var entity = tr.GetObject(entId, OpenMode.ForRead, false) as Entity;
                    if (entity == null) continue;

                    if (result.Options.SkipFrozenLayers && IsLayerInvisible(tr, entity.Layer, entity.GetEntityColorIndex()))
                        continue;

                    switch (entity)
                    {
                        case BlockReference br:
                            HandleBlockReference(tr, br, layoutName, sourceFile, fromXref,
                                xrefManager, result, traversed, depth);
                            break;

                        case Line line:
                            AddGeometry(result, GeometryKind.Line, line.Length,
                                line, sourceFile, layoutName, fromXref);
                            break;

                        case Polyline pl:
                            AddGeometry(result, GeometryKind.Polyline, SafeLen(tr, pl),
                                pl, sourceFile, layoutName, fromXref);
                            break;

                        case Polyline2d pl2:
                            AddGeometry(result, GeometryKind.Polyline2D, SafeLen(tr, pl2),
                                pl2, sourceFile, layoutName, fromXref);
                            break;

                        case Polyline3d pl3:
                            AddGeometry(result, GeometryKind.Polyline3D, SafeLen(tr, pl3),
                                pl3, sourceFile, layoutName, fromXref);
                            break;

                        case Arc arc:
                            AddGeometry(result, GeometryKind.Arc, arc.Radius * arc.TotalAngle,
                                arc, sourceFile, layoutName, fromXref);
                            break;

                        case Circle cir:
                            AddGeometry(result, GeometryKind.Circle,
                                2 * Math.PI * cir.Radius, cir, sourceFile, layoutName, fromXref);
                            break;
                    }
                }
                catch (Exception ex)
                {
                    result.ErrorCount++;
                    result.AddWarning(new ScanWarning
                    {
                        Code = "ENTITY_ERROR",
                        Message = "Loi doc entity: " + ex.Message,
                        Layout = layoutName, SourceFile = sourceFile,
                        Handle = entId.Handle.ToString(), Severity = "Error"
                    });
                }
            }
        }

        private static void AddGeometry(ScanResult result, GeometryKind kind, double length,
            Entity entity, string sourceFile, string layoutName, bool fromXref)
        {
            if (length < 0) length = 0;
            result.Geometries.Add(new GeometryInfo
            {
                Kind = kind,
                RawLength = length,
                Layer = entity.Layer,
                ColorIndex = entity.GetEntityColorIndex(),
                Linetype = entity.Linetype,
                Identity = BuildIdentity(entity, sourceFile, layoutName, fromXref),
                IsNested = fromXref
            });
            result.TotalEntitiesScanned++;
        }

        private static double SafeLen(Transaction tr, Entity e)
        {
            try
            {
                if (e is Polyline p) return p.Length;
                if (e is Polyline2d p2)
                {
                    double dist = 0;
                    try { dist = p2.GetDistAtPoint(p2.EndPoint); } catch (Exception) { }
                    return dist;
                }
                if (e is Polyline3d p3)
                {
                    double sum = 0;
                    Point3d? prev = null;
                    foreach (ObjectId vId in p3)
                    {
                        var vertex = tr.GetObject(vId, OpenMode.ForRead, false) as PolylineVertex3d;
                        if (vertex != null)
                        {
                            if (prev.HasValue) sum += prev.Value.DistanceTo(vertex.Position);
                            prev = vertex.Position;
                        }
                    }
                    return sum;
                }
            }
            catch (Exception) { }
            return 0;
        }

        private static void HandleBlockReference(Transaction tr, BlockReference br,
            string layoutName, string sourceFile, bool fromXref,
            XrefManager xrefManager, ScanResult result, HashSet<string> traversed, int depth)
        {
            var blockDef = tr.GetObject(br.BlockTableRecord, OpenMode.ForRead, false) as BlockTableRecord;
            if (blockDef == null) return;

            bool isXrefRef = MtoCompat.IsXrefReference(blockDef);
            string effectiveName = MtoCompat.EffectiveBlockName(br);
            bool isDynamic = br.IsDynamicBlock;
            string dynName = null;
            if (isDynamic && br.DynamicBlockTableRecord.IsValid)
            {
                try
                {
                    var dBar = tr.GetObject(br.DynamicBlockTableRecord, OpenMode.ForRead, false) as BlockTableRecord;
                    dynName = dBar?.Name;
                }
                catch (Exception) { }
            }
            string blockName = string.IsNullOrEmpty(blockDef.Name) ? effectiveName : blockDef.Name;

            bool beInXref = isXrefRef || fromXref;

            var identity = new ObjectIdentity
            {
                Handle = SafeHandle(br),
                SourceFile = sourceFile ?? "host",
                Layout = layoutName ?? "Model",
                Space = string.Equals(layoutName, "Model") ? SpaceKind.Model : SpaceKind.Paper,
                IsFromXref = beInXref,
                XrefBlockName = beInXref ? blockName : null
            };

            // Lay file nguon that su cua xref
            string xrefSourceFile = null;
            if (isXrefRef)
            {
                try { xrefSourceFile = blockDef.PathName; } catch (Exception) { }
            }

            bool shouldCount = true;
            if (beInXref)
            {
                shouldCount = xrefManager.ShouldCount(xrefSourceFile ?? sourceFile, blockName);
            }

            if (shouldCount)
            {
                var dynamicProps = isDynamic
                    ? _dynamicBlockReader.ReadDynamicPropertiesFromBlock(br, tr)
                    : new Dictionary<string, object>();

                result.Blocks.Add(new BlockReferenceInfo
                {
                    BlockName = blockName,
                    EffectiveName = effectiveName,
                    IsDynamic = isDynamic,
                    DynamicBlockName = dynName,
                    IsXref = isXrefRef,
                    Layer = br.Layer,
                    ColorIndex = br.GetEntityColorIndex(),
                    Linetype = br.Linetype,
                    RotationRadians = br.Rotation,
                    ScaleX = br.ScaleFactors.X,
                    ScaleY = br.ScaleFactors.Y,
                    ScaleZ = br.ScaleFactors.Z,
                    PositionX = br.Position.X,
                    PositionY = br.Position.Y,
                    PositionZ = br.Position.Z,
                    Attributes = ReadAttributes(tr, br),
                    DynamicProperties = dynamicProps,
                    Identity = identity,
                    IsNested = depth > 0
                });
                result.TotalEntitiesScanned++;
            }

            // De quy vao ben trong block/xref
            bool scanInside = result.Options.ScanNestedBlocks;
            if (scanInside)
            {
                // Chi quet vao xref khi che do xref != Ignore
                if (!isXrefRef || xrefManager.Mode != XrefMode.Ignore)
                {
                    string nestedKey = br.BlockTableRecord.Handle.ToString();
                    // Tranh vong lap, nhung block duoc chen nhieu lan thi van quet (bo qua trung bang Deduplicate)
                    if (traversed.Add(nestedKey) || isXrefRef)
                    {
                        ScanBlockTableRecord(tr, br.BlockTableRecord,
                            layoutName, xrefSourceFile ?? sourceFile,
                            fromXref || isXrefRef, xrefManager, result, traversed, depth + 1);
                    }
                }
            }
        }

        // =========================================================================
        // Layer invisible (off/frozen)
        // =========================================================================
        private static readonly Dictionary<string, bool> _layerVisCache =
            new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);

        internal static void ResetLayerCache() => _layerVisCache.Clear();

        private static bool IsLayerInvisible(Transaction tr, string layerName, int colorIndex)
        {
            try
            {
                // Layer thuoc xref co dang "NAMELAYER|xref"; phan dau "|" la ten layer that
                // trong database xref (khong co o db hien tai). Bo qua kiem tra khi la xref.
                string realName = layerName;
                int pipe = layerName.IndexOf('|');
                if (pipe >= 0) realName = layerName.Substring(pipe + 1);

                if (_layerVisCache.TryGetValue(realName, out var cached))
                    return cached;

                // Duong dan toi LayerTable cua database dang mo. De tranh phu thuoc layout,
                // ta kiem tra qua db cua document hien tai.
                var db = LocalDb();
                if (db == null)
                {
                    _layerVisCache[realName] = false;
                    return false;
                }

                using (var lt = (LayerTable)tr.GetObject(db.LayerTableId, OpenMode.ForRead, false))
                {
                    if (lt == null)
                    {
                        _layerVisCache[realName] = false;
                        return false;
                    }
                    foreach (ObjectId layerId in lt)
                    {
                        var ltr = tr.GetObject(layerId, OpenMode.ForRead, false) as LayerTableRecord;
                        if (ltr == null) continue;
                        if (string.Equals(ltr.Name, realName, StringComparison.OrdinalIgnoreCase))
                        {
                            bool invisible = ltr.IsOff || ltr.IsFrozen || ltr.IsHidden;
                            _layerVisCache[realName] = invisible;
                            return invisible;
                        }
                    }
                }

                _layerVisCache[realName] = false;
                return false;
            }
            catch (Exception)
            {
                return false;
            }
        }

        [System.Runtime.CompilerServices.MethodImpl(System.Runtime.CompilerServices.MethodImplOptions.NoInlining)]
        private static Database LocalDb()
        {
            try { return Application.DocumentManager.MdiActiveDocument?.Database; }
            catch (Exception) { return null; }
        }

        // =========================================================================
        // Attributes
        // =========================================================================
        private static Dictionary<string, string> ReadAttributes(Transaction tr, BlockReference br)
        {
            var attrs = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            try
            {
                foreach (ObjectId attId in br.AttributeCollection)
                {
                    var attr = tr.GetObject(attId, OpenMode.ForRead, false) as AttributeReference;
                    if (attr == null) continue;
                    if (!attrs.ContainsKey(attr.Tag))
                        attrs[attr.Tag] = attr.TextString;
                }
            }
            catch (Exception) { }
            return attrs;
        }

        // =========================================================================
        // Xref info
        // =========================================================================
        private static void CollectXrefInfo(Transaction tr, Database db, ScanResult result)
        {
            try
            {
                var bt = tr.GetObject(db.BlockTableId, OpenMode.ForRead) as BlockTable;
                if (bt == null) return;

                foreach (ObjectId btrId in bt)
                {
                    var btr = tr.GetObject(btrId, OpenMode.ForRead, false) as BlockTableRecord;
                    if (btr == null || !btr.IsFromExternalReference) continue;

                    string path = null;
                    bool exists = false;
                    try
                    {
                        path = btr.PathName;
                        exists = !string.IsNullOrEmpty(path) && File.Exists(path);
                    }
                    catch (Exception) { }

                    bool isLoaded = true;
                    try { isLoaded = MtoCompat.IsXrefLoaded(btr); } catch (Exception) { }

                    result.Xrefs.Add(new XrefReference
                    {
                        BlockName = string.IsNullOrEmpty(btr.Name) ? "?" : btr.Name,
                        FullPath = path,
                        SourceExists = exists,
                        IsUnloaded = !isLoaded,
                        NestLevel = 1,
                        InsertionCount = CountInsertions(tr, bt, btrId),
                        StatusMessage = !exists ? "Thieu file nguon"
                            : (isLoaded ? "OK" : "Unload")
                    });
                }

                var analyzer = new XrefManager(result.Options.XrefMode);
                foreach (var w in analyzer.Analyze(result.Xrefs, result.DrawingFile))
                {
                    if (w.Code != "XREF_OK")
                        result.AddWarning(w);
                }
            }
            catch (Exception ex)
            {
                result.AddWarning(new ScanWarning
                {
                    Code = "XREF_ERROR",
                    Message = ex.Message,
                    Severity = "Warning"
                });
            }
        }

        private static int CountInsertions(Transaction tr, BlockTable bt, ObjectId blockDefId)
        {
            int count = 0;
            try
            {
                foreach (ObjectId btrId in bt)
                {
                    var btr = tr.GetObject(btrId, OpenMode.ForRead, false) as BlockTableRecord;
                    if (btr == null) continue;
                    foreach (ObjectId entId in btr)
                    {
                        var e = tr.GetObject(entId, OpenMode.ForRead, false) as BlockReference;
                        if (e != null && e.BlockTableRecord == blockDefId)
                            count++;
                    }
                }
            }
            catch (Exception) { }
            return count;
        }

        // =========================================================================
        // Deduplicate + Layer stats + Unit
        // =========================================================================
        private static ObjectIdentity BuildIdentity(Entity e, string sourceFile, string layout, bool fromXref)
        {
            return new ObjectIdentity
            {
                Handle = SafeHandle(e),
                SourceFile = sourceFile ?? "host",
                Layout = layout ?? "Model",
                Space = string.Equals(layout, "Model") ? SpaceKind.Model : SpaceKind.Paper,
                IsFromXref = fromXref
            };
        }

        private static string SafeHandle(Entity e)
        {
            try { return e.Handle.ToString(); }
            catch (Exception) { return "?"; }
        }

        private static void Deduplicate(ScanResult result)
        {
            bool keepXrefDuplicates = result.Options?.XrefMode == XrefMode.PerInsertion;

            var blockKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            result.Blocks.RemoveAll(b =>
            {
                if (keepXrefDuplicates && b.Identity?.IsFromXref == true) return false;
                var key = (b.Identity?.SourceFile ?? "") + "@" + (b.Identity?.Handle ?? "");
                return !blockKeys.Add(key);
            });

            var geomKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            result.Geometries.RemoveAll(g =>
            {
                if (keepXrefDuplicates && g.Identity?.IsFromXref == true) return false;
                var key = (g.Identity?.SourceFile ?? "") + "@" + (g.Identity?.Handle ?? "");
                return !geomKeys.Add(key);
            });
        }

        private static List<LayerStat> ComputeLayerStats(ScanResult result)
        {
            var map = new Dictionary<string, LayerStat>(StringComparer.OrdinalIgnoreCase);

            foreach (var b in result.Blocks)
            {
                if (string.IsNullOrEmpty(b.Layer)) continue;
                if (!map.TryGetValue(b.Layer, out var s))
                {
                    s = new LayerStat
                    {
                        Name = b.Layer,
                        IsFromXref = b.Identity?.IsFromXref ?? false,
                        SourceFile = b.Identity?.SourceFile
                    };
                    map[b.Layer] = s;
                }
                s.ObjectCount++;
            }
            foreach (var g in result.Geometries)
            {
                if (string.IsNullOrEmpty(g.Layer)) continue;
                if (!map.TryGetValue(g.Layer, out var s))
                {
                    s = new LayerStat
                    {
                        Name = g.Layer,
                        IsFromXref = g.Identity?.IsFromXref ?? false,
                        SourceFile = g.Identity?.SourceFile
                    };
                    map[g.Layer] = s;
                }
                s.ObjectCount++;
                s.TotalLength += g.RawLength;
            }

            return map.Values.ToList();
        }

        private static UnitInfo DetectUnit(Transaction tr, Database db)
        {
            var unit = new UnitInfo();
            try
            {
                int insUnits = (int)db.Insunits;
                switch (insUnits)
                {
                    case 0: unit.SourceUnit = DwgUnit.Unitless; unit.SourceUnitText = "Unitless"; break;
                    case 1: unit.SourceUnit = DwgUnit.Inches; unit.SourceUnitText = "in"; break;
                    case 2: unit.SourceUnit = DwgUnit.Feet; unit.SourceUnitText = "ft"; break;
                    case 4: unit.SourceUnit = DwgUnit.Millimeters; unit.SourceUnitText = "mm"; break;
                    case 5: unit.SourceUnit = DwgUnit.Centimeters; unit.SourceUnitText = "cm"; break;
                    case 6: unit.SourceUnit = DwgUnit.Meters; unit.SourceUnitText = "m"; break;
                    default: unit.SourceUnit = DwgUnit.Unknown; unit.SourceUnitText = "Unknown"; break;
                }
                unit.ConversionToMillimeter = 1.0;
                if (unit.SourceUnit == DwgUnit.Feet) unit.ConversionToMillimeter = 304.8;
                else if (unit.SourceUnit == DwgUnit.Inches) unit.ConversionToMillimeter = 25.4;
                else if (unit.SourceUnit == DwgUnit.Centimeters) unit.ConversionToMillimeter = 10.0;
                else if (unit.SourceUnit == DwgUnit.Meters) unit.ConversionToMillimeter = 1000.0;
                else if (unit.SourceUnit == DwgUnit.Millimeters) unit.ConversionToMillimeter = 1.0;
            }
            catch (Exception) { }
            return unit;
        }
    }

    /// <summary>
    /// Extension cho color index (an toan khi color = 256 = ByLayer).
    /// </summary>
    public static class EntityColorExtensions
    {
        public static int GetEntityColorIndex(this Entity e)
        {
            try { return (int)e.ColorIndex; }
            catch (Exception) { return 256; }
        }
    }
}