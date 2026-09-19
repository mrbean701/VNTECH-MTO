namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// Thong tin mot Xref duoc phat hien trong ban ve. Ung voi FR05.
    /// </summary>
    public sealed class XrefReference
    {
        public string BlockName { get; set; }

        /// <summary>Duong dan day du toi file nguon.</summary>
        public string FullPath { get; set; }

        /// <summary>Co file nguon ton tai tren dia khong.</summary>
        public bool SourceExists { get; set; }

        /// <summary>Co dang unload hay khong.</summary>
        public bool IsUnloaded { get; set; }

        /// <summary>Cap do xref (top-level = 1).</summary>
        public int NestLevel { get; set; }

        /// <summary>So lan dong block nay duoc chen trong ban ve.</summary>
        public int InsertionCount { get; set; }

        /// <summary>True neu bi chen lap (duplicate).</summary>
        public bool IsDuplicatedInsertion { get; set; }

        /// <summary>True neu co vong lap long nhau.</summary>
        public bool IsCyclicNested { get; set; }

        public string StatusMessage { get; set; }
    }
}