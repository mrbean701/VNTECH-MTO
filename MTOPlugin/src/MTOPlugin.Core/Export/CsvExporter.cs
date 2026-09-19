using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using MTOPlugin.Core.Classification;

namespace MTOPlugin.Core.Export
{
    /// <summary>
    /// Xuat ket qua phan loai ra file CSV (UTF-8 BOM).
    /// Ho tro: Summary, Details, Unclassified.
    /// </summary>
    public sealed class CsvExporter
    {
        /// <summary>
        /// Xuat TONG_HOP ra CSV.
        /// </summary>
        public void ExportSummary(ClassificationResult result, string filePath)
        {
            if (result == null) throw new ArgumentNullException(nameof(result));

            var dir = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            using (var writer = new StreamWriter(filePath, false, new UTF8Encoding(true)))
            {
                writer.WriteLine("STT,Ma he,Ten he,Ma vat tu,Ten vat tu,Quy cach,Don vi,Khoi luong,So doi tuong,Trang thai");
                int idx = 1;
                foreach (var s in result.Summary)
                {
                    writer.WriteLine(string.Format("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}",
                        idx++,
                        Csv(s.SystemCode),
                        Csv(s.MaterialName),
                        Csv(s.MaterialCode),
                        Csv(s.MaterialName),
                        Csv(s.Specification),
                        Csv(s.Unit),
                        Math.Round(s.TotalQuantity, 3),
                        s.ObjectCount,
                        Csv(s.StatusMessage)));
                }
            }
        }

        /// <summary>
        /// Xuat CHI_TIET ra CSV.
        /// </summary>
        public void ExportDetails(ClassificationResult result, string filePath)
        {
            if (result == null) throw new ArgumentNullException(nameof(result));

            var dir = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            using (var writer = new StreamWriter(filePath, false, new UTF8Encoding(true)))
            {
                writer.WriteLine("STT,File,Layer,Loai,Block,Block hoat dong,Thuoc tinh,Chieu dai goc,Don vi goc,Chieu dai quy doi,Don vi quy doi,Cach tinh,Ma quy tac,Ma he,Ma vat tu,Ten vat tu,Quy cach,Don vi tinh,Khoi luong,Handle");
                int idx = 1;
                foreach (var d in result.Details)
                {
                    writer.WriteLine(string.Format("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16},{17},{18},{19}",
                        idx++,
                        Csv(d.DrawingFile),
                        Csv(d.Layer),
                        Csv(d.ObjectType),
                        Csv(d.BlockName),
                        Csv(d.EffectiveBlockName),
                        Csv(d.AttributesJson),
                        Math.Round(d.RawLength, 3),
                        Csv(d.RawUnit),
                        Math.Round(d.ConvertedLength, 3),
                        Csv(d.ConvertedUnit),
                        Csv(d.CalculationMethod),
                        Csv(d.RuleCode),
                        Csv(d.SystemCode),
                        Csv(d.MaterialCode),
                        Csv(d.MaterialName),
                        Csv(d.Specification),
                        Csv(d.Unit),
                        Math.Round(d.Quantity, 3),
                        Csv(d.Handle)));
                }
            }
        }

        private static string Csv(string value)
        {
            if (string.IsNullOrEmpty(value)) return "";
            if (value.Contains(",") || value.Contains("\"") || value.Contains("\n"))
                return "\"" + value.Replace("\"", "\"\"") + "\"";
            return value;
        }
    }
}
