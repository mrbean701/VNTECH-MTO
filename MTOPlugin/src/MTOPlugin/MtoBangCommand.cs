using System;
using System.IO;
using System.Linq;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using MTOPlugin.Core.Session;

namespace MTOPlugin
{
    /// <summary>
    /// Lenh MTOBANG: tao bang tong hop khoi luong ngay tren BAN VE MOI
    /// (Database tam -> SaveAs -> mo file moi), khong sua bat ky ban ve goc.
    /// Du lieu lay tu ScanSession cua lan quet gan nhat trong phien.
    /// </summary>
    public sealed class MtoBangCommand
    {
        [CommandMethod("MTOBANG")]
        public void CreateSummaryTable()
        {
            var doc = Application.DocumentManager.MdiActiveDocument;
            if (doc == null) return;
            var ed = doc.Editor;

            if (!ScanSession.HasData)
            {
                ed.WriteMessage(
                    "\nChua co ket qua quet. Hay chay 'Bước 1: Quet + Phan loai' trong panel MTO truoc.");
                return;
            }

            var classification = ScanSession.LastClassification;
            if (classification == null || classification.Summary == null || classification.Summary.Count == 0)
            {
                ed.WriteMessage("\nKhong co du lieu tong hop nao de tao bang.");
                return;
            }

            var filePath = GetSavePath(ed);
            if (string.IsNullOrWhiteSpace(filePath)) return;

            var dir = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            try
            {
                var db = new Database(true, true);
                try
                {
                    using (var tr = db.TransactionManager.StartTransaction())
                    {
                        var bt = (BlockTable)tr.GetObject(db.BlockTableId, OpenMode.ForWrite);
                        var ms = (BlockTableRecord)tr.GetObject(bt[BlockTableRecord.ModelSpace], OpenMode.ForWrite);

                        string[] headers = { "Hệ", "Mã vật tư", "Tên vật tư / công việc", "Quy cách", "Đơn vị", "Khối lượng", "SL đối tượng" };
                        double[] widths = { 16, 20, 70, 40, 12, 18, 20 };
                        double totalWidth = widths.Sum();

                        double startX = 0.0;
                        double y = -10.0;

                        AddText(ms, tr, "BANG TONG HOP KHOI LUONG M&E", startX, 0.0, 6.0);
                        string srcName = ScanSession.LastScan != null ? ScanSession.LastScan.DrawingFile : doc.Name;
                        AddText(ms, tr, "Ban ve nguon: " + srcName, startX, -6.5, 2.5);

                        double x = startX;
                        foreach (string h in headers)
                        {
                            AddText(ms, tr, h, x, y, 4.0);
                            x += widths[Array.IndexOf(headers, h)];
                        }

                        AddLine(ms, tr, startX, y - 0.5, startX + totalWidth, y - 0.5);
                        y -= 5.0;

                        foreach (var s in classification.Summary)
                        {
                            string[] cells =
                            {
                                s.SystemCode,
                                s.MaterialCode,
                                s.MaterialName,
                                s.Specification,
                                s.Unit,
                                Math.Round(s.TotalQuantity, 3).ToString(),
                                s.ObjectCount.ToString()
                            };

                            x = startX;
                            for (int c = 0; c < cells.Length; c++)
                            {
                                AddText(ms, tr, cells[c], x, y, 3.0);
                                x += widths[c];
                            }

                            AddLine(ms, tr, startX, y - 0.3, startX + totalWidth, y - 0.3);
                            y -= 4.2;
                        }

                        double totalQty = classification.Summary.Sum(s => s.TotalQuantity);
                        AddText(ms, tr, "TONG: " + Math.Round(totalQty, 3), startX, y, 3.0);

                        AddText(ms, tr,
                            "Lap bang: " + Environment.UserName + " | " + DateTime.Now.ToString("yyyy-MM-dd HH:mm"),
                            startX, y - 4.0, 2.0);

                        tr.Commit();
                    }

                    db.SaveAs(filePath, DwgVersion.Current);
                }
                finally
                {
                    db.Dispose();
                }

                ed.WriteMessage("\nDa tao bang tong hop: " + filePath);
                Application.DocumentManager.Open(filePath, false);
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage("\nLoi tao bang: " + ex.Message);
            }
        }

        /// <summary>
        /// Lay duong dan file DWG moi.
        /// net8 (AutoCAD 2025+): dung dialog chuan (GetFileNameForSave).
        /// net48 (AutoCAD 2023): API dialog khac ten/khong co => dung nhap duong dan
        /// bang dong lenh (API on dinh moi phien ban, tranh phu thuoc API moi).
        /// Tra ve null neu nguoi dung huy.
        /// </summary>
        private static string GetSavePath(Editor ed)
        {
            string suggested = "BangTongHopMTO_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".dwg";
#if NET8_0_OR_GREATER
            var options = new PromptSaveFileOptions("Chon noi luu bang tong hop (ban ve moi)")
            {
                Filter = "Ban ve AutoCAD (*.dwg)|*.dwg",
                InitialFileName = "BangTongHopMTO_" + DateTime.Now.ToString("yyyyMMdd_HHmmss")
            };
            options.DialogCaption = "Chon noi luu bang tong hop (ban ve moi)";
            var pr = ed.GetFileNameForSave(options);
            if (pr.Status != PromptStatus.OK) return null;
            return pr.StringResult;
#else
            var pr2 = ed.GetString("\nNhap duong dan file DWG moi [" + suggested + "]: ");
            if (pr2.Status != PromptStatus.OK) return null;
            string p = string.IsNullOrWhiteSpace(pr2.StringResult) ? suggested : pr2.StringResult;
            if (!p.EndsWith(".dwg", StringComparison.OrdinalIgnoreCase)) p += ".dwg";
            return p;
#endif
        }

        private static void AddText(BlockTableRecord ms, Transaction tr, string text, double x, double y, double height)
        {
            var t = new DBText
            {
                TextString = text,
                Height = height,
                Position = new Point3d(x, y, 0)
            };
            ms.AppendEntity(t);
            tr.AddNewlyCreatedDBObject(t, true);
        }

        private static void AddLine(BlockTableRecord ms, Transaction tr, double x1, double y1, double x2, double y2)
        {
            var ln = new Line(new Point3d(x1, y1, 0), new Point3d(x2, y2, 0));
            ms.AppendEntity(ln);
            tr.AddNewlyCreatedDBObject(ln, true);
        }
    }
}