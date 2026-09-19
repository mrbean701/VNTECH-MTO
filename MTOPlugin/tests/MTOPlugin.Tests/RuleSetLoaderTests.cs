using System;
using System.IO;
using MTOPlugin.Core.Rules;
using NUnit.Framework;

namespace MTOPlugin.Tests
{
    [TestFixture]
    public class RuleSetLoaderTests
    {
        [Test]
        public void Deserialize_EmptyJson_ReturnsEmptyRuleSet()
        {
            var result = RuleSetLoader.Deserialize("{}");
            Assert.IsNotNull(result);
            Assert.AreEqual(0, result.Rules.Count);
        }

        [Test]
        public void Deserialize_Null_ReturnsEmptyRuleSet()
        {
            var result = RuleSetLoader.Deserialize(null);
            Assert.IsNotNull(result);
        }

        [Test]
        public void Deserialize_ValidJson_ParsesName()
        {
            var json = @"{""name"":""Test Rules"",""version"":""1.0"",""rules"":[]}";
            var result = RuleSetLoader.Deserialize(json);
            Assert.AreEqual("Test Rules", result.Name);
            Assert.AreEqual("1.0", result.Version);
        }

        [Test]
        public void Deserialize_WithRules_ParsesAll()
        {
            var json = @"{
                ""name"":""Test"",
                ""version"":""1.0"",
                ""rules"":[
                    {
                        ""code"":""R-001"",
                        ""systemCode"":""HE-DIEN"",
                        ""materialCode"":""M-1"",
                        ""materialName"":""Den"",
                        ""unit"":""cai"",
                        ""calculation"":""Count"",
                        ""status"":""Active"",
                        ""conditions"":[{""entityKind"":""block"",""blockNames"":""DEN*""}]
                    },
                    {
                        ""code"":""R-002"",
                        ""systemCode"":""HE-NUOC"",
                        ""materialCode"":""M-2"",
                        ""materialName"":""Ong"",
                        ""unit"":""m"",
                        ""calculation"":""SumLength"",
                        ""status"":""Active"",
                        ""conditions"":[{""entityKind"":""geometry"",""layers"":""WS-PIPE""}]
                    }
                ]
            }";
            var result = RuleSetLoader.Deserialize(json);
            Assert.AreEqual(2, result.Rules.Count);
            Assert.AreEqual("R-001", result.Rules[0].Code);
            Assert.AreEqual(CalculationKind.Count, result.Rules[0].Calculation);
            Assert.AreEqual("R-002", result.Rules[1].Code);
            Assert.AreEqual(CalculationKind.SumLength, result.Rules[1].Calculation);
        }

        [Test]
        public void Deserialize_CountIfAttributeEquals_ParsesCorrectly()
        {
            var json = @"{
                ""name"":""Test"",
                ""rules"":[
                    {
                        ""code"":""R-003"",
                        ""systemCode"":""HE-DIEN"",
                        ""materialCode"":""M-3"",
                        ""materialName"":""Den 10W"",
                        ""unit"":""cai"",
                        ""calculation"":""CountIfAttributeEquals"",
                        ""status"":""Active"",
                        ""attributeCondition"":{""attribute"":""WATTAGE"",""operator"":""equals"",""value"":""10""},
                        ""conditions"":[{""entityKind"":""block"",""blockNames"":""EL-LIGHT-*""}]
                    }
                ]
            }";
            var result = RuleSetLoader.Deserialize(json);
            Assert.AreEqual(1, result.Rules.Count);
            Assert.AreEqual(CalculationKind.CountIfAttributeEquals, result.Rules[0].Calculation);
            Assert.IsNotNull(result.Rules[0].AttributeCondition);
            Assert.AreEqual("WATTAGE", result.Rules[0].AttributeCondition.Attribute);
            Assert.AreEqual("equals", result.Rules[0].AttributeCondition.Operator);
            Assert.AreEqual("10", result.Rules[0].AttributeCondition.Value);
        }

        [Test]
        public void Deserialize_WithSystems_ParsesCorrectly()
        {
            var json = @"{
                ""name"":""Test"",
                ""systems"":[
                    {""code"":""HE-DIEN"",""name"":""He thong dien""},
                    {""code"":""HE-NUOC"",""name"":""He thong nuoc""}
                ],
                ""rules"":[]
            }";
            var result = RuleSetLoader.Deserialize(json);
            Assert.AreEqual(2, result.Systems.Count);
            Assert.AreEqual("HE-DIEN", result.Systems[0].Code);
            Assert.AreEqual("He thong dien", result.Systems[0].Name);
        }

        [Test]
        public void Serialize_ThenDeserialize_RoundTrips()
        {
            var original = new RuleSet
            {
                Name = "Round Trip Test",
                Version = "2.0",
                Description = "Test description"
            };
            original.Rules.Add(new RuleDefinition
            {
                Code = "R-RT-01",
                SystemCode = "HE-TEST",
                MaterialCode = "M-1",
                MaterialName = "Test Material",
                Unit = "cai",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Active,
                Priority = 100,
                Conditions = { new RuleCondition { EntityKind = "block", BlockNames = "TEST*" } }
            });

            var json = RuleSetLoader.Serialize(original);
            var deserialized = RuleSetLoader.Deserialize(json);

            Assert.AreEqual(original.Name, deserialized.Name);
            Assert.AreEqual(original.Version, deserialized.Version);
            Assert.AreEqual(1, deserialized.Rules.Count);
            Assert.AreEqual("R-RT-01", deserialized.Rules[0].Code);
        }

        [Test]
        public void Deserialize_InvalidJson_ThrowsInvalidDataException()
        {
            Assert.Throws<InvalidDataException>(() =>
                RuleSetLoader.Deserialize("{invalid json}"));
        }

        [Test]
        public void Load_NullPath_ThrowsArgumentException()
        {
            Assert.Throws<ArgumentException>(() =>
                RuleSetLoader.Load(null));
        }

        [Test]
        public void Load_NonExistentFile_ThrowsFileNotFoundException()
        {
            Assert.Throws<FileNotFoundException>(() =>
                RuleSetLoader.Load(@"C:\nonexistent\rules.json"));
        }

        [Test]
        public void Save_ThenLoad_RoundTrips()
        {
            var tempFile = Path.Combine(Path.GetTempPath(), "mto_rules_test_" + Guid.NewGuid().ToString("N") + ".json");
            try
            {
                var ruleSet = new RuleSet { Name = "Save Test", Version = "1.0" };
                ruleSet.Rules.Add(new RuleDefinition
                {
                    Code = "R-SAVE-01",
                    SystemCode = "HE-DIEN",
                    MaterialCode = "M-1",
                    MaterialName = "Test",
                    Unit = "cai",
                    Calculation = CalculationKind.Count,
                    Status = RuleStatus.Active,
                    Conditions = { new RuleCondition() }
                });

                RuleSetLoader.Save(ruleSet, tempFile);
                Assert.IsTrue(File.Exists(tempFile));

                var loaded = RuleSetLoader.Load(tempFile);
                Assert.AreEqual("Save Test", loaded.Name);
                Assert.AreEqual(1, loaded.Rules.Count);
                Assert.AreEqual("R-SAVE-01", loaded.Rules[0].Code);
            }
            finally
            {
                if (File.Exists(tempFile)) File.Delete(tempFile);
            }
        }

        [Test]
        public void ActiveRules_FiltersDraftAndPaused()
        {
            var ruleSet = new RuleSet();
            ruleSet.Rules.Add(new RuleDefinition { Code = "R-1", Status = RuleStatus.Active, Priority = 100 });
            ruleSet.Rules.Add(new RuleDefinition { Code = "R-2", Status = RuleStatus.Draft, Priority = 100 });
            ruleSet.Rules.Add(new RuleDefinition { Code = "R-3", Status = RuleStatus.Paused, Priority = 100 });
            ruleSet.Rules.Add(new RuleDefinition { Code = "R-4", Status = RuleStatus.Active, Priority = 200 });

            Assert.AreEqual(2, ruleSet.ActiveRules.Count);
            Assert.AreEqual("R-4", ruleSet.ActiveRules[0].Code); // Higher priority first
            Assert.AreEqual("R-1", ruleSet.ActiveRules[1].Code);
        }
    }
}
