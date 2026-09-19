using System.Collections.Generic;
using System;

namespace MTOPlugin.Core.Rules
{
    /// <summary>
    /// Cach tinh khoi luong cho cac doi tuong khop quy tac.
    /// </summary>
    public enum CalculationKind
    {
        /// <summary>Dem so luong doi tuong (blocks).</summary>
        Count = 0,

        /// <summary>Cong chieu dai (geometry).</summary>
        SumLength = 1,

        /// <summary>Cong chieu dai roi nhan he so.</summary>
        SumLengthTimesFactor = 2,

        /// <summary>Cong chieu dai, lam tron len theo buoc (vd con cot than).</summary>
        SumLengthCeilingStep = 3,

        /// <summary>Sum of attribute numeric value (doc tu attribute 'ATTRIB').</summary>
        SumAttributeValue = 4,

        /// <summary>Dem doi tuong khi attribute khop gia tri (vd: den 10W). Su dung AttributeCondition.</summary>
        CountIfAttributeEquals = 5
    }

    /// <summary>
    /// Trang thai cua quy tac. Luu tru lien quan phan duyet quy trinh.
    /// </summary>
    public enum RuleStatus
    {
        Draft = 0,
        Active = 1,
        Paused = 2
    }

    /// <summary>
    /// Cau truc mot quy tac boc tach. Ung voi FR06.
    /// </summary>
    public sealed class RuleDefinition
    {
        /// <summary>Ma quy tac duy nhat, vd R-DIEN-001.</summary>
        public string Code { get; set; }

        /// <summary>Phien ban quy tac, vd "1.2".</summary>
        public string Version { get; set; } = "1.0";

        /// <summary>Mo ta ngu canh nghiep vu.</summary>
        public string Description { get; set; }

        /// <summary>Ma he M&E (HE-DIEN, HE-NUOC...).</summary>
        public string SystemCode { get; set; }

        /// <summary>Danh muc vat tu / cong viec.</summary>
        public string MaterialCode { get; set; }

        /// <summary>Ten vat tu / cong viec.</summary>
        public string MaterialName { get; set; }

        /// <summary>Quy cach ky thuat (VD: "PVC D20", "Day CV 1x2.5mm2").</summary>
        public string Specification { get; set; }

        /// <summary>Don vi tinh khoi luong (cai, m, m2...).</summary>
        public string Unit { get; set; }

        /// <summary>Dieu kien nhan dang.</summary>
        public List<RuleCondition> Conditions { get; set; } = new List<RuleCondition>();

        /// <summary>Cach khai bao khoi luong.</summary>
        public CalculationKind Calculation { get; set; } = CalculationKind.Count;

        /// <summary>He so quy doi (dung khi Calculation = SumLengthTimesFactor).</summary>
        public double Factor { get; set; } = 1.0;

        /// <summary>Buoc lam tron (dung khi Calculation = SumLengthCeilingStep).</summary>
        public double CeilingStep { get; set; } = 0.0;

        /// <summary>Ten attribute khi Calculation = SumAttributeValue.</summary>
        public string SumAttribute { get; set; }

        /// <summary>Uu tien: so lon hon dung truoc khi mot doi tuong khop nhieu quy tac.</summary>
        public int Priority { get; set; } = 100;

        public RuleStatus Status { get; set; } = RuleStatus.Active;

        /// <summary>Ten nguoi khai bao quy tac.</summary>
        public string CreatedBy { get; set; }

        public DateTime CreatedAt { get; set; }

        /// <summary>Nguoi xac nhan quy tac (ky su M&E).</summary>
        public string ApprovedBy { get; set; }

        public DateTime? ApprovedAt { get; set; }

        /// <summary>Quy tac chi ap dung khi doi tuong nam trong Xref? null = mac dinh.</summary>
        public bool? ApplyToXrefOnly { get; set; }

        /// <summary>Dieu kien attribute cho CountIfAttributeEquals.</summary>
        public AttributeCondition AttributeCondition { get; set; }

        public override string ToString()
        {
            return string.Format("{0} v{1}: {2}", Code, Version, MaterialName);
        }
    }

    /// <summary>
    /// Dieu kien attribute cho CalculationKind.CountIfAttributeEquals.
    /// Cho phep dem doi tuong khi attribute khop (equals/notEquals/contains/greaterThan/lessThan).
    /// </summary>
    public sealed class AttributeCondition
    {
        /// <summary>Ten attribute can kiem tra.</summary>
        public string Attribute { get; set; }

        /// <summary>Phep so sanh: equals, notEquals, contains, greaterThan, lessThan.</summary>
        public string Operator { get; set; } = "equals";

        /// <summary>Gia tri so sanh.</summary>
        public string Value { get; set; }

        /// <summary>Hanh dong: include (dem), exclude (loai tru), extract (trich xuat).</summary>
        public string Action { get; set; } = "include";
    }
}