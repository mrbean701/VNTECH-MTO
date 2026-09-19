using System;
using System.Collections.Generic;

namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// C?u hinh mot lan quet. Duoc tao ra tu UI (FR01) va ghi vao nhat ky (FR10).
    /// </summary>
    public sealed class ScanOptions
    {
        public ScanScope Scope { get; set; } = ScanScope.ModelAndAllLayouts;

        public XrefMode XrefMode { get; set; } = XrefMode.UniqueBySource;

        public string RulesFilePath { get; set; }

        public string OutputFilePath { get; set; }

        public UnitInfo Unit { get; set; } = new UnitInfo();

        /// <summary>True neu can quet ca doi tuong nam ben trong block/xref (de recursive).</summary>
        public bool ScanNestedBlocks { get; set; } = true;

        /// <summary>Doi tuong thuoc cac layer tat/thu-dong se duoc bo qua?</summary>
        public bool SkipFrozenLayers { get; set; } = true;
    }

    /// <summary>
    /// Canh bao hoac loi xuat hien trong qua trinh quet. Ung voi sheet CANH_BAO_LOI.
    /// </summary>
    public sealed class ScanWarning
    {
        public string Code { get; set; }

        public string Message { get; set; }

        public string SourceFile { get; set; }

        public string Layout { get; set; }

        public string Layer { get; set; }

        public string Handle { get; set; }

        public string ObjectDetail { get; set; }

        public string Severity { get; set; } = "Warning";

        public override string ToString()
        {
            return string.Format("[{0}] {1}", Code, Message);
        }
    }

    /// <summary>
    /// Ket qua tong the cua mot lan quet: cac doi tuong, thong ke, canh bao.
    /// Truyen ra tu Scanner (trong AutoCAD) va duoc Classification/Export xu ly.
    /// </summary>
    public sealed class ScanResult
    {
        public string DrawingFile { get; set; }

        public DateTime RunAtUtc { get; set; } = DateTime.UtcNow;

        public ScanOptions Options { get; set; } = new ScanOptions();

        public UnitInfo Unit { get; set; }

        public List<BlockReferenceInfo> Blocks { get; } = new List<BlockReferenceInfo>();

        public List<GeometryInfo> Geometries { get; } = new List<GeometryInfo>();

        public List<LayerStat> Layers { get; } = new List<LayerStat>();

        public List<LayoutInfo> Layouts { get; } = new List<LayoutInfo>();

        public List<XrefReference> Xrefs { get; } = new List<XrefReference>();

        public List<ScanWarning> Warnings { get; } = new List<ScanWarning>();

        public long TotalEntitiesScanned { get; set; }

        /// <summary>So doi tuong khong hop le/bi loi khi doc.</summary>
        public long ErrorCount { get; set; }

        public string ErrorMessage { get; set; }

        public TimeSpan ScanDuration { get; set; }

        public bool Success => string.IsNullOrEmpty(ErrorMessage);

        public void AddWarning(ScanWarning w) => Warnings.Add(w);
    }
}