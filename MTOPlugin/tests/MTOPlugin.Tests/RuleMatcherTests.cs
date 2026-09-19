using System.Collections.Generic;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;
using NUnit.Framework;

namespace MTOPlugin.Tests
{
    [TestFixture]
    public class RuleMatcherTests
    {
        private static BlockReferenceInfo MakeBlock(string name, string eff, string layer,
            Dictionary<string, string> attrs = null, bool isDynamic = false)
        {
            return new BlockReferenceInfo
            {
                BlockName = name,
                EffectiveName = eff ?? name,
                Layer = layer,
                IsDynamic = isDynamic,
                Attributes = attrs ?? new Dictionary<string, string>()
            };
        }

        [Test]
        public void MatchesBlock_SimpleLayer()
        {
            var cond = new RuleCondition { EntityKind = "block", Layers = "EL-DEVICE" };
            var block = MakeBlock("DEN", "DEN", "EL-DEVICE");
            Assert.IsTrue(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_WildcardBlockName()
        {
            var cond = new RuleCondition { BlockNames = "DEN*;CB*" };
            var block = MakeBlock("DEN_HOP2", "DEN_HOP2", "EL-DEVICE");
            Assert.IsTrue(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_WrongLayer_Fails()
        {
            var cond = new RuleCondition { EntityKind = "block", Layers = "EL-DEVICE" };
            var block = MakeBlock("DEN", "DEN", "WS-PIPE");
            Assert.IsFalse(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_Attributes()
        {
            var cond = new RuleCondition
            {
                EntityKind = "block",
                BlockNames = "VAN*",
                Attributes = "SIZE=DN25;TYPE=GATE"
            };
            var block = MakeBlock("VAN_BI", "VAN_BI", "WS-PIPE",
                new Dictionary<string, string> { { "SIZE", "DN25" }, { "TYPE", "GATE" } });
            Assert.IsTrue(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_AttributeNegated()
        {
            var cond = new RuleCondition
            {
                EntityKind = "block",
                BlockNames = "VAN*",
                Attributes = "~TYPE=GLOBE"
            };
            var block = MakeBlock("VAN_GATE", "VAN_GATE", "WS-PIPE",
                new Dictionary<string, string> { { "TYPE", "GATE" } });
            Assert.IsTrue(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_EntityKindMismatch_Fails()
        {
            var cond = new RuleCondition { EntityKind = "geometry", Layers = "EL-DEVICE" };
            var block = MakeBlock("DEN", "DEN", "EL-DEVICE");
            Assert.IsFalse(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesGeometry_Line()
        {
            var cond = new RuleCondition
            {
                EntityKind = "geometry",
                Layers = "EL-CONDUIT",
                GeometryKinds = "Line;Polyline"
            };
            var geom = new GeometryInfo { Kind = GeometryKind.Line, Layer = "EL-CONDUIT" };
            Assert.IsTrue(RuleMatcher.MatchesGeometry(cond, geom));
        }

        [Test]
        public void MatchesGeometry_WrongKind_Fails()
        {
            var cond = new RuleCondition
            {
                EntityKind = "geometry",
                GeometryKinds = "Polyline"
            };
            var geom = new GeometryInfo { Kind = GeometryKind.Line, Layer = "EL-CONDUIT" };
            Assert.IsFalse(RuleMatcher.MatchesGeometry(cond, geom));
        }

        [Test]
        public void MatchWildcard_Basic()
        {
            Assert.IsTrue(RuleMatcher.MatchWildcard("EL-*", "EL-CABLE"));
            Assert.IsTrue(RuleMatcher.MatchWildcard("VAN", "VAN"));
            Assert.IsFalse(RuleMatcher.MatchWildcard("EL-*", "WS-PIPE"));
        }

        // --- P1.3: DynamicProperty tests ---

        [Test]
        public void MatchesBlock_DynamicProperty_Equals()
        {
            var cond = new RuleCondition
            {
                EntityKind = "block",
                BlockNames = "ELV-DC-RACK-*",
                DynamicProperty = new DynamicPropertyCondition
                {
                    PropertyName = "Size",
                    Operator = "equals",
                    Value = "42U"
                }
            };
            var block = MakeBlock("ELV-DC-RACK-42U", "ELV-DC-RACK-42U", "ELV-DC",
                new Dictionary<string, string>(), true);
            block.DynamicProperties = new Dictionary<string, object>
            {
                { "Size", "42U" },
                { "Width", "600" }
            };
            Assert.IsTrue(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_DynamicProperty_EqualsFails()
        {
            var cond = new RuleCondition
            {
                EntityKind = "block",
                BlockNames = "ELV-DC-RACK-*",
                DynamicProperty = new DynamicPropertyCondition
                {
                    PropertyName = "Size",
                    Operator = "equals",
                    Value = "42U"
                }
            };
            var block = MakeBlock("ELV-DC-RACK-24U", "ELV-DC-RACK-24U", "ELV-DC",
                new Dictionary<string, string>(), true);
            block.DynamicProperties = new Dictionary<string, object>
            {
                { "Size", "24U" }
            };
            Assert.IsFalse(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_DynamicProperty_Contains()
        {
            var cond = new RuleCondition
            {
                EntityKind = "block",
                BlockNames = "EL-LIGHT-*",
                DynamicProperty = new DynamicPropertyCondition
                {
                    PropertyName = "Visibility",
                    Operator = "contains",
                    Value = "Downlight"
                }
            };
            var block = MakeBlock("EL-LIGHT-DL", "EL-LIGHT-DL", "EL-LIGHT",
                new Dictionary<string, string>(), true);
            block.DynamicProperties = new Dictionary<string, object>
            {
                { "Visibility", "LED-Downlight-10W" }
            };
            Assert.IsTrue(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_DynamicProperty_NoProperties_Fails()
        {
            var cond = new RuleCondition
            {
                EntityKind = "block",
                BlockNames = "*",
                DynamicProperty = new DynamicPropertyCondition
                {
                    PropertyName = "Size",
                    Operator = "equals",
                    Value = "42U"
                }
            };
            // Block khong co DynamicProperties
            var block = MakeBlock("RACK", "RACK", "DC");
            Assert.IsFalse(RuleMatcher.MatchesBlock(cond, block));
        }

        [Test]
        public void MatchesBlock_DynamicProperty_GreaterThan()
        {
            var cond = new RuleCondition
            {
                EntityKind = "block",
                BlockNames = "ELV-DC-UPS-*",
                DynamicProperty = new DynamicPropertyCondition
                {
                    PropertyName = "Capacity",
                    Operator = "greaterThan",
                    Value = "5"
                }
            };
            var block = MakeBlock("ELV-DC-UPS-10K", "ELV-DC-UPS-10K", "ELV-DC",
                new Dictionary<string, string>(), true);
            block.DynamicProperties = new Dictionary<string, object>
            {
                { "Capacity", "10" }
            };
            Assert.IsTrue(RuleMatcher.MatchesBlock(cond, block));
        }
    }
}