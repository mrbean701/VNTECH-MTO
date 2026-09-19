using System.Collections.Generic;
using MTOPlugin.Core.Models;

namespace MTOPlugin.Core
{
    /// <summary>
    /// Interface cho viec doc dynamic block properties.
    /// Implementations nam trong Host project (phu thuoc AutoCAD API).
    /// Core chi biet interface, khong biet AutoCAD.
    /// </summary>
    public interface IDynamicBlockReader
    {
        /// <summary>
        /// Kiem tra mot block reference co phai dynamic block khong.
        /// </summary>
        bool IsDynamicBlock(BlockReferenceInfo block);

        /// <summary>
        /// Doc tat ca dynamic properties cua mot dynamic block.
        /// Tra ve dictionary: ten property -> gia tri (object).
        /// Neu khong phai dynamic block, tra ve empty dictionary.
        /// </summary>
        Dictionary<string, object> ReadDynamicProperties(BlockReferenceInfo block);

        /// <summary>
        /// Doc gia tri cua mot dynamic property cu the.
        /// Tra ve null neu property khong ton tai hoac block khong phai dynamic.
        /// </summary>
        object GetPropertyValue(BlockReferenceInfo block, string propertyName);

        /// <summary>
        /// Lay ten hien thi (effective name) cua dynamic block.
        /// Neu khong phai dynamic block, tra ve BlockName goc.
        /// </summary>
        string GetEffectiveName(BlockReferenceInfo block);
    }
}
