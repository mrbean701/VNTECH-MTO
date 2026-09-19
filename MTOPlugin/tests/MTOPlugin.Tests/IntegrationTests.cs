using System;
using System.Collections.Generic;
using System.IO;
using MTOPlugin.Core.Batch;
using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Export;
using MTOPlugin.Core.Localization;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;
using MTOPlugin.Core.Unit;
using NUnit.Framework;

namespace MTOPlugin.Tests
{
    [TestFixture]
    public class IntegrationTests
    {
        private string _sampleRulesPath;
        private string _outputDir;

        [SetUp]
        public void Setup()
        {
            // Try multiple paths for rules.sample.json
            var paths = new[]
            {
                Path.Combine(TestContext.CurrentContext.TestDirectory, "..", "..", "..", "..", "config", "rules.sample.json"),
                Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "config", "rules.sample.json"),
                Path.Combine(Directory.GetCurrentDirectory(), "config", "rules.sample.json"),
                @"D:\13. Duong Trong Thang\Tai lieu\1. Du an chuan hoa quy trinh\quantity take-off\MTOPlugin\config\rules.sample.json"
            };

            _sampleRulesPath = null;
            foreach (var path in paths)
            {
                if (File.Exists(path))
                {
                    _sampleRulesPath = path;
                    break;
                }
            }

            _outputDir = Path.Combine(Path.GetTempPath(), "mto_test_" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_outputDir);
        }

        [TearDown]
        public void Cleanup()
        {
            if (Directory.Exists(_outputDir))
            {
                try { Directory.Delete(_outputDir, true); } catch { }
            }
        }

        // --- RuleSetLoader Integration ---

        [Test]
        public void Integration_LoadSampleRules_LoadsSuccessfully()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found at: " + _sampleRulesPath);
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            Assert.IsNotNull(ruleSet);
            Assert.That(ruleSet.Rules.Count, Is.GreaterThanOrEqualTo(100), "Should have 100+ rules");
            Assert.That(ruleSet.Systems.Count, Is.GreaterThanOrEqualTo(10), "Should have 10+ systems");
        }

        [Test]
        public void Integration_LoadSampleRules_AllRulesHaveRequiredFields()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found");
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            foreach (var rule in ruleSet.Rules)
            {
                Assert.IsNotNull(rule.Code, "Rule Code should not be null");
                Assert.IsNotNull(rule.SystemCode, "Rule SystemCode should not be null: " + rule.Code);
                Assert.IsNotNull(rule.MaterialCode, "Rule MaterialCode should not be null: " + rule.Code);
                Assert.IsNotNull(rule.MaterialName, "Rule MaterialName should not be null: " + rule.Code);
                Assert.IsNotNull(rule.Unit, "Rule Unit should not be null: " + rule.Code);
                Assert.That(rule.Conditions.Count, Is.GreaterThan(0), "Rule should have conditions: " + rule.Code);
            }
        }

        [Test]
        public void Integration_LoadSampleRules_NoDuplicateCodes()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found");
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            var codes = new HashSet<string>();
            foreach (var rule in ruleSet.Rules)
            {
                Assert.IsTrue(codes.Add(rule.Code), "Duplicate rule code: " + rule.Code);
            }
        }

        [Test]
        public void Integration_ValidateSampleRules_NoIssues()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found");
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            var issues = RuleSetLoader.ValidateRuleSet(ruleSet);
            Assert.AreEqual(0, issues.Count, "Validation issues: " + string.Join("; ", issues));
        }

        [Test]
        public void Integration_LoadSampleRules_SystemsParsedCorrectly()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found");
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            Assert.IsTrue(ruleSet.Systems.Exists(s => s.Code == "HE-DIEN"), "Should have HE-DIEN system");
            Assert.IsTrue(ruleSet.Systems.Exists(s => s.Code == "HE-NUOC"), "Should have HE-NUOC system");
            Assert.IsTrue(ruleSet.Systems.Exists(s => s.Code == "HE-ELV-NET"), "Should have HE-ELV-NET system");
            Assert.IsTrue(ruleSet.Systems.Exists(s => s.Code == "HE-ELV-CCTV"), "Should have HE-ELV-CCTV system");
        }

        // --- ClassificationEngine Integration ---

        [Test]
        public void Integration_ClassifyWithRealRules_ElectricalBlock()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found");
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            var unit = new UnitInfo { SourceUnit = DwgUnit.Millimeters, SourceUnitText = "mm", OutputUnit = "mm", ConversionToMillimeter = 1.0 };
            var engine = new ClassificationEngine(ruleSet, unit);

            var scan = new ScanResult { DrawingFile = "test.dwg" };
            scan.Blocks.Add(new BlockReferenceInfo
            {
                BlockName = "EL-LIGHT-DL-10W",
                EffectiveName = "EL-LIGHT-DL-10W",
                Layer = "EL-LIGHT",
                Attributes = new Dictionary<string, string> { { "WATTAGE", "10" } },
                Identity = new ObjectIdentity { Handle = "1", SourceFile = "test.dwg", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 1;

            var result = engine.Classify(scan);
            Assert.AreEqual(1, result.ClassifiedCount);
            Assert.AreEqual(0, result.UnclassifiedCount);
            Assert.That(result.Summary.Count, Is.GreaterThan(0));
        }

        [Test]
        public void Integration_ClassifyWithRealRules_PlumbingBlock()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found");
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            var unit = new UnitInfo { SourceUnit = DwgUnit.Millimeters, SourceUnitText = "mm", OutputUnit = "mm", ConversionToMillimeter = 1.0 };
            var engine = new ClassificationEngine(ruleSet, unit);

            var scan = new ScanResult { DrawingFile = "test.dwg" };
            scan.Blocks.Add(new BlockReferenceInfo
            {
                BlockName = "PLB-VALVE-BALL-DN25",
                EffectiveName = "PLB-VALVE-BALL-DN25",
                Layer = "PLB-VALVE",
                Identity = new ObjectIdentity { Handle = "2", SourceFile = "test.dwg", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 1;

            var result = engine.Classify(scan);
            Assert.AreEqual(1, result.ClassifiedCount);
        }

        [Test]
        public void Integration_ClassifyWithRealRules_NetworkGeometry()
        {
            if (!File.Exists(_sampleRulesPath))
            {
                Assert.Ignore("rules.sample.json not found");
                return;
            }

            var ruleSet = RuleSetLoader.Load(_sampleRulesPath);
            var unit = new UnitInfo { SourceUnit = DwgUnit.Millimeters, SourceUnitText = "mm", OutputUnit = "m", ConversionToMillimeter = 1.0 };
            var engine = new ClassificationEngine(ruleSet, unit);

            var scan = new ScanResult { DrawingFile = "test.dwg" };
            scan.Geometries.Add(new GeometryInfo
            {
                Kind = GeometryKind.Line,
                Layer = "ELV-NET-CAB-CAT6A-01",
                RawLength = 50000,
                Identity = new ObjectIdentity { Handle = "3", SourceFile = "test.dwg", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 1;

            var result = engine.Classify(scan);
            Assert.AreEqual(1, result.ClassifiedCount);
            Assert.AreEqual(50.0, result.Details[0].Quantity, 0.01); // 50000mm = 50m
        }

        // --- ExcelExporter Integration ---

        [Test]
        public void Integration_ExportToExcel_CreatesFile()
        {
            var ruleSet = new RuleSet { Version = "test" };
            ruleSet.Rules.Add(new RuleDefinition
            {
                Code = "R-TEST-001",
                SystemCode = "HE-TEST",
                MaterialCode = "M-001",
                MaterialName = "Test Material",
                Unit = "cai",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "TEST*" } }
            });

            var unit = new UnitInfo { SourceUnit = DwgUnit.Millimeters, SourceUnitText = "mm", OutputUnit = "mm", ConversionToMillimeter = 1.0 };
            var engine = new ClassificationEngine(ruleSet, unit);

            var scan = new ScanResult { DrawingFile = "integration_test.dwg" };
            scan.Blocks.Add(new BlockReferenceInfo
            {
                BlockName = "TEST-BLOCK",
                EffectiveName = "TEST-BLOCK",
                Layer = "TEST-LAYER",
                Identity = new ObjectIdentity { Handle = "A1", SourceFile = "integration_test.dwg", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 1;

            var result = engine.Classify(scan);
            var outputPath = Path.Combine(_outputDir, "test_output.xlsx");

            var exporter = new ExcelExporter();
            exporter.Export(scan, result, outputPath);

            Assert.IsTrue(File.Exists(outputPath), "Excel file should be created");
            var fileInfo = new FileInfo(outputPath);
            Assert.That(fileInfo.Length, Is.GreaterThan(0), "Excel file should not be empty");
        }

        // --- CsvExporter Integration ---

        [Test]
        public void Integration_ExportToCsv_CreatesFile()
        {
            var result = new ClassificationResult();
            result.Summary.Add(new SummaryRow
            {
                SystemCode = "HE-TEST",
                MaterialCode = "M-001",
                MaterialName = "Test Material",
                Unit = "cai",
                TotalQuantity = 5,
                ObjectCount = 5,
                StatusMessage = "OK"
            });

            var csvPath = Path.Combine(_outputDir, "test_summary.csv");
            var exporter = new CsvExporter();
            exporter.ExportSummary(result, csvPath);

            Assert.IsTrue(File.Exists(csvPath), "CSV file should be created");
            var content = File.ReadAllText(csvPath);
            Assert.That(content, Does.Contain("HE-TEST"));
            Assert.That(content, Does.Contain("Test Material"));
        }

        // --- BatchEngine Integration ---

        [Test]
        public void Integration_BatchEngine_ProcessesMultipleFiles()
        {
            var ruleSet = new RuleSet { Version = "test" };
            ruleSet.Rules.Add(new RuleDefinition
            {
                Code = "R-BATCH-001",
                SystemCode = "HE-TEST",
                MaterialCode = "M-001",
                MaterialName = "Batch Material",
                Unit = "cai",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "*" } }
            });

            var unit = new UnitInfo { SourceUnit = DwgUnit.Millimeters, SourceUnitText = "mm", OutputUnit = "mm", ConversionToMillimeter = 1.0 };
            var batchEngine = new BatchEngine(ruleSet, unit);

            var scans = new List<ScanResult>();
            for (int i = 0; i < 3; i++)
            {
                var scan = new ScanResult { DrawingFile = "batch_" + i + ".dwg" };
                scan.Blocks.Add(new BlockReferenceInfo
                {
                    BlockName = "BATCH-BLOCK-" + i,
                    EffectiveName = "BATCH-BLOCK-" + i,
                    Layer = "BATCH-LAYER",
                    Identity = new ObjectIdentity { Handle = i.ToString(), SourceFile = "batch_" + i + ".dwg", Layout = "Model", Space = SpaceKind.Model }
                });
                scan.TotalEntitiesScanned = 1;
                scans.Add(scan);
            }

            var options = new BatchOptions
            {
                OutputFolder = _outputDir,
                ExportPerFile = true,
                ExportMerged = true
            };

            var batchResult = batchEngine.Process(scans, options);

            Assert.AreEqual(3, batchResult.TotalFiles);
            Assert.AreEqual(3, batchResult.SuccessCount);
            Assert.AreEqual(0, batchResult.ErrorCount);
            Assert.That(batchResult.OutputFiles.Count, Is.GreaterThanOrEqualTo(1));
        }

        // --- UnitConverter Integration ---

        [Test]
        public void Integration_UnitConverter_ConvertsCorrectly()
        {
            Assert.AreEqual(1000.0, UnitConverter.ToMillimeter(DwgUnit.Meters, 1.0));
            Assert.AreEqual(304.8, UnitConverter.ToMillimeter(DwgUnit.Feet, 1.0));
            Assert.AreEqual(25.4, UnitConverter.ToMillimeter(DwgUnit.Inches, 1.0));
            Assert.AreEqual(914.4, UnitConverter.ToMillimeter(DwgUnit.Yards, 1.0));
        }

        [Test]
        public void Integration_UnitConverter_ToOutput_Works()
        {
            Assert.AreEqual(1.0, UnitConverter.ToOutput(DwgUnit.Millimeters, 1000.0, "m"), 0.001);
            Assert.AreEqual(1.0, UnitConverter.ToOutput(DwgUnit.Feet, 1.0, "ft"), 0.001);
            Assert.AreEqual(12.0, UnitConverter.ToOutput(DwgUnit.Feet, 1.0, "in"), 0.001);
        }

        // --- Localization Integration ---

        [Test]
        public void Integration_Localization_Vietnamese()
        {
            LocalizationHelper.SetLanguage(LocalizationHelper.Language.Vietnamese);
            Assert.AreEqual("MTOPro - Bóc Tách Khối Lượng M&E", LocalizationHelper.Get("APP_TITLE"));
            Assert.AreEqual("Bước 1: Quét + Phân loại", LocalizationHelper.Get("STEP1"));
            Assert.AreEqual("Quét", LocalizationHelper.Get("SCAN"));
        }

        [Test]
        public void Integration_Localization_English()
        {
            LocalizationHelper.SetLanguage(LocalizationHelper.Language.English);
            Assert.AreEqual("MTOPro - M&E Quantity Take-Off", LocalizationHelper.Get("APP_TITLE"));
            Assert.AreEqual("Step 1: Scan + Classify", LocalizationHelper.Get("STEP1"));
            Assert.AreEqual("Scan", LocalizationHelper.Get("SCAN"));
        }

        [Test]
        public void Integration_Localization_SwitchLanguage()
        {
            LocalizationHelper.SetLanguage(LocalizationHelper.Language.Vietnamese);
            var vi = LocalizationHelper.Get("EXPORT_ALL");
            Assert.AreEqual("Xuất TOÀN BỘ", vi);

            LocalizationHelper.SetLanguage(LocalizationHelper.Language.English);
            var en = LocalizationHelper.Get("EXPORT_ALL");
            Assert.AreEqual("Export ALL", en);
        }

        // --- JSON Validation Integration ---

        [Test]
        public void Integration_JsonValidation_ValidJson()
        {
            var result = RuleSetLoader.ValidateJson("{\"name\":\"test\"}");
            Assert.IsNull(result, "Valid JSON should return null");
        }

        [Test]
        public void Integration_JsonValidation_InvalidJson()
        {
            var result = RuleSetLoader.ValidateJson("{invalid json}");
            Assert.IsNotNull(result, "Invalid JSON should return error message");
            Assert.That(result, Does.Contain("khong hop le"));
        }

        [Test]
        public void Integration_JsonValidation_EmptyString()
        {
            var result = RuleSetLoader.ValidateJson("");
            Assert.IsNotNull(result);
        }

        // --- Path Sanitization Integration ---

        [Test]
        public void Integration_SanitizePath_ValidJsonFile()
        {
            var result = RuleSetLoader.SanitizePath("rules.json");
            Assert.AreEqual("rules.json", result);
        }

        [Test]
        public void Integration_SanitizePath_InvalidExtension()
        {
            var result = RuleSetLoader.SanitizePath("file.exe");
            Assert.IsNull(result);
        }

        [Test]
        public void Integration_SanitizePath_NullBytes()
        {
            var result = RuleSetLoader.SanitizePath("file\0.json");
            Assert.IsNotNull(result);
            Assert.IsFalse(result.Contains("\0"));
        }
    }
}
