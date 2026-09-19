using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Models;
using OfficeOpenXml;

namespace MTOPlugin.Core.Export
{
    /// <summary>
    /// Xuat ket qua ra file XLSX voi 5 sheet: TONG_HOP, CHI_TIET, CHUA_PHAN_LOAI,
    /// CANH_BAO_LOI, THONG_TIN_LAN_QUET. Ung voi FR08.
    /// Nguyen tac: khong xuat file Excel trong. Neu khong co du lieu hop le,
    /// phai thong bao nguyen nhan.
    /// </summary>
    public sealed class ExcelExporter
    {
        private const string SheetTongHop = "TONG_HOP";
        private const string SheetChiTiet = "CHI_TIET";
        private const string SheetChuaPhanLoai = "CHUA_PHAN_LOAI";
        private const string SheetCanhBao = "CANH_BAO_LOI";
        private const string SheetThongTin = "THONG_TIN_LAN_QUET";

        /// <summary>
        /// Xuat full file xlsx (toan bo du lieu lan quet).
        /// </summary>
        public void Export(ScanResult scan, ClassificationResult classification, string filePath)
        {
            ExportTo(scan, classification, filePath, null);
        }

        /// <summary>
        /// Xuat file xlsx co chon loc. selectedKeys là tap key dang
        /// "SourceFile@Handle" (chuoi key cung cach voi key trong Core). Neu null -> xuat toan bo.
        /// TONG_HOP duoc tinh lai tu chi tiet da lọc; CHUA_PHAN_LOAI chi ghi cac muc duoc chọn.
        /// </summary>
        public void ExportTo(ScanResult scan, ClassificationResult classification, string filePath,
            ICollection<string> selectedKeys)
        {
            if (scan == null || classification == null)
                throw new ArgumentNullException("scan/classification");

            // Nguyen tac: khong xuat file trong khong ro nguyen nhan
            EnsureUsableData(scan, classification);

            if (selectedKeys == null)
                selectedKeys = BuildFullKeySet(classification);
            if (selectedKeys.Count == 0)
                throw new ExcelExportException("Chua chon muc nao de xuat Excel.");

            var details = FilterDetails(classification, selectedKeys);
            var unclassified = FilterUnclassified(classification, selectedKeys);
            if (details.Count == 0 && unclassified.Count == 0)
                throw new ExcelExportException(
                    "Cac muc duoc chon khong con du lieu hop le de xuat Excel.");

            bool selective = IsSelective(classification, selectedKeys);
            int exportedItems = details.Count + unclassified.Count;

            var dir = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            using (var pkg = new ExcelPackage(new FileInfo(filePath)))
            {
                var wsTotal = pkg.Workbook.Worksheets.Add(SheetTongHop);
                WriteSummary(wsTotal, details, classification.Summary);

                var wsDetail = pkg.Workbook.Worksheets.Add(SheetChiTiet);
                WriteDetail(wsDetail, details);

                var wsUnclassified = pkg.Workbook.Worksheets.Add(SheetChuaPhanLoai);
                WriteUnclassified(wsUnclassified, unclassified);

                var wsWarning = pkg.Workbook.Worksheets.Add(SheetCanhBao);
                WriteWarnings(wsWarning, scan);

                var wsInfo = pkg.Workbook.Worksheets.Add(SheetThongTin);
                WriteScanInfo(wsInfo, scan, classification, selective, exportedItems);

                foreach (var ws in pkg.Workbook.Worksheets)
                {
                    if (ws.Dimension != null)
                        ws.Cells[ws.Dimension.Address].AutoFitColumns();
                }

                pkg.Save();
            }
        }

        private static string KeyOf(string sourceFile, string handle)
        {
            return (sourceFile ?? "") + "@" + (handle ?? "");
        }

        private static HashSet<string> BuildFullKeySet(ClassificationResult classification)
        {
            var set = new HashSet<string>();
            foreach (var d in classification.Details)
                set.Add(KeyOf(d.SourceFile, d.Handle));
            foreach (var u in classification.Unclassified)
                set.Add(KeyOf(u.SourceFile, u.Handle));
            return set;
        }

