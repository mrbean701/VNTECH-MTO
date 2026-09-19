using System;
using System.Collections.Generic;
using System.Linq;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;

namespace MTOPlugin.Core.Classification
{
    /// <summary>
    /// Dau ra cua mot chi tiet: doi tuong da duoc gan vao v?t tu/cong viec nao do.
    /// Luu vao sheet CHI_TIET trong Excel.
    /// </summary>
    public sealed class ClassifiedDetail
    {
        public string DrawingFile { get; set; }
        public string Handle { get; set; }
        public string Layer { get; set; }
        public string ObjectType { get; set; }

        /// <summary>Ten block (block reference).</summary>
        public string BlockName { get; set; }

        /// <summary>Ten hien thi (dynamic block).</summary>
        public string EffectiveBlockName { get; set; }

        public string AttributesJson { get; set; }

        public double RawLength { get; set; }

        public string RawUnit { get; set; }

        public double ConvertedLength { get; set; }

        public string ConvertedUnit { get; set; }

        public string CalculationMethod { get; set; }

        public string RuleCode { get; set; }

        public string SystemCode { get; set; }

        public string MaterialCode { get; set; }

        public string MaterialName { get; set; }

        public string Specification { get; set; }

        public string Unit { get; set; }

        public double Quantity { get; set; }

        public string SourceFile { get; set; }

        public string Layout { get; set; }

        public string SpaceKind { get; set; }

        public bool IsFromXref { get; set; }

        public string XrefBlockName { get; set; }

        public string Status { get; set; } = "OK";
    }

    /// <summary>
    /// Dong tong hop: moi vat tu/công viec gop vao mot dong duy nhat voi tong khoi luong.
    /// Luu vao sheet TONG_HOP.
    /// </summary>
    public sealed class SummaryRow
    {
        public string SystemCode { get; set; }

        public string MaterialCode { get; set; }

        public string MaterialName { get; set; }

        public string Specification { get; set; }

        public string Unit { get; set; }

        public double TotalQuantity { get; set; }

        public long ObjectCount { get; set; }

        public string StatusMessage { get; set; }

        public List<ClassifiedDetail> Details { get; } = new List<ClassifiedDetail>();
    }

    /// <summary>
    /// Doi tuong chua phan loai: duoc ho tro nhung khong khop bat ky quy tac nao.
    /// Luu vao sheet CHUA_PHAN_LOAI.
    /// </summary>
    public sealed class UnclassifiedItem
    {
        public string DrawingFile { get; set; }

        public string Handle { get; set; }

        public string Layer { get; set; }

        public string ObjectType { get; set; }

        public string BlockName { get; set; }

        public string EffectiveBlockName { get; set; }

        public string AttributesJson { get; set; }

        public double RawLength { get; set; }

        public string SpaceKind { get; set; }

        public string Layout { get; set; }

        public string SourceFile { get; set; }

        public string Reason { get; set; } = "Chua phu hop voi quy tac nao";

        public string SuggestedMapping { get; set; }
    }

    /// <summary>
    /// Ket qua phan loai tong the cua mot lan quet.
    /// </summary>
    public sealed class ClassificationResult
    {
        public string RuleSetVersion { get; set; }

        public DateTime RunAtUtc { get; set; } = DateTime.UtcNow;

        public string DrawingFile { get; set; }

        public List<SummaryRow> Summary { get; } = new List<SummaryRow>();

        public List<ClassifiedDetail> Details { get; } = new List<ClassifiedDetail>();

        public List<UnclassifiedItem> Unclassified { get; } = new List<UnclassifiedItem>();

        public long TotalEntities { get; set; }

        public long ClassifiedCount => Details.Count;

        public long UnclassifiedCount => Unclassified.Count;

        public double ClassificationRate =>
            TotalEntities > 0 ? (double)ClassifiedCount / TotalEntities * 100.0 : 0.0;
    }
}