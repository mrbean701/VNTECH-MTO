using System.Collections.Generic;

namespace MTOPlugin.Core.Rules
{
    /// <summary>
    /// Dieu kien nhan dang doi tuong cho mot quy tac.
    /// Tat ca dieu kien trong mot quy tac duoc AND voi nhau.
    /// Cac gia tri * tai mot truong co nghia "bat ky".
    /// </summary>
    public sealed class RuleCondition
    {
        /// <summary>Muc them mat loai doi tuong: block hoac geometry hoac both.</summary>
        public string EntityKind { get; set; } = "*";

        /// <summary>Layer. H? tro danh sach phan cach bang ";".</summary>
        public string Layers { get; set; } = "*";

        /// <summary>Ten block (acid patterns voi '*' hoac danh sach ';').</summary>
        public string BlockNames { get; set; } = "*";

        /// <summary>Ten dynamic block hoat dong (neu co).</summary>
        public string EffectiveBlockNames { get; set; } = "*";

        /// <summary>Thu?c tinh block: key=value; doi voi bieu thuc gia tri dung dau '~' de nguoc.</summary>
        public string Attributes { get; set; }

        /// <summary>Loai hinh hoc duoc ho tro (Line, Polyline, Arc...). Dau '*' la bat ky.</summary>
        public string GeometryKinds { get; set; } = "*";

        /// <summary>Kieu duong.</summary>
        public string Linetypes { get; set; } = "*";

        /// <summary>Mau ACI: so hoac danh sach '1;2;3'.</summary>
        public string ColorIndexes { get; set; } = "*";

        /// <summary>Bieu thuc regex ap dung len ten block/effective name.</summary>
        public string BlockNameRegex { get; set; }

        /// <summary>Regex ap dung len layer.</summary>
        public string LayerRegex { get; set; }

        /// <summary>Kiem tra dynamic block co do dai bat ky?</summary>
        public bool? RequireDynamicBlock { get; set; }

        /// <summary>Dieu kien dynamic property (ten thuoc tinh, phep so sanh, gia tri).</summary>
        public DynamicPropertyCondition DynamicProperty { get; set; }

        public override string ToString()
        {
            var parts = new List<string>();
            if (Layers != "*") parts.Add("Layer: " + Layers);
            if (BlockNames != "*") parts.Add("Block: " + BlockNames);
            if (EffectiveBlockNames != "*") parts.Add("EffBlock: " + EffectiveBlockNames);
            if (Attributes != null) parts.Add("Attr: " + Attributes);
            if (GeometryKinds != "*") parts.Add("Geom: " + GeometryKinds);
            if (Linetypes != "*") parts.Add("LT: " + Linetypes);
            if (ColorIndexes != "*") parts.Add("Color: " + ColorIndexes);
            if (BlockNameRegex != null) parts.Add("Regex: " + BlockNameRegex);
            if (LayerRegex != null) parts.Add("LayerRx: " + LayerRegex);
            return string.Join("; ", parts);
        }
    }

    /// <summary>
    /// Dieu kien kiem tra dynamic property cua dynamic block.
    /// VD: PropertyName="Visibility", Operator="equals", Value="TypeA".
    /// </summary>
    public sealed class DynamicPropertyCondition
    {
        /// <summary>Ten thuoc tinh dynamic.</summary>
        public string PropertyName { get; set; }

        /// <summary>Phep so sanh: equals, contains, greaterThan, lessThan.</summary>
        public string Operator { get; set; } = "equals";

        /// <summary>Gia tri so sanh.</summary>
        public string Value { get; set; }
    }
}