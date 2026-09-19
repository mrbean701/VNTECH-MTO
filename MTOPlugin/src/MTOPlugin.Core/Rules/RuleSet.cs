using System;
using System.Collections.Generic;
using System.Linq;

namespace MTOPlugin.Core.Rules
{
    /// <summary>
    /// Tap hop quy tac duoc load tu file cau hinh (JSON hoac Excel).
    /// Co phien ban d? truy vet sheet THONG_TIN_LAN_QUET.
    /// </summary>
    public sealed class RuleSet
    {
        public string Name { get; set; } = "MTO Rules";

        public string Version { get; set; } = "1.0";

        public string Description { get; set; }

        public DateTime? LastModified { get; set; }

        public string CreatedBy { get; set; }

        /// <summary>Danh muc he M&E (HE-DIEN, HE-NUOC, HE-ELV...).</summary>
        public List<SystemDefinition> Systems { get; set; } = new List<SystemDefinition>();

        public List<RuleDefinition> Rules { get; set; } = new List<RuleDefinition>();

        public IReadOnlyList<RuleDefinition> ActiveRules =>
            Rules.Where(r => r.Status == RuleStatus.Active)
                 .OrderByDescending(r => r.Priority)
                 .ThenBy(r => r.Code)
                 .ToList();
    }

    /// <summary>
    /// Danh muc he M&E trong bo quy tac.
    /// </summary>
    public sealed class SystemDefinition
    {
        public string Code { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public string Unit { get; set; }
    }
}