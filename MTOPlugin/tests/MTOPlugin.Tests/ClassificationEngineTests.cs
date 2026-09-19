using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;
using NUnit.Framework;

namespace MTOPlugin.Tests
{
    [TestFixture]
    public class ClassificationEngineTests
    {
        private static UnitInfo MmUnit() => new UnitInfo
        {
            SourceUnit = DwgUnit.Millimeters,
            SourceUnitText = "mm",
            OutputUnit = "mm",
            ConversionToMillimeter = 1.0
        };

        private static RuleSet RuleSetWith(RuleDefinition rule)
        {
            var set = new RuleSet { Version = "test" };
            set.Rules.Add(rule);
            return set;
        }

        private static ScanResult ScanWithOneBlock(BlockReferenceInfo block)
        {
            var scan = new ScanResult { DrawingFile = "test.dwg", Options = new ScanOptions { Unit = MmUnit() } };
            scan.Blocks.Add(block);
            scan.TotalEntitiesScanned = 1;
            return scan;
        }

        [Test]
        public void Classify_BlockMatch_AddsToSummary()
        {
            var rule = new RuleDefinition
            {
                Code = "R-T-01",
                SystemCode = "HE-TEST",
                MaterialCode = "M-1",
                MaterialName = "Bang dien",
                Unit = "cai",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "BANG*" } },
                Priority = 100
            };

            var block = new BlockReferenceInfo
            {
                BlockName = "BANGDIEN_HOP2",
                EffectiveName = "BANGDIEN_HOP2",
                Layer = "EL-DEVICE",
                Identity = new ObjectIdentity { Handle = "1", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            Assert.AreEqual(1, result.Summary.Count);
            Assert.AreEqual(1.0, result.Summary[0].TotalQuantity);
            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual("BANGDIEN_HOP2", result.Details[0].BlockName);
            Assert.AreEqual(0, result.Unclassified.Count);
            Assert.AreEqual(100.0, result.ClassificationRate);
        }

        [Test]
        public void Classify_NoMatch_GoesToUnclassified()
        {
            var rule = new RuleDefinition
            {
                Code = "R-T-01",
                SystemCode = "HE-TEST",
                MaterialCode = "M-1",
                MaterialName = "Bang dien",
                Unit = "cai",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "BANG*" } }
            };

            var block = new BlockReferenceInfo
            {
                BlockName = "DEN",
                EffectiveName = "DEN",
                Layer = "EL-DEVICE",
                Identity = new ObjectIdentity { Handle = "1", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            Assert.AreEqual(0, result.Details.Count);
            Assert.AreEqual(1, result.Unclassified.Count);
            Assert.AreEqual(0.0, result.ClassificationRate);
        }

        [Test]
        public void Classify_DraftRule_Ignored()
        {
            var rule = new RuleDefinition
            {
                Code = "R-T-DRAFT",
                SystemCode = "HE-TEST",
                MaterialCode = "M-1",
                MaterialName = "Draft",
                Unit = "cai",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Draft,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "*" } }
            };

