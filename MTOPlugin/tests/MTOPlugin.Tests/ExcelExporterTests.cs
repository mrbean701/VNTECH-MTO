using System;
using System.IO;
using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Export;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;
using NUnit.Framework;
using OfficeOpenXml;

namespace MTOPlugin.Tests
{
    [TestFixture]
    public class ExcelExporterTests
    {
        private readonly string _outFile = Path.Combine(Path.GetTempPath(), "mto_test_out.xlsx");

        private static UnitInfo MmUnit() => new UnitInfo
        {
            SourceUnit = DwgUnit.Millimeters, SourceUnitText = "mm",
            OutputUnit = "mm", ConversionToMillimeter = 1.0
        };

        [SetUp]
        public void Setup()
        {
            if (File.Exists(_outFile)) File.Delete(_outFile);
        }

        [Test]
        public void Export_HasFiveSheets()
        {
            var scan = new ScanResult { DrawingFile = "abc.dwg", Options = new ScanOptions { Unit = MmUnit() }, Unit = MmUnit() };
            var block = new BlockReferenceInfo
            {
                BlockName = "DEN", EffectiveName = "DEN", Layer = "EL-DEVICE",
                Attributes = { { "MA", "A1" } },
                Identity = new ObjectIdentity { Handle = "1", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };
            var geom = new GeometryInfo
            {
                Kind = GeometryKind.Line, Layer = "WS-PIPE", RawLength = 500,
                Identity = new ObjectIdentity { Handle = "2", SourceFile = "host", Layout = "Layout1", Space = SpaceKind.Paper }
            };
            scan.Blocks.Add(block);
            scan.Geometries.Add(geom);
            scan.Layers.Add(new LayerStat { Name = "EL-DEVICE", ObjectCount = 1 });
            scan.TotalEntitiesScanned = 2;

            var rule1 = new RuleDefinition
            {
                Code = "R-1", SystemCode = "HE-DIEN", MaterialCode = "M-1",
                MaterialName = "Den", Unit = "cai", Calculation = CalculationKind.Count,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "DEN" } }
            };
            var rule2 = new RuleDefinition
            {
                Code = "R-2", SystemCode = "HE-NUOC", MaterialCode = "M-2",
                MaterialName = "Ong", Unit = "m", Calculation = CalculationKind.SumLength,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "geometry", Layers = "WS-PIPE" } }
            };
            var ruleSet = new RuleSet { Version = "1.0", Name = "test" };
            ruleSet.Rules.Add(rule1);
            ruleSet.Rules.Add(rule2);

            var engine = new ClassificationEngine(ruleSet, MmUnit());
            var result = engine.Classify(scan);

            var exporter = new ExcelExporter();
            exporter.Export(scan, result, _outFile);

            Assert.IsTrue(File.Exists(_outFile));

            using (var pkg = new ExcelPackage(new FileInfo(_outFile)))
            {
                Assert.AreEqual(5, pkg.Workbook.Worksheets.Count);
                Assert.IsNotNull(pkg.Workbook.Worksheets["TONG_HOP"]);
                Assert.IsNotNull(pkg.Workbook.Worksheets["CHI_TIET"]);
                Assert.IsNotNull(pkg.Workbook.Worksheets["CHUA_PHAN_LOAI"]);
                Assert.IsNotNull(pkg.Workbook.Worksheets["CANH_BAO_LOI"]);
                Assert.IsNotNull(pkg.Workbook.Worksheets["THONG_TIN_LAN_QUET"]);

                // TONG_HOP co 2 dong du lieu
                var ws = pkg.Workbook.Worksheets["TONG_HOP"];
                Assert.AreEqual(3, ws.Dimension.End.Row);
            }
        }

        [Test]
        public void Export_EmptyScan_ThrowsExcelExportException()
        {
            var scan = new ScanResult
            {
                DrawingFile = "empty.dwg",
                Options = new ScanOptions { Unit = MmUnit() },
                Unit = MmUnit(),
                TotalEntitiesScanned = 0
            };
            var result = new ClassificationResult();

            var exporter = new ExcelExporter();
            Assert.Throws<ExcelExportException>(() =>
                exporter.Export(scan, result, _outFile));
        }

        [Test]
        public void Export_FailedScan_Throws()
        {
            var scan = new ScanResult
            {
                DrawingFile = "bad.dwg",
                Options = new ScanOptions { Unit = MmUnit() },
                Unit = MmUnit(),
                ErrorMessage = "loi khi doc",
                ErrorCount = 1
            };
            var result = new ClassificationResult();

            var exporter = new ExcelExporter();
            var ex = Assert.Throws<ExcelExportException>(() =>
                exporter.Export(scan, result, _outFile));
            StringAssert.Contains("loi quet", ex.Message.ToLowerInvariant());
        }
    }
}