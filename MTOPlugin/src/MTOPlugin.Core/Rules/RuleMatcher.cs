using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using MTOPlugin.Core.Models;

namespace MTOPlugin.Core.Rules
{
    /// <summary>
    /// Trung khip khop dieu kien quy tac doi voi mot doi tuong (block hoac geometry).
    /// Kiem tra AND cac dieu kien: layer, block, attributes, geometry, color, linetype.
    /// H? tr? wildcard pattern (dau '*') va regex.
    /// </summary>
    public static class RuleMatcher
    {
        /// <summary>
        /// Kiem tra doi tuong block co khop dieu kien quy tac khong.
        /// </summary>
        public static bool MatchesBlock(RuleCondition cond, BlockReferenceInfo block)
        {
            if (cond == null) return false;

            if (!MatchScalar(cond.EntityKind, "block") && cond.EntityKind != "*")
                return false;

            // Layer
            if (!MatchList(cond.Layers, block.Layer))
                return false;

            // Block name: ho tro danh sach ';', wildcard, va regex.
            // Neu co it nhat mot bo chon ten block thi phai khop it nhat mot bo.
            bool hasNameSelector = cond.BlockNames != "*" || cond.BlockNameRegex != null ||
                                   cond.EffectiveBlockNames != "*";
            if (hasNameSelector)
            {
                var blockName = block.BlockName ?? "";
                var effName = block.EffectiveName ?? "";

                bool matchedByName = false;
                if (cond.BlockNames != "*")
                {
                    var patterns = cond.BlockNames.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
                    matchedByName = patterns.Any(p => MatchWildcard(p.Trim(), blockName));
                }

                bool matchedByRegex = false;
                if (!matchedByName && cond.BlockNameRegex != null)
                {
                    matchedByRegex = Regex.IsMatch(blockName, cond.BlockNameRegex, RegexOptions.IgnoreCase);
                }

                bool matchedByEffective = false;
                if (!matchedByName && !matchedByRegex && cond.EffectiveBlockNames != "*")
                {
                    var patterns = cond.EffectiveBlockNames.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
                    matchedByEffective = patterns.Any(p => MatchWildcard(p.Trim(), effName));
                }

                if (!(matchedByName || matchedByRegex || matchedByEffective))
                    return false;
            }

            // Dynamic block requirement
            if (cond.RequireDynamicBlock.HasValue && cond.RequireDynamicBlock.Value && !block.IsDynamic)
                return false;

            // Dynamic property condition
            if (cond.DynamicProperty != null && !string.IsNullOrEmpty(cond.DynamicProperty.PropertyName))
            {
                if (!MatchDynamicProperty(cond.DynamicProperty, block))
                    return false;
            }

            // Attributes: "KEY=VALUE" pattern separated by ';'
            if (!string.IsNullOrEmpty(cond.Attributes))
            {
                if (!MatchAttributes(cond.Attributes, block.Attributes))
                    return false;
            }

            // Color
            if (cond.ColorIndexes != "*")
            {
                if (!MatchIntList(cond.ColorIndexes, block.ColorIndex))
                    return false;
            }

            // Linetype
            if (cond.Linetypes != "*")
            {
                if (!MatchList(cond.Linetypes, block.Linetype ?? ""))
                    return false;
            }

            return true;
        }

        /// <summary>
        /// Kiem tra doi tuong hinh hoc co khop dieu kien quy tac khong.
        /// </summary>
        public static bool MatchesGeometry(RuleCondition cond, GeometryInfo geom)
        {
            if (cond == null) return false;

            if (!MatchScalar(cond.EntityKind, "geometry") && cond.EntityKind != "*")
                return false;

            if (!MatchList(cond.Layers, geom.Layer))
                return false;

            if (cond.GeometryKinds != "*")
            {
                var kindName = geom.Kind.ToString();
                if (!MatchList(cond.GeometryKinds, kindName))
                    return false;
            }

            if (cond.Linetypes != "*")
            {
                if (!MatchList(cond.Linetypes, geom.Linetype ?? ""))
                    return false;
            }

            if (cond.ColorIndexes != "*")
            {
                if (!MatchIntList(cond.ColorIndexes, geom.ColorIndex))
                    return false;
            }

            // Block-geometry rules: block/entity kind
            if (cond.BlockNames != "*" && cond.EntityKind == "geometry")
            {
                // block conditions on geometry -> skip (khong khop vi geometry khong co ten block)
                return false;
            }

            return true;
        }

        // -----------------------------------------------------------------------

        private static bool MatchList(string patternList, string value)
        {
            if (patternList == "*" || string.IsNullOrWhiteSpace(patternList))
                return true;

            var items = patternList.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            return items.Any(i => MatchWildcard(i.Trim(), value));
        }

