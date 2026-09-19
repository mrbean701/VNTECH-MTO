namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// Dinh danh mot doi tuong trong ban ve va nguon goc cua no.
    /// Phuc vu truy vet (FR09) va tranh tinh lap khi quet nhieu layout.
    /// </summary>
    public sealed class ObjectIdentity
    {
        /// <summary>Handle cua doi tuong trong database no sinusol.</summary>
        public string Handle { get; set; }

        /// <summary>Duong dan file DWG nguon (r?ng neu la b?n v? dang mo).</summary>
        public string SourceFile { get; set; }

        /// <summary>Ten layout/paper space chua doi tuong (r?ng neu o Model).</summary>
        public string Layout { get; set; }

        /// <summary>Khong gian: Model hay Paper.</summary>
        public SpaceKind Space { get; set; }

        /// <summary>True neu doi tuong nam trong mot Xref.</summary>
        public bool IsFromXref { get; set; }

        /// <summary>Ten block Xref bao ngoai (neu co).</summary>
        public string XrefBlockName { get; set; }

        public override string ToString()
        {
            return string.Format("{0} [{1}]@{2}:{3}",
                Handle, SourceFile, Space, Layout);
        }
    }
}