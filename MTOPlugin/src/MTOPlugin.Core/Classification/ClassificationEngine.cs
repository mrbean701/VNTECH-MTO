using System;
using System.Collections.Generic;
using System.Linq;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;

namespace MTOPlugin.Core.Classification
{
    /// <summary>
    /// Trung khip ap dung bo quy tac len cac doi tuong da quet duoc.
    /// Nguyen tac:
    ///  - Moi doi tuong duoc test theo tung quy tac (uu tien giam dan).
    ///  - Neu khong khop quy tac nao -> dua vao danh sach CHUA_PHAN_LOAI.
    ///  - Loi tren mot doi tuong khong lam dung toan bo luot quet (try/catch rieng).
    /// </summary>
    public sealed class ClassificationEngine
    {
        private readonly RuleSet _ruleSet;
        private readonly UnitInfo _unit;

        public ClassificationEngine(RuleSet ruleSet, UnitInfo unit)
        {
            _ruleSet = ruleSet ?? throw new ArgumentNullException(nameof(ruleSet));
            _unit = unit ?? new UnitInfo();
        }

        public ClassificationResult Classify(ScanResult scan)
        {
            if (scan == null) throw new ArgumentNullException(nameof(scan));
            if (!scan.Success) throw new InvalidOperationException(
                "Khong the phan loai doi voi ket qua quet da co loi: " + scan.ErrorMessage);

            var result = new ClassificationResult
            {
                DrawingFile = scan.DrawingFile,
                RuleSetVersion = _ruleSet.Version + " | " + _ruleSet.Name,
                RunAtUtc = DateTime.UtcNow,
                TotalEntities = scan.Blocks.Count + scan.Geometries.Count
            };

            var rules = _ruleSet.ActiveRules.ToList();

            // --- Blocks ---
            foreach (var block in scan.Blocks)
            {
                try
                {
                    var rule = rules.FirstOrDefault(r => MatchesRule(r, block));
                    if (rule != null)
                    {
                        var detail = BuildDetail(scan, rule, block);
                        result.Details.Add(detail);
                        AddToSummary(result, rule, detail.Quantity);
                    }
                    else
                    {
                        result.Unclassified.Add(BuildUnclassified(scan, block,
                            "Khong quy tac nao khop voi block " + block.BlockName));
                    }
                }
                catch (Exception ex)
                {
                    result.Unclassified.Add(BuildUnclassified(scan, block,
                        "Loi khi phan loai: " + ex.Message));
                }
            }

            // --- Geometry ---
            foreach (var geom in scan.Geometries)
            {
                try
                {
                    var rule = rules.FirstOrDefault(r => MatchesRule(r, geom));
                    if (rule != null)
                    {
                        var detail = BuildDetail(scan, rule, geom);
                        result.Details.Add(detail);
                        AddToSummary(result, rule, detail.Quantity);
                    }
                    else
                    {
                        result.Unclassified.Add(BuildUnclassified(scan, geom,
                            "Khong quy tac nao khop voi geometry " + geom.Kind));
                    }
                }
                catch (Exception ex)
                {
                    result.Unclassified.Add(BuildUnclassified(scan, geom,
                        "Loi khi phan loai: " + ex.Message));
                }
            }

            // Sort summary + details for stable output
            result.Summary.Sort((a, b) =>
            {
                int c = string.CompareOrdinal(a.SystemCode, b.SystemCode);
                if (c != 0) return c;
                return string.CompareOrdinal(a.MaterialCode, b.MaterialCode);
            });
            result.Details.Sort((a, b) => string.CompareOrdinal(a.Handle, b.Handle));

            return result;
        }

        // ----------------------------------------------------------------------

        private static bool MatchesRule(RuleDefinition rule, BlockReferenceInfo block)
        {
            foreach (var cond in rule.Conditions)
            {
                if (RuleMatcher.MatchesBlock(cond, block))
                    return true;
            }
            return false;
        }

        private static bool MatchesRule(RuleDefinition rule, GeometryInfo geom)
        {
            foreach (var cond in rule.Conditions)
            {
                if (RuleMatcher.MatchesGeometry(cond, geom))
                    return true;
            }
            return false;
        }

        private ClassifiedDetail BuildDetail(ScanResult scan, RuleDefinition rule, BlockReferenceInfo block)
        {
            double qty;
            string method;

            switch (rule.Calculation)
            {
                case CalculationKind.Count:
                    qty = 1.0;
                    method = "Dem so luong";
                    break;
                case CalculationKind.SumAttributeValue:
                    if (rule.SumAttribute != null && block.Attributes.TryGetValue(rule.SumAttribute, out var attrVal))
                    {
                        double.TryParse(attrVal, out qty);
                    }
                    else
                    {
                        qty = 0.0;
                    }
                    method = "Cong gia tri attribute '" + rule.SumAttribute + "'";
                    break;
                case CalculationKind.CountIfAttributeEquals:
                    qty = MatchesAttributeCondition(rule.AttributeCondition, block.Attributes) ? 1.0 : 0.0;
                    method = "Dem neu attribute '" + rule.AttributeCondition?.Attribute + "' " +
                             (rule.AttributeCondition?.Operator ?? "equals") + " " + rule.AttributeCondition?.Value;
                    break;
                default:
                    qty = 1.0;
                    method = "Dem so luong";
                    break;
            }

            return new ClassifiedDetail
            {
                DrawingFile = scan.DrawingFile,
                Handle = block.Identity?.Handle,
                Layer = block.Layer,
                ObjectType = "BlockReference",
                BlockName = block.BlockName,
                EffectiveBlockName = block.EffectiveName,
                AttributesJson = SerializeAttributes(block.Attributes),
                RawLength = 0,
                RawUnit = _unit.SourceUnitText,
                ConvertedLength = 0,
                ConvertedUnit = _unit.OutputUnit,
                CalculationMethod = method,
                RuleCode = rule.Code,
                SystemCode = rule.SystemCode,
                MaterialCode = rule.MaterialCode,
                MaterialName = rule.MaterialName,
                Specification = rule.Specification,
                Unit = rule.Unit,
                Quantity = qty,
                SourceFile = block.Identity?.SourceFile,
                Layout = block.Identity?.Layout,
                SpaceKind = block.Identity?.Space.ToString(),
                IsFromXref = block.Identity?.IsFromXref ?? false,
                XrefBlockName = block.Identity?.XrefBlockName,
                Status = "OK"
            };
        }

        private ClassifiedDetail BuildDetail(ScanResult scan, RuleDefinition rule, GeometryInfo geom)
        {
            double qty;
            string method;

            switch (rule.Calculation)
            {
                case CalculationKind.Count:
                    qty = 1.0;
                    method = "Dem so luong";
                    break;
                case CalculationKind.SumLength:
                    qty = _unit.ToOutput(geom.RawLength, out _);
                    method = "Cong chieu dai";
                    break;
                case CalculationKind.SumLengthTimesFactor:
                    qty = _unit.ToOutput(geom.RawLength, out _) * rule.Factor;
                    method = "Cong chieu dai x he so " + rule.Factor;
                    break;
                case CalculationKind.SumLengthCeilingStep:
                    qty = CeilingStep(_unit.ToOutput(geom.RawLength, out _), rule.CeilingStep);
                    method = "Cong chieu dai, lam tron len buoc " + rule.CeilingStep;
                    break;
                default:
                    qty = _unit.ToOutput(geom.RawLength, out _);
                    method = "Cong chieu dai";
                    break;
            }

            return new ClassifiedDetail
            {
                DrawingFile = scan.DrawingFile,
                Handle = geom.Identity?.Handle,
                Layer = geom.Layer,
                ObjectType = geom.Kind.ToString(),
                BlockName = null,
                EffectiveBlockName = null,
                AttributesJson = null,
                RawLength = geom.RawLength,
                RawUnit = _unit.SourceUnitText,
                ConvertedLength = qty,
                ConvertedUnit = _unit.OutputUnit,
                CalculationMethod = method,
                RuleCode = rule.Code,
                SystemCode = rule.SystemCode,
                MaterialCode = rule.MaterialCode,
                MaterialName = rule.MaterialName,
                Specification = rule.Specification,
                Unit = rule.Unit,
                Quantity = qty,
                SourceFile = geom.Identity?.SourceFile,
                Layout = geom.Identity?.Layout,
                SpaceKind = geom.Identity?.Space.ToString(),
                IsFromXref = geom.Identity?.IsFromXref ?? false,
                XrefBlockName = geom.Identity?.XrefBlockName,
                Status = "OK"
            };
        }

        private static UnclassifiedItem BuildUnclassified(ScanResult scan, BlockReferenceInfo block, string reason)
        {
            return new UnclassifiedItem
            {
                DrawingFile = scan.DrawingFile,
                Handle = block.Identity?.Handle,
                Layer = block.Layer,
                ObjectType = "BlockReference",
                BlockName = block.BlockName,
                EffectiveBlockName = block.EffectiveName,
                AttributesJson = SerializeAttributes(block.Attributes),
                RawLength = 0,
                SpaceKind = block.Identity?.Space.ToString(),
                Layout = block.Identity?.Layout,
                SourceFile = block.Identity?.SourceFile,
                Reason = reason
            };
        }

        private static UnclassifiedItem BuildUnclassified(ScanResult scan, GeometryInfo geom, string reason)
        {
            return new UnclassifiedItem
            {
                DrawingFile = scan.DrawingFile,
                Handle = geom.Identity?.Handle,
                Layer = geom.Layer,
                ObjectType = geom.Kind.ToString(),
                RawLength = geom.RawLength,
                SpaceKind = geom.Identity?.Space.ToString(),
                Layout = geom.Identity?.Layout,
                SourceFile = geom.Identity?.SourceFile,
                Reason = reason
            };
        }

        private static void AddToSummary(ClassificationResult result, RuleDefinition rule, double quantity)
        {
            var row = result.Summary.FirstOrDefault(s =>
                s.SystemCode == rule.SystemCode &&
                s.MaterialCode == rule.MaterialCode &&
                s.Unit == rule.Unit &&
                s.Specification == rule.Specification);

            if (row == null)
            {
                row = new SummaryRow
                {
                    SystemCode = rule.SystemCode,
                    MaterialCode = rule.MaterialCode,
                    MaterialName = rule.MaterialName,
                    Specification = rule.Specification,
                    Unit = rule.Unit,
                    TotalQuantity = 0,
                    ObjectCount = 0,
                    StatusMessage = "OK"
                };
                result.Summary.Add(row);
            }

            row.TotalQuantity += quantity;
            row.ObjectCount++;
        }

        private static string SerializeAttributes(Dictionary<string, string> attrs)
        {
            if (attrs == null || attrs.Count == 0) return null;
            return string.Join("; ", attrs.Select(kv => kv.Key + "=" + kv.Value));
        }

        private static double CeilingStep(double value, double step)
        {
            if (step <= 0) return value;
            return Math.Ceiling(value / step) * step;
        }

        /// <summary>
        /// Kiem tra dieu kien AttributeCondition doi voi block attributes.
        /// Ho tro: equals, notEquals, contains, greaterThan, lessThan.
        /// </summary>
        private static bool MatchesAttributeCondition(AttributeCondition cond, Dictionary<string, string> attrs)
        {
            if (cond == null || string.IsNullOrEmpty(cond.Attribute)) return false;
            if (attrs == null || attrs.Count == 0) return false;

            if (!attrs.TryGetValue(cond.Attribute, out var actual))
            {
                // Thu tim khong phan biet hoa/thuong
                foreach (var kv in attrs)
                {
                    if (string.Equals(kv.Key, cond.Attribute, StringComparison.OrdinalIgnoreCase))
                    {
                        actual = kv.Value;
                        break;
                    }
                }
            }

            if (actual == null) return false;

            switch ((cond.Operator ?? "equals").ToLowerInvariant())
            {
                case "equals":
                    return string.Equals(actual, cond.Value, StringComparison.OrdinalIgnoreCase);
                case "notequals":
                    return !string.Equals(actual, cond.Value, StringComparison.OrdinalIgnoreCase);
                case "contains":
                    return actual.IndexOf(cond.Value ?? "", StringComparison.OrdinalIgnoreCase) >= 0;
                case "greaterthan":
                    if (double.TryParse(actual, out double gActual) && double.TryParse(cond.Value, out double gTarget))
                        return gActual > gTarget;
                    return false;
                case "lessthan":
                    if (double.TryParse(actual, out double lActual) && double.TryParse(cond.Value, out double lTarget))
                        return lActual < lTarget;
                    return false;
                default:
                    return string.Equals(actual, cond.Value, StringComparison.OrdinalIgnoreCase);
            }
        }
    }
}