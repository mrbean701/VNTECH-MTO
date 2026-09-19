using System.Collections.Generic;

namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// Thong tin mot block reference doc duoc tu ban ve. Ung voi FR03.
    /// </summary>
    public sealed class BlockReferenceInfo
    {
        /// <summary>Ten khoi goc cua block definition.</summary>
        public string BlockName { get; set; }

        /// <summary>Ten hien thi (dynamic block: ten hien tai sau khi bien doi).</summary>
        public string EffectiveName { get; set; }

        /// <summary>Co phai dynamic block khong.</summary>
        public bool IsDynamic { get; set; }

        /// <summary>Dynamic block name tra ve khi IsDynamic = true.</summary>
        public string DynamicBlockName { get; set; }

        /// <summary>Co phai xref reference block khong.</summary>
        public bool IsXref { get; set; }

        /// <summary>Ten layer cua block reference.</summary>
        public string Layer { get; set; }

        /// <summary>Mau so (ACI index).</summary>
        public int ColorIndex { get; set; }

        /// <summary>Kieu duong.</summary>
        public string Linetype { get; set; }

        /// <summary>He so ti le truc X/Y/Z.</summary>
        public double ScaleX { get; set; } = 1.0;
        public double ScaleY { get; set; } = 1.0;
        public double ScaleZ { get; set; } = 1.0;

        /// <summary>Goc quay (radian).</summary>
        public double RotationRadians { get; set; }

        /// <summary>Toa do insert (dwg unit goc).</summary>
        public double PositionX { get; set; }
        public double PositionY { get; set; }
        public double PositionZ { get; set; }

        /// <summary>Thu?c tinh block du?c khai bao san (hv DGN).</summary>
        public Dictionary<string, string> Attributes { get; set; }
            = new Dictionary<string, string>();

        /// <summary>Thuoc tinh dynamic block (ten property -> gia tri). Chi co gia tri khi IsDynamic=true.</summary>
        public Dictionary<string, object> DynamicProperties { get; set; }
            = new Dictionary<string, object>();

        /// <summary>Dinh danh de truy vet.</summary>
        public ObjectIdentity Identity { get; set; }

        /// <summary>Tinh buoc (tay do con tro seal va ops).</summary>
        public bool IsNested { get; set; }

        public object Clone()
        {
            var c = (BlockReferenceInfo)MemberwiseClone();
            c.Attributes = new Dictionary<string, string>(Attributes);
            c.Identity = Identity;
            return c;
        }
    }
}