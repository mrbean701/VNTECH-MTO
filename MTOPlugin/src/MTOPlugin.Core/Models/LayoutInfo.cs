using System.Collections.Generic;

namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// Thong tin layout: ten, la model space hay paper space, so viewport.
    /// H? tr? tach Model/Layout va l?c khong tinh lap doi tuong qua viewport.
    /// </summary>
    public sealed class LayoutInfo
    {
        /// <summary>Ten layout.</summary>
        public string Name { get; set; }

        /// <summary>Ten block table record (model space layout co ten "Model").</summary>
        public string BlockTableRecordName { get; set; }

        public bool IsModelSpace { get; set; }

        /// <summary>So viewport trinh bay tren layout nay (paper space).</summary>
        public int ViewportCount { get; set; }

        /// <summary>Co active viewport hay khong.</summary>
        public bool HasActiveViewport { get; set; }
    }

    /// <summary>
    /// Ket qua thong ke layer. Ung voi FR02.
    /// </summary>
    public sealed class LayerStat
    {
        public string Name { get; set; }

        /// <summary>So doi tuong thuoc layer nay (blocks + geometry).</summary>
        public long ObjectCount { get; set; }

        /// <summary>Tong do dai cac doi tuong hinh hoc tren layer (DWG unit goc).</summary>
        public double TotalLength { get; set; }

        /// <summary>Mot trong cac nguon file (neu thuoc Xref).</summary>
        public string SourceFile { get; set; }

        public bool IsFromXref { get; set; }

        public override string ToString()
        {
            return string.Format("{0}: {1} doi tuong, {2:0.###} don vi",
                Name, ObjectCount, TotalLength);
        }
    }
}