        private static bool MatchIntList(string patternList, int value)
        {
            if (patternList == "*" || string.IsNullOrWhiteSpace(patternList)) return true;
            var items = patternList.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            return items.Any(i =>
            {
                int.TryParse(i.Trim(), out int v);
                return v == value;
            });
        }

        private static bool MatchScalar(string pattern, string value)
        {
            if (pattern == "*") return true;
            if (string.IsNullOrEmpty(pattern)) return false;
            return MatchWildcard(pattern, value ?? "");
        }

        /// <summary>
        /// Simple wildcard matching with '?' and '*'.
        /// '*' = match 0..N characters, '?' = match exactly 1 character.
        /// </summary>
        public static bool MatchWildcard(string pattern, string input)
        {
            if (string.IsNullOrEmpty(pattern)) return true;
            if (string.IsNullOrEmpty(input)) return false;
            if (pattern == "*") return true;

            int pIdx = 0;
            int iIdx = 0;
            int starPIdx = -1;
            int starIIdx = -1;

            while (iIdx < input.Length)
            {
                if (pIdx < pattern.Length && (pattern[pIdx] == '?' || char.ToLower(pattern[pIdx]) == char.ToLower(input[iIdx])))
                {
                    pIdx++;
                    iIdx++;
                }
                else if (pIdx < pattern.Length && pattern[pIdx] == '*')
                {
                    starPIdx = pIdx;
                    starIIdx = iIdx;
                    pIdx++;
                }
                else if (starPIdx >= 0)
                {
                    pIdx = starPIdx + 1;
                    starIIdx++;
                    iIdx = starIIdx;
                }
                else
                {
                    return false;
                }
            }

            while (pIdx < pattern.Length && pattern[pIdx] == '*')
                pIdx++;

            return pIdx == pattern.Length;
        }

        /// <summary>
        /// Kiem tra dieu kien attribute: "HV=1;ATTR=2" hoac "HV!=~3" (bugu = "~").
        /// </summary>
        private static bool MatchAttributes(string condAttr, Dictionary<string, string> blockAttrs)
        {
            if (string.IsNullOrEmpty(condAttr)) return true;
            if (blockAttrs == null || blockAttrs.Count == 0) return false;

            var conditions = condAttr.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (var c in conditions)
            {
                var trimmed = c.Trim();
                if (string.IsNullOrEmpty(trimmed)) continue;

                bool negated = false;
                if (trimmed.StartsWith("~"))
                {
                    negated = true;
                    trimmed = trimmed.Substring(1);
                }

                int eqIdx = trimmed.IndexOf('=');
                if (eqIdx < 0) continue;

                var key = trimmed.Substring(0, eqIdx).Trim();
                var valPattern = trimmed.Substring(eqIdx + 1).Trim();

                bool found = false;
                foreach (var kvp in blockAttrs)
                {
                    if (string.Equals(kvp.Key, key, StringComparison.OrdinalIgnoreCase))
                    {
                        found = MatchWildcard(valPattern, kvp.Value);
                        break;
                    }
                }

                if (negated)
                {
                    if (found) return false;
                }
                else
                {
                    if (!found) return false;
                }
            }
            return true;
        }

        /// <summary>
        /// Kiem tra dieu kien dynamic property.
        /// Ho tro: equals, contains, greaterThan, lessThan.
        /// </summary>
        private static bool MatchDynamicProperty(DynamicPropertyCondition cond, BlockReferenceInfo block)
        {
            if (cond == null || string.IsNullOrEmpty(cond.PropertyName)) return true;

            if (block.DynamicProperties == null || block.DynamicProperties.Count == 0)
                return false;

            if (!block.DynamicProperties.TryGetValue(cond.PropertyName, out var actual))
                return false;

            var actualStr = actual?.ToString() ?? "";
            var targetStr = cond.Value ?? "";

            switch ((cond.Operator ?? "equals").ToLowerInvariant())
            {
                case "equals":
                    return string.Equals(actualStr, targetStr, StringComparison.OrdinalIgnoreCase);
                case "contains":
                    return actualStr.IndexOf(targetStr, StringComparison.OrdinalIgnoreCase) >= 0;
                case "greaterthan":
                    if (double.TryParse(actualStr, out double gA) && double.TryParse(targetStr, out double gT))
                        return gA > gT;
                    return false;
                case "lessthan":
                    if (double.TryParse(actualStr, out double lA) && double.TryParse(targetStr, out double lT))
                        return lA < lT;
                    return false;
                default:
                    return string.Equals(actualStr, targetStr, StringComparison.OrdinalIgnoreCase);
            }
        }
    }
}