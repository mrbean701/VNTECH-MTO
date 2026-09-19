using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Export;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;
using MTOPlugin.Core.Unit;

namespace MTOPlugin.Core.Batch
{
    /// <summary>
    /// Xu ly batch nhieu file DWG. Nhan tu ngoai vao danh sach ScanResult da quet,
    /// phan loai va xuat Excel gop hoac rieng. Khong phu thuoc AutoCAD API.
    /// </summary>
    public sealed class BatchEngine
    {
        private readonly RuleSet _ruleSet;
        private readonly UnitInfo _unit;

        public BatchEngine(RuleSet ruleSet, UnitInfo unit)
        {
            _ruleSet = ruleSet ?? throw new ArgumentNullException(nameof(ruleSet));
            _unit = unit ?? new UnitInfo();
        }

        /// <summary>
        /// Xu ly batch: phan loai tung file, xuat Excel gop hoac rieng.
        /// </summary>
        public BatchResult Process(List<ScanResult> scans, BatchOptions options)
        {
            if (scans == null || scans.Count == 0)
                throw new ArgumentException("Khong co file nao de xu ly batch.");

            var result = new BatchResult
            {
                TotalFiles = scans.Count,
                StartTime = DateTime.UtcNow
            };

            var allClassifications = new List<ClassificationResult>();

            foreach (var scan in scans)
            {
                try
                {
                    var engine = new ClassificationEngine(_ruleSet, scan.Unit ?? _unit);
                    var classification = engine.Classify(scan);
                    allClassifications.Add(classification);

                    result.FileResults.Add(new FileResult
                    {
                        FileName = scan.DrawingFile,
                        TotalScanned = scan.TotalEntitiesScanned,
                        Classified = classification.ClassifiedCount,
                        Unclassified = classification.UnclassifiedCount,
                        ClassificationRate = classification.ClassificationRate,
                        Success = scan.Success,
                        ErrorMessage = scan.ErrorMessage
                    });

                    // Xuat rieng tung file
                    if (options.ExportPerFile)
                    {
                        var perFile = Path.Combine(options.OutputFolder,
                            "MTO_" + Path.GetFileNameWithoutExtension(scan.DrawingFile) + "_" +
                            DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".xlsx");
                        var exporter = new ExcelExporter();
                        exporter.Export(scan, classification, perFile);
                        result.OutputFiles.Add(perFile);
                    }
                }
                catch (Exception ex)
                {
                    result.FileResults.Add(new FileResult
                    {
                        FileName = scan.DrawingFile,
                        Success = false,
                        ErrorMessage = ex.Message
                    });
                    result.ErrorCount++;
                }
            }

            // Xuat gop
            if (options.ExportMerged && allClassifications.Count > 0)
            {
                var mergedPath = Path.Combine(options.OutputFolder,
                    "MTO_Batch_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".xlsx");

                // Dung file dau tien lam dai dien, gop summary
                var firstScan = scans[0];
                var mergedClassification = MergeClassifications(allClassifications);
                var exporter = new ExcelExporter();
                exporter.Export(firstScan, mergedClassification, mergedPath);
                result.OutputFiles.Add(mergedPath);
            }

            result.EndTime = DateTime.UtcNow;
            result.Duration = result.EndTime - result.StartTime;
            result.SuccessCount = result.FileResults.Count(f => f.Success);
            return result;
        }

        private static ClassificationResult MergeClassifications(List<ClassificationResult> results)
        {
            var merged = new ClassificationResult
            {
                RuleSetVersion = results.FirstOrDefault()?.RuleSetVersion,
                DrawingFile = "BATCH_MERGED",
                RunAtUtc = DateTime.UtcNow
            };

            foreach (var r in results)
            {
                foreach (var detail in r.Details)
                    merged.Details.Add(detail);
                foreach (var unclass in r.Unclassified)
                    merged.Unclassified.Add(unclass);
                foreach (var summary in r.Summary)
                {
                    var existing = merged.Summary.FirstOrDefault(s =>
                        s.SystemCode == summary.SystemCode &&
                        s.MaterialCode == summary.MaterialCode &&
                        s.Unit == summary.Unit);
                    if (existing == null)
                    {
                        existing = new SummaryRow
                        {
                            SystemCode = summary.SystemCode,
                            MaterialCode = summary.MaterialCode,
                            MaterialName = summary.MaterialName,
                            Specification = summary.Specification,
                            Unit = summary.Unit,
                            StatusMessage = "OK"
                        };
                        merged.Summary.Add(existing);
                    }
                    existing.TotalQuantity += summary.TotalQuantity;
                    existing.ObjectCount += summary.ObjectCount;
                }
                merged.TotalEntities += r.TotalEntities;
            }

            return merged;
        }
    }

    public sealed class BatchOptions
    {
        public string OutputFolder { get; set; }
        public bool ExportPerFile { get; set; } = true;
        public bool ExportMerged { get; set; } = true;
    }

    public sealed class BatchResult
    {
        public int TotalFiles { get; set; }
        public int SuccessCount { get; set; }
        public int ErrorCount { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public TimeSpan Duration { get; set; }
        public List<FileResult> FileResults { get; set; } = new List<FileResult>();
        public List<string> OutputFiles { get; set; } = new List<string>();
    }

    public sealed class FileResult
    {
        public string FileName { get; set; }
        public long TotalScanned { get; set; }
        public long Classified { get; set; }
        public long Unclassified { get; set; }
        public double ClassificationRate { get; set; }
        public bool Success { get; set; }
        public string ErrorMessage { get; set; }
    }
}
