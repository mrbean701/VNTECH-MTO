using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Models;

namespace MTOPlugin.Core.Session
{
    /// <summary>
    /// Luu ket qua lan quet gan nhat trong phien lam viec (in-memory).
    /// Panel gui UI va lenh MTOBANG/MTOZOOM cung doc tu day nen khong can
    /// lam lai viec quet. Dam bao: chi luu khi quet thanh cong.
    /// </summary>
    public static class ScanSession
    {
        public static ScanOptions LastOptions { get; private set; }

        public static ScanResult LastScan { get; private set; }

        public static ClassificationResult LastClassification { get; private set; }

        public static bool HasData
        {
            get { return LastScan != null && LastClassification != null; }
        }

        public static void Store(ScanOptions options, ScanResult scan, ClassificationResult classification)
        {
            LastOptions = options;
            LastScan = scan;
            LastClassification = classification;
        }

        public static void Clear()
        {
            LastOptions = null;
            LastScan = null;
            LastClassification = null;
        }
    }
}