            var block = new BlockReferenceInfo
            {
                BlockName = "ANY",
                EffectiveName = "ANY",
                Layer = "X",
                Identity = new ObjectIdentity { Handle = "1", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));
            Assert.AreEqual(0, result.Details.Count);
            Assert.AreEqual(1, result.Unclassified.Count);
        }

        [Test]
        public void Classify_GeometrySumLength_UsesConvertedUnit()
        {
            var rule = new RuleDefinition
            {
                Code = "R-T-GEO",
                SystemCode = "HE-TEST",
                MaterialCode = "M-2",
                MaterialName = "Ong",
                Unit = "m",
                Calculation = CalculationKind.SumLength,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "geometry", Layers = "WS-PIPE", GeometryKinds = "Line" } }
            };

            var scan = new ScanResult { DrawingFile = "t.dwg", Options = new ScanOptions { Unit = MmUnit() } };
            scan.Geometries.Add(new GeometryInfo
            {
                Kind = GeometryKind.Line,
                Layer = "WS-PIPE",
                RawLength = 3000,
                Identity = new ObjectIdentity { Handle = "h1", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 1;

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(scan);

            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(3000.0, result.Details[0].Quantity); // mm -> mm
            Assert.AreEqual(3000.0, result.Summary[0].TotalQuantity);
        }

        [Test]
        public void Classify_GeometrySumLengthTimesFactor()
        {
            var rule = new RuleDefinition
            {
                Code = "R-T-GEO2",
                SystemCode = "HE-TEST",
                MaterialCode = "M-3",
                MaterialName = "Cap doi",
                Unit = "m",
                Calculation = CalculationKind.SumLengthTimesFactor,
                Factor = 2.0,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "geometry", Layers = "EL-WIRE", GeometryKinds = "Line" } }
            };

            var scan = new ScanResult { DrawingFile = "t.dwg", Options = new ScanOptions { Unit = MmUnit() } };
            scan.Geometries.Add(new GeometryInfo
            {
                Kind = GeometryKind.Line, Layer = "EL-WIRE", RawLength = 100,
                Identity = new ObjectIdentity { Handle = "h", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 1;

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(scan);
            Assert.AreEqual(200.0, result.Summary[0].TotalQuantity);
        }

        // --- P1.1: CountIfAttributeEquals tests ---

        [Test]
        public void Classify_CountIfAttributeEquals_MatchingAttribute_CountsOne()
        {
            var rule = new RuleDefinition
            {
                Code = "R-DEN-10W",
                SystemCode = "HE-DIEN",
                MaterialCode = "M-LT-01",
                MaterialName = "Den LED 10W",
                Unit = "cai",
                Calculation = CalculationKind.CountIfAttributeEquals,
                AttributeCondition = new AttributeCondition
                {
                    Attribute = "WATTAGE",
                    Operator = "equals",
                    Value = "10",
                    Action = "include"
                },
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "EL-LIGHT-DL-*" } },
                Priority = 100
            };

            var block = new BlockReferenceInfo
            {
                BlockName = "EL-LIGHT-DL-10W",
                EffectiveName = "EL-LIGHT-DL-10W",
                Layer = "EL-LIGHT",
                Attributes = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "WATTAGE", "10" },
                    { "COLOR_TEMP", "4000" }
                },
                Identity = new ObjectIdentity { Handle = "100", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(1.0, result.Details[0].Quantity);
            Assert.AreEqual(1, result.Summary.Count);
            Assert.AreEqual(1.0, result.Summary[0].TotalQuantity);
        }

        [Test]
        public void Classify_CountIfAttributeEquals_NonMatchingAttribute_CountsZero()
        {
            var rule = new RuleDefinition
            {
                Code = "R-DEN-10W",
                SystemCode = "HE-DIEN",
                MaterialCode = "M-LT-01",
                MaterialName = "Den LED 10W",
                Unit = "cai",
                Calculation = CalculationKind.CountIfAttributeEquals,
                AttributeCondition = new AttributeCondition
                {
                    Attribute = "WATTAGE",
                    Operator = "equals",
                    Value = "10"
                },
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "EL-LIGHT-*" } },
                Priority = 100
            };

            // Block co WATTAGE=20, khong phai 10
            var block = new BlockReferenceInfo
            {
                BlockName = "EL-LIGHT-DL-20W",
                EffectiveName = "EL-LIGHT-DL-20W",
                Layer = "EL-LIGHT",
                Attributes = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "WATTAGE", "20" }
                },
                Identity = new ObjectIdentity { Handle = "101", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            // Block khop dieu kien nhung attribute khong match -> qty=0, van o Details
            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(0.0, result.Details[0].Quantity);
        }

        [Test]
        public void Classify_CountIfAttributeEquals_ContainsOperator_Matches()
        {
            var rule = new RuleDefinition
            {
                Code = "R-CAM-4MP",
                SystemCode = "HE-ELV-CCTV",
                MaterialCode = "M-CAM-01",
                MaterialName = "Camera 4MP",
                Unit = "cai",
                Calculation = CalculationKind.CountIfAttributeEquals,
                AttributeCondition = new AttributeCondition
                {
                    Attribute = "RESOLUTION",
                    Operator = "contains",
                    Value = "4MP"
                },
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "ELV-CAM-*" } },
                Priority = 100
            };

            var block = new BlockReferenceInfo
            {
                BlockName = "ELV-CAM-DOME",
                EffectiveName = "ELV-CAM-DOME",
                Layer = "ELV-CAM",
                Attributes = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "RESOLUTION", "4MP-IR30m" }
                },
                Identity = new ObjectIdentity { Handle = "200", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(1.0, result.Details[0].Quantity);
        }

        [Test]
        public void Classify_CountIfAttributeEquals_GreaterThan_Works()
        {
            var rule = new RuleDefinition
            {
                Code = "R-UPS-10K",
                SystemCode = "HE-ELV-DC",
                MaterialCode = "M-UPS-01",
                MaterialName = "UPS >= 10kVA",
                Unit = "cai",
                Calculation = CalculationKind.CountIfAttributeEquals,
                AttributeCondition = new AttributeCondition
                {
                    Attribute = "KVA",
                    Operator = "greaterThan",
                    Value = "5"
                },
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "ELV-DC-UPS-*" } },
                Priority = 100
            };

            var block = new BlockReferenceInfo
            {
                BlockName = "ELV-DC-UPS-10K",
                EffectiveName = "ELV-DC-UPS-10K",
                Layer = "ELV-DC",
                Attributes = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "KVA", "10" }
                },
                Identity = new ObjectIdentity { Handle = "300", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(1.0, result.Details[0].Quantity);
        }

        [Test]
        public void Classify_CountIfAttributeEquals_LessThan_Fails()
        {
            var rule = new RuleDefinition
            {
                Code = "R-UPS-10K",
                SystemCode = "HE-ELV-DC",
                MaterialCode = "M-UPS-01",
                MaterialName = "UPS < 10kVA",
                Unit = "cai",
                Calculation = CalculationKind.CountIfAttributeEquals,
                AttributeCondition = new AttributeCondition
                {
                    Attribute = "KVA",
                    Operator = "lessThan",
                    Value = "10"
                },
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "ELV-DC-UPS-*" } },
                Priority = 100
            };

            var block = new BlockReferenceInfo
            {
                BlockName = "ELV-DC-UPS-10K",
                EffectiveName = "ELV-DC-UPS-10K",
                Layer = "ELV-DC",
                Attributes = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "KVA", "10" }
                },
                Identity = new ObjectIdentity { Handle = "301", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(0.0, result.Details[0].Quantity); // 10 is NOT < 10
        }

        [Test]
        public void Classify_CountIfAttributeEquals_NoAttribute_ReturnsZero()
        {
            var rule = new RuleDefinition
            {
                Code = "R-DEN-10W",
                SystemCode = "HE-DIEN",
                MaterialCode = "M-LT-01",
                MaterialName = "Den LED 10W",
                Unit = "cai",
                Calculation = CalculationKind.CountIfAttributeEquals,
                AttributeCondition = new AttributeCondition
                {
                    Attribute = "WATTAGE",
                    Operator = "equals",
                    Value = "10"
                },
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "*" } },
                Priority = 100
            };

            // Block khong co attribute WATTAGE
            var block = new BlockReferenceInfo
            {
                BlockName = "DEN",
                EffectiveName = "DEN",
                Layer = "EL",
                Attributes = new System.Collections.Generic.Dictionary<string, string>(),
                Identity = new ObjectIdentity { Handle = "400", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            };

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(ScanWithOneBlock(block));

            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(0.0, result.Details[0].Quantity);
        }

        [Test]
        public void Classify_SumLengthCeilingStep_RoundsUp()
        {
            var rule = new RuleDefinition
            {
                Code = "R-TRAY",
                SystemCode = "HE-DIEN",
                MaterialCode = "M-TRAY-01",
                MaterialName = "Khay cap 3m",
                Unit = "m",
                Calculation = CalculationKind.SumLengthCeilingStep,
                CeilingStep = 3000.0, // 3000mm = 3m (don vi giong OutputUnit = mm)
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "geometry", Layers = "EL-TRAY-*", GeometryKinds = "Line;Polyline" } },
                Priority = 100
            };

            var scan = new ScanResult { DrawingFile = "t.dwg", Options = new ScanOptions { Unit = MmUnit() } };
            scan.Geometries.Add(new GeometryInfo
            {
                Kind = GeometryKind.Line, Layer = "EL-TRAY-J", RawLength = 7000, // 7m -> ceil(7/3)*3 = 9m
                Identity = new ObjectIdentity { Handle = "h2", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 1;

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(scan);

            Assert.AreEqual(1, result.Details.Count);
            Assert.AreEqual(9000.0, result.Details[0].Quantity); // ceil(7000/3000)*3000 = 3*3000 = 9000
        }

        [Test]
        public void Classify_MultipleBlocks_SummaryGroupsCorrectly()
        {
            var rule = new RuleDefinition
            {
                Code = "R-DEN",
                SystemCode = "HE-DIEN",
                MaterialCode = "M-LT-01",
                MaterialName = "Den LED",
                Unit = "cai",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Active,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "EL-LIGHT-*" } },
                Priority = 100
            };

            var scan = new ScanResult { DrawingFile = "t.dwg", Options = new ScanOptions { Unit = MmUnit() } };
            scan.Blocks.Add(new BlockReferenceInfo
            {
                BlockName = "EL-LIGHT-DL", EffectiveName = "EL-LIGHT-DL", Layer = "EL-LIGHT",
                Identity = new ObjectIdentity { Handle = "1", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.Blocks.Add(new BlockReferenceInfo
            {
                BlockName = "EL-LIGHT-PNL", EffectiveName = "EL-LIGHT-PNL", Layer = "EL-LIGHT",
                Identity = new ObjectIdentity { Handle = "2", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.Blocks.Add(new BlockReferenceInfo
            {
                BlockName = "EL-LIGHT-EXIT", EffectiveName = "EL-LIGHT-EXIT", Layer = "EL-LIGHT",
                Identity = new ObjectIdentity { Handle = "3", SourceFile = "host", Layout = "Model", Space = SpaceKind.Model }
            });
            scan.TotalEntitiesScanned = 3;

            var engine = new ClassificationEngine(RuleSetWith(rule), MmUnit());
            var result = engine.Classify(scan);

            Assert.AreEqual(1, result.Summary.Count);
            Assert.AreEqual(3.0, result.Summary[0].TotalQuantity);
            Assert.AreEqual(3, result.Summary[0].ObjectCount);
            Assert.AreEqual(3, result.Details.Count);
            Assert.AreEqual(100.0, result.ClassificationRate);
        }
    }
}