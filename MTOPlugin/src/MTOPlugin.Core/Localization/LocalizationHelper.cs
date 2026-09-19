using System.Collections.Generic;

namespace MTOPlugin.Core.Localization
{
    /// <summary>
    /// Ho tro da ngon ngu (Vietnamese + English).
    /// Su dung cho UI labels, sheet names, column headers.
    /// </summary>
    public static class LocalizationHelper
    {
        public enum Language { Vietnamese, English }

        private static Language _current = Language.Vietnamese;

        public static void SetLanguage(Language lang) => _current = lang;
        public static Language GetLanguage() => _current;

        private static readonly Dictionary<string, string[]> Labels = new Dictionary<string, string[]>
        {
            // key: [vi, en]
            { "APP_TITLE", new[] { "MTOPro - Bóc Tách Khối Lượng M&E", "MTOPro - M&E Quantity Take-Off" } },
            { "STEP1", new[] { "Bước 1: Quét + Phân loại", "Step 1: Scan + Classify" } },
            { "STEP2", new[] { "Bước 2: Xuất Excel", "Step 2: Export Excel" } },
            { "SCAN", new[] { "Quét", "Scan" } },
            { "EXPORT_ALL", new[] { "Xuất TOÀN BỘ", "Export ALL" } },
            { "EXPORT_SELECTED", new[] { "Xuất các mục đã chọn", "Export Selected" } },
            { "RULES_FILE", new[] { "Bộ quy tắc (JSON)", "Rules File (JSON)" } },
            { "BROWSE", new[] { "Browse...", "Browse..." } },
            { "OUTPUT_FILE", new[] { "File xuất (XLSX)", "Output File (XLSX)" } },
            { "SCOPE", new[] { "Phạm vi quét", "Scan Scope" } },
            { "XREF_MODE", new[] { "Chế độ Xref", "Xref Mode" } },
            { "MODEL", new[] { "Toàn bộ Model", "All Model" } },
            { "ALL_LAYOUTS", new[] { "Toàn bộ Layout", "All Layouts" } },
            { "SYSTEM", new[] { "Hệ thống", "System" } },
            { "MATERIAL", new[] { "Vật tư", "Material" } },
            { "UNIT", new[] { "Đơn vị", "Unit" } },
            { "QUANTITY", new[] { "Khối lượng", "Quantity" } },
            { "TOTAL", new[] { "Tổng", "Total" } },
            { "CLASSIFIED", new[] { "Đã phân loại", "Classified" } },
            { "UNCLASSIFIED", new[] { "Chưa phân loại", "Unclassified" } },
            { "WARNINGS", new[] { "Cảnh báo", "Warnings" } },
            { "ERROR", new[] { "Lỗi", "Error" } },
            { "SUCCESS", new[] { "Thành công", "Success" } },
            { "SAVE", new[] { "Lưu", "Save" } },
            { "CANCEL", new[] { "Hủy", "Cancel" } },
            { "ADD", new[] { "Thêm", "Add" } },
            { "DELETE", new[] { "Xóa", "Delete" } },
            { "IMPORT", new[] { "Nhập", "Import" } },
            { "EXPORT", new[] { "Xuất", "Export" } },
            { "VALIDATE", new[] { "Kiểm tra", "Validate" } },
            { "SEARCH", new[] { "Tìm kiếm", "Search" } },
            { "FILTER", new[] { "Lọc", "Filter" } },
            { "ALL", new[] { "Tất cả", "All" } },
            { "SELECT_ALL", new[] { "Chọn tất cả", "Select All" } },
            { "DESELECT_ALL", new[] { "Bỏ chọn", "Deselect All" } },
        };

        /// <summary>
        /// Lay label theo ngon ngu hien tai.
        /// </summary>
        public static string Get(string key)
        {
            if (Labels.TryGetValue(key, out var labels))
                return _current == Language.Vietnamese ? labels[0] : labels[1];
            return key;
        }

        /// <summary>
        /// Lay label theo ngon ngu chi dinh.
        /// </summary>
        public static string Get(string key, Language lang)
        {
            if (Labels.TryGetValue(key, out var labels))
                return lang == Language.Vietnamese ? labels[0] : labels[1];
            return key;
        }
    }
}
