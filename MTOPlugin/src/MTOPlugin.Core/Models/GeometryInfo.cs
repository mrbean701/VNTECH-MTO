namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// Thong tin mot doi tuong hinh hoc (Line, Polyline, Arc...). Ung voi FR04.
    /// </summary>
    public sealed class GeometryInfo
    {
        public GeometryKind Kind { get; set; }

        /// <summary>Do dai thuc do trong don vi ban ve (DWG unit goc).</summary>
        public double RawLength { get; set; }

        /// <summary>Ten layer.</summary>
        public string Layer { get; set; }

        /// <summary>Mau (ACI index).</summary>
        public int ColorIndex { get; set; }

        /// <summary>Kieu duong.</summary>
        public string Linetype { get; set; }

        /// <summary>Dinh tom neu doi tuong chua ho tro do.</summary>
        public string ReasonNotSupported { get; set; }

        /// <summary>Dinh danh truy vet.</summary>
        public ObjectIdentity Identity { get; set; }

        /// <summary>True neu nam trong block/xref (can ghi vao ke t qu de truy)</summary>
        public bool IsNested { get; set; }

        public override string ToString()
        {
            return string.Format("{0}:{1} len={2:0.###}",
                Kind, Layer, RawLength);
        }
    }
}