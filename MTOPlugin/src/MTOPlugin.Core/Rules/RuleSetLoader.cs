using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json;

namespace MTOPlugin.Core.Rules
{
    /// <summary>
    /// Nhap du lieu quy tac tu file JSON. ung voi cau truc "bo quy t?c" trong de tai.
    /// File JSON co cau truc:
    /// {
    ///   "name": "...",
    ///   "version": "1.0",
    ///   "rules": [ { ... }, ... ]
    /// }
    /// </summary>
    public static class RuleSetLoader
    {
        /// <summary>
        /// Doc file JSON tra ve RuleSet hoac null neu loi.
        /// </summary>
        public static RuleSet Load(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath))
                throw new ArgumentException("Duong dan file quy tac khong duoc de trong.");

            if (!File.Exists(filePath))
                throw new FileNotFoundException("Khong tim thay file quy tac: " + filePath);

            var json = File.ReadAllText(filePath);
            return Deserialize(json);
        }

        /// <summary>
        /// Deserialize tu JSON string.
        /// </summary>
        public static RuleSet Deserialize(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
                return new RuleSet();

            try
            {
                return JsonConvert.DeserializeObject<RuleSet>(json, new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore,
                    MissingMemberHandling = MissingMemberHandling.Ignore,
                    DefaultValueHandling = DefaultValueHandling.Include
                });
            }
            catch (JsonException ex)
            {
                throw new InvalidDataException("Loi doc file JSON quy tac: " + ex.Message, ex);
            }
        }

        /// <summary>
        /// Luu RuleSet ra file JSON.
        /// </summary>
        public static void Save(RuleSet ruleSet, string filePath)
        {
            if (ruleSet == null) throw new ArgumentNullException(nameof(ruleSet));
            if (string.IsNullOrWhiteSpace(filePath))
                throw new ArgumentException("Duong dan file khong duoc de trong.");

            var json = JsonConvert.SerializeObject(ruleSet, Formatting.Indented,
                new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore,
                    DefaultValueHandling = DefaultValueHandling.Include
                });

            File.WriteAllText(filePath, json);
        }

        /// <summary>
        /// Luu thanh JSON string.
        /// </summary>
        public static string Serialize(RuleSet ruleSet)
        {
            return JsonConvert.SerializeObject(ruleSet, Formatting.Indented,
                new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore,
                    DefaultValueHandling = DefaultValueHandling.Include
                });
        }

        /// <summary>
        /// Kiem tra JSON hop le (khong parse, chi check syntax).
        /// Tra ve null neu hop le, tra ve loi neu khong hop le.
        /// </summary>
        public static string ValidateJson(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
                return "JSON rong.";

            try
            {
                JsonConvert.DeserializeObject(json);
                return null;
            }
            catch (JsonException ex)
            {
                return "JSON khong hop le: " + ex.Message;
            }
        }

        /// <summary>
        /// Kiem tra RuleSet hop le: code, systemCode, materialCode khong trung.
        /// Tra ve danh sach loi (rong = hop le).
        /// </summary>
        public static List<string> ValidateRuleSet(RuleSet ruleSet)
        {
            var issues = new List<string>();
            if (ruleSet == null) { issues.Add("RuleSet null."); return issues; }

            var codes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            int idx = 0;
            foreach (var rule in ruleSet.Rules)
            {
                idx++;
                if (string.IsNullOrWhiteSpace(rule.Code))
                    issues.Add("Rule #" + idx + ": Thiếu Code.");
                else if (!codes.Add(rule.Code))
                    issues.Add("Rule " + rule.Code + ": Code trùng lặp.");
                if (string.IsNullOrWhiteSpace(rule.SystemCode))
                    issues.Add("Rule " + rule.Code + ": Thiếu SystemCode.");
                if (string.IsNullOrWhiteSpace(rule.MaterialCode))
                    issues.Add("Rule " + rule.Code + ": Thiếu MaterialCode.");
                if (string.IsNullOrWhiteSpace(rule.MaterialName))
                    issues.Add("Rule " + rule.Code + ": Thiếu MaterialName.");
                if (string.IsNullOrWhiteSpace(rule.Unit))
                    issues.Add("Rule " + rule.Code + ": Thiếu Unit.");
                if (rule.Conditions == null || rule.Conditions.Count == 0)
                    issues.Add("Rule " + rule.Code + ": Không có Conditions.");
            }
            return issues;
        }

        /// <summary>
        /// Sanitize duong dan file: loai bo ky tu doc hai, dam bao nam trong thu muc cho phep.
        /// </summary>
        public static string SanitizePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) return path;

            // Loai bo ky tu null
            path = path.Replace("\0", "");

            // Chi lay ten file, bo path traversal
            var fileName = Path.GetFileName(path);
            if (string.IsNullOrWhiteSpace(fileName))
                return null;

            // Kiem tra extension hop le
            var ext = Path.GetExtension(fileName).ToLowerInvariant();
            if (ext != ".json" && ext != ".xlsx" && ext != ".csv")
                return null;

            return fileName;
        }
    }
}