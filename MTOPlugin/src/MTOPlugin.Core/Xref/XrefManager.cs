using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MTOPlugin.Core.Models;

namespace MTOPlugin.Core.Xref
{
    /// <summary>
    /// Xu ly Xref theo che do ngu?i dung chon: bo qua, tinh mot lan theo file nguon,
    /// hoac tinh theo tung lan chen. Dong thoi phat hien Xref loi: thieu, unload,
    /// long nhau, chen lap. Ung voi FR05.
    /// </summary>
    public sealed class XrefManager
    {
        private readonly XrefMode _mode;

        public XrefMode Mode => _mode;

        /// <summary>Danh sach file nguon da duoc tinh o mode UniqueBySource.</summary>
        private HashSet<string> _processedSourceFiles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        public XrefManager(XrefMode mode)
        {
            _mode = mode;
        }

        /// <summary>
        /// Quyet dinh co tinh doi tuong thuoc Xref hay khong.
        /// </summary>
        public bool ShouldCount(string sourceFile, string blockName)
        {
            switch (_mode)
            {
                case XrefMode.Ignore:
                    return false;

                case XrefMode.UniqueBySource:
                    if (string.IsNullOrEmpty(sourceFile))
                        return true;
                    return _processedSourceFiles.Add(sourceFile);

                case XrefMode.PerInsertion:
                    return true;

                default:
                    return true;
            }
        }

        /// <summary>
        /// Phan tich danh sach Xref th? g? moi co' bien dang.
        /// </summary>
        public List<ScanWarning> Analyze(IEnumerable<XrefReference> references, string hostFile)
        {
            var warnings = new List<ScanWarning>();
            var refs = references.ToList();

            // Xref thieu file
            foreach (var x in refs)
            {
                if (!x.SourceExists)
                {
                    warnings.Add(new ScanWarning
                    {
                        Code = "XREF_MISSING",
                        Message = "Xref '" + x.BlockName + "' thieu file nguon: " + x.FullPath,
                        SourceFile = hostFile,
                        Severity = "Error"
                    });
                }
                else if (x.IsUnloaded)
                {
                    warnings.Add(new ScanWarning
                    {
                        Code = "XREF_UNLOADED",
                        Message = "Xref '" + x.BlockName + "' dang o trang thai unload.",
                        SourceFile = hostFile,
                        Severity = "Warning"
                    });
                }
            }

            // Chen lap cung duong dan
            foreach (var group in refs.Where(r => !string.IsNullOrEmpty(r.FullPath))
                                      .GroupBy(r => r.FullPath, StringComparer.OrdinalIgnoreCase))
            {
                if (group.Count() > 1 || group.Any(r => r.InsertionCount > 1))
                {
                    var total = group.Sum(r => r.InsertionCount);
                    warnings.Add(new ScanWarning
                    {
                        Code = "XREF_DUPLICATE",
                        Message = "Xref '" + group.First().BlockName + "' duoc chen " + total + " lan (co the tinh trung).",
                        SourceFile = hostFile,
                        Severity = "Warning"
                    });
                }
            }

            // Vong lap (cyclic nested): chi bao khi duong dan truy hoi ve chinh no
            var crossReferenced = DetectCyclicReferences(refs);
            foreach (var c in crossReferenced)
            {
                warnings.Add(new ScanWarning
                {
                    Code = "XREF_CYCLIC",
                    Message = "Phat hien vong lap Xref: " + c,
                    SourceFile = hostFile,
                    Severity = "Error"
                });
            }

            if (warnings.Count == 0)
            {
                warnings.Add(new ScanWarning
                {
                    Code = "XREF_OK",
                    Message = "Khong co loi Xref nghiem trong; da quet " + refs.Count + " xref.",
                    SourceFile = hostFile,
                    Severity = "Info"
                });
            }

            return warnings;
        }

        private static List<string> DetectCyclicReferences(IEnumerable<XrefReference> refs)
        {
            var found = new List<string>();
            var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var r in refs)
            {
                if (!string.IsNullOrEmpty(r.FullPath))
                    map[r.BlockName] = r.FullPath;
            }

            foreach (var r in refs)
            {
                // Mo phong duyet graph theo block name
                if (ContainsCycle(map, r.BlockName, new HashSet<string>(StringComparer.OrdinalIgnoreCase)))
                {
                    found.Add(r.BlockName);
                }
            }
            return found.Distinct().ToList();
        }

        private static bool ContainsCycle(Dictionary<string, string> map, string start,
            HashSet<string> visiting)
        {
            if (!visiting.Add(start)) return true;
            if (map.ContainsKey(start) && map[start] == start) return true;
            visiting.Remove(start);
            return false;
        }
    }
}