        private static bool IsSelective(ClassificationResult classification, ICollection<string> selectedKeys)
        {
            if (selectedKeys.Count != BuildFullKeySet(classification).Count)
                return true;
            foreach (var k in selectedKeys)
                if (!BuildFullKeySet(classification).Contains(k))
                    return true;
            return false;
        }

        private static List<ClassifiedDetail> FilterDetails(ClassificationResult classification, ICollection<string> selectedKeys)
        {
            var set = new HashSet<string>(selectedKeys);
            var list = new List<ClassifiedDetail>();
            foreach (var d in classification.Details)
                if (set.Contains(KeyOf(d.SourceFile, d.Handle)))
                    list.Add(d);
            return list;
        }

        private static List<UnclassifiedItem> FilterUnclassified(ClassificationResult classification, ICollection<string> selectedKeys)
        {
            var set = new HashSet<string>(selectedKeys);
            var list = new List<UnclassifiedItem>();
            foreach (var u in classification.Unclassified)
                if (set.Contains(KeyOf(u.SourceFile, u.Handle)))
                    list.Add(u);
            return list;
        }

        private static void EnsureUsableData(ScanResult scan, ClassificationResult classification)
        {
            if (!scan.Success)
                throw new ExcelExportException(
                    "Loi quet ban ve: " + scan.ErrorMessage +
                    ". Khong xuat file Excel.");

            var totalObjects = scan.Blocks.Count + scan.Geometries.Count;
            if (totalObjects == 0)
                throw new ExcelExportException(
                    "Pham vi quet khong co doi tuong hop le nao. Khong xuat file Excel.");

            if (classification.Details.Count == 0 && classification.Unclassified.Count == 0)
                throw new ExcelExportException(
                    "Khong co doi tuong nao duoc phan loai ho?c dua vao danh sach chua phan loai. " +
                    "Kiem tra bo quy tac hoac pham vi quet.");
        }

        // ------------------------------------------------------------------ TONG_HOP
        private static void WriteSummary(ExcelWorksheet ws, List<ClassifiedDetail> details, List<SummaryRow> originalSummary)
        {
            ws.Cells[1, 1].Value = "Ma he";
            ws.Cells[1, 2].Value = "Ma vat tu";
            ws.Cells[1, 3].Value = "Ten vat tu/cong viec";
            ws.Cells[1, 4].Value = "Quy cach";
            ws.Cells[1, 5].Value = "Don vi";
            ws.Cells[1, 6].Value = "Khoi luong";
            ws.Cells[1, 7].Value = "So doi tuong";
            ws.Cells[1, 8].Value = "Trang thai";

            var statusMap = new Dictionary<string, string>();
            if (originalSummary != null)
            {
                foreach (var s in originalSummary)
                    foreach (var d in s.Details)
                        statusMap[KeyOf(d.SourceFile, d.Handle)] = s.StatusMessage;
            }

            int row = 2;
            foreach (var g in details
                .GroupBy(d => new { d.SystemCode, d.MaterialCode, d.MaterialName, d.Specification, d.Unit })
                .OrderBy(x => x.Key.SystemCode).ThenBy(x => x.Key.MaterialName))
            {
                string status = null;
                foreach (var d in g)
                {
                    if (statusMap.TryGetValue(KeyOf(d.SourceFile, d.Handle), out status))
                        break;
                }

                ws.Cells[row, 1].Value = g.Key.SystemCode;
                ws.Cells[row, 2].Value = g.Key.MaterialCode;
                ws.Cells[row, 3].Value = g.Key.MaterialName;
                ws.Cells[row, 4].Value = g.Key.Specification;
                ws.Cells[row, 5].Value = g.Key.Unit;
                ws.Cells[row, 6].Value = Math.Round(g.Sum(x => x.Quantity), 3);
                ws.Cells[row, 7].Value = g.Count();
                ws.Cells[row, 8].Value = status ?? "OK";
                row++;
            }
        }

        // ------------------------------------------------------------------ CHI_TIET
        private static void WriteDetail(ExcelWorksheet ws, List<ClassifiedDetail> details)
        {
            ws.Cells[1, 1].Value = "File";
            ws.Cells[1, 2].Value = "Xref nguon";
            ws.Cells[1, 3].Value = "Model/Layout";
            ws.Cells[1, 4].Value = "Layer";
            ws.Cells[1, 5].Value = "Loai";
            ws.Cells[1, 6].Value = "Block";
            ws.Cells[1, 7].Value = "Block hoat dong";
            ws.Cells[1, 8].Value = "Thuoc tinh";
            ws.Cells[1, 9].Value = "Chieu dai goc";
            ws.Cells[1, 10].Value = "Don vi goc";
            ws.Cells[1, 11].Value = "Chieu dai quy doi";
            ws.Cells[1, 12].Value = "Don vi quy doi";
            ws.Cells[1, 13].Value = "Cach tinh";
            ws.Cells[1, 14].Value = "Ma quy tac";
            ws.Cells[1, 15].Value = "Ma he";
            ws.Cells[1, 16].Value = "Ma vat tu";
            ws.Cells[1, 17].Value = "Ten vat tu";
            ws.Cells[1, 18].Value = "Quy cach";
            ws.Cells[1, 19].Value = "Don vi tinh";
            ws.Cells[1, 20].Value = "Khoi luong";
            ws.Cells[1, 21].Value = "Handle";

            int row = 2;
            foreach (var d in details)
            {
                ws.Cells[row, 1].Value = d.DrawingFile;
                ws.Cells[row, 2].Value = d.XrefBlockName;
                ws.Cells[row, 3].Value = d.SpaceKind + "/" + d.Layout;
                ws.Cells[row, 4].Value = d.Layer;
                ws.Cells[row, 5].Value = d.ObjectType;
                ws.Cells[row, 6].Value = d.BlockName;
                ws.Cells[row, 7].Value = d.EffectiveBlockName;
                ws.Cells[row, 8].Value = d.AttributesJson;
                ws.Cells[row, 9].Value = Math.Round(d.RawLength, 3);
                ws.Cells[row, 10].Value = d.RawUnit;
                ws.Cells[row, 11].Value = Math.Round(d.ConvertedLength, 3);
                ws.Cells[row, 12].Value = d.ConvertedUnit;
                ws.Cells[row, 13].Value = d.CalculationMethod;
                ws.Cells[row, 14].Value = d.RuleCode;
                ws.Cells[row, 15].Value = d.SystemCode;
                ws.Cells[row, 16].Value = d.MaterialCode;
                ws.Cells[row, 17].Value = d.MaterialName;
                ws.Cells[row, 18].Value = d.Specification;
                ws.Cells[row, 19].Value = d.Unit;
                ws.Cells[row, 20].Value = Math.Round(d.Quantity, 3);
                ws.Cells[row, 21].Value = d.Handle;
                row++;
            }
        }

        // ------------------------------------------------------------------ CHUA_PHAN_LOAI
        private static void WriteUnclassified(ExcelWorksheet ws, List<UnclassifiedItem> unclassified)
        {
            ws.Cells[1, 1].Value = "File";
            ws.Cells[1, 2].Value = "Handle";
            ws.Cells[1, 3].Value = "Layer";
            ws.Cells[1, 4].Value = "Loai";
            ws.Cells[1, 5].Value = "Block";
            ws.Cells[1, 6].Value = "Block hoat dong";
            ws.Cells[1, 7].Value = "Thuoc tinh";
            ws.Cells[1, 8].Value = "Chieu dai goc";
            ws.Cells[1, 9].Value = "Model/Layout";
            ws.Cells[1, 10].Value = "Nguon (Xref)";
            ws.Cells[1, 11].Value = "Nguyen nhan";
            ws.Cells[1, 12].Value = "Goi y anh xa";

            int row = 2;
            foreach (var u in unclassified)
            {
                ws.Cells[row, 1].Value = u.DrawingFile;
                ws.Cells[row, 2].Value = u.Handle;
                ws.Cells[row, 3].Value = u.Layer;
                ws.Cells[row, 4].Value = u.ObjectType;
                ws.Cells[row, 5].Value = u.BlockName;
                ws.Cells[row, 6].Value = u.EffectiveBlockName;
                ws.Cells[row, 7].Value = u.AttributesJson;
                ws.Cells[row, 8].Value = Math.Round(u.RawLength, 3);
                ws.Cells[row, 9].Value = u.Layout;
                ws.Cells[row, 10].Value = u.SourceFile;
                ws.Cells[row, 11].Value = u.Reason;
                ws.Cells[row, 12].Value = u.SuggestedMapping;
                row++;
            }
        }

        // ------------------------------------------------------------------ CANH_BAO_LOI
        private static void WriteWarnings(ExcelWorksheet ws, ScanResult scan)
        {
            ws.Cells[1, 1].Value = "Ma canh bao";
            ws.Cells[1, 2].Value = "Muc do";
            ws.Cells[1, 3].Value = "Noi dung";
            ws.Cells[1, 4].Value = "File";
            ws.Cells[1, 5].Value = "Layout";
            ws.Cells[1, 6].Value = "Layer";
            ws.Cells[1, 7].Value = "Handle";

            int row = 2;
            foreach (var w in scan.Warnings)
            {
                ws.Cells[row, 1].Value = w.Code;
                ws.Cells[row, 2].Value = w.Severity;
                ws.Cells[row, 3].Value = w.Message;
                ws.Cells[row, 4].Value = w.SourceFile;
                ws.Cells[row, 5].Value = w.Layout;
                ws.Cells[row, 6].Value = w.Layer;
                ws.Cells[row, 7].Value = w.Handle;
                row++;
            }

            if (scan.Warnings.Count == 0)
            {
                ws.Cells[2, 3].Value = "Khong co canh bao hoac loi trong lan quet nay.";
            }
        }

        // ------------------------------------------------------------------ THONG_TIN_LAN_QUET
        private static void WriteScanInfo(ExcelWorksheet ws, ScanResult scan, ClassificationResult result,
            bool selective, int exportedItems)
        {
            string[,] rows =
            {
                { "Ten ban ve", scan.DrawingFile },
                { "Thoi gian chay", scan.RunAtUtc.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss") },
                { "Nguoi chay", Environment.UserName },
                { "Pham vi quet", scan.Options.Scope.ToString() },
                { "Che do Xref", scan.Options.XrefMode.ToString() },
                { "Tong so doi tuong quet", scan.TotalEntitiesScanned.ToString() },
                { "So doi tuong phan loai", result.ClassifiedCount.ToString() },
                { "So doi tuong chua phan loai", result.UnclassifiedCount.ToString() },
                { "Ti le phan loai", result.ClassificationRate.ToString("0.00") + "%" },
                { "Phien ban plugin", GetPluginVersion() },
                { "Phien ban bo quy tac", result.RuleSetVersion },
                { "Don vi nguon", scan.Unit?.SourceUnitText ?? "Unknown" },
                { "Don vi xuat", scan.Unit?.OutputUnit ?? "mm" },
                { "Thoi gian quet", scan.ScanDuration.TotalSeconds.ToString("0.0") + " s" },
                { "So loi", scan.ErrorCount.ToString() },
                { "Kieu xuat", selective ? "Chon loc" : "Toan bo" },
                { "So muc da xuat", exportedItems.ToString() }
            };

            int row = 1;
            for (int i = 0; i < rows.GetLength(0); i++)
            {
                ws.Cells[row, 1].Value = rows[i, 0];
                ws.Cells[row, 2].Value = rows[i, 1];
                row++;
            }
        }

        private static string GetPluginVersion()
        {
            var asm = typeof(ExcelExporter).Assembly;
            var v = asm.GetName().Version;
            return v == null ? "0.0.0" : v.ToString();
        }
    }

    /// <summary>
    /// Ngoai le khi xuat Excel (vd: khong duoc tao file trong).
    /// </summary>
    public sealed class ExcelExportException : Exception
    {
        public ExcelExportException(string message) : base(message) { }
    }
}