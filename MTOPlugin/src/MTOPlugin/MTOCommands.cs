using System;
using System.IO;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Runtime;

// LUU Y (da kiem chung bang reflection tren acdbmgd.dll cua AutoCAD 2023):
// Extents3d nam o Autodesk.AutoCAD.DatabaseServices, KHONG phai Geometry.
// => Dung chung mot alias cho ca net48 (AutoCAD 2023) va net8 (AutoCAD 2025+).
using AcadExtents = Autodesk.AutoCAD.DatabaseServices.Extents3d;

namespace MTOPlugin
{
    /// <summary>
    /// Cac lenh AutoCAD cua plugin MTO.
    ///  - MTO           : mo panel boc tach khoi luong (PaletteSet).
    ///  - MTOZOOM       : truy vet doi tuong theo Handle (FR09).
    ///  - MTOTHONGKE    : quet + xuat Excel nhanh qua lenh (khong can panel).
    /// </summary>
    public class MTOCommands
    {
        private UI.PaletteWrapper _palette;

        [CommandMethod("MTO")]
        public void OpenPanel()
        {
            try
            {
                var doc = Application.DocumentManager.MdiActiveDocument;
                if (doc == null) return;

                if (_palette == null)
                {
                    _palette = new UI.PaletteWrapper(doc,
                        new Scanner.ScannerHostBridge(doc));
                }
                _palette.Show();
            }
            catch (System.Exception ex)
            {
                WriteLine("\nLoi mo panel: " + ex.Message);
                try { ApplicationPlugin.StartupLog?.Log("[MTO] Loi mo panel: " + ex); }
                catch (System.Exception) { }
            }
        }

        [CommandMethod("MTOZOOM")]
        public void ZoomToHandle()
        {
            try
            {
                var doc = Application.DocumentManager.MdiActiveDocument;
                if (doc == null) return;

                var ed = doc.Editor;
                var pr = ed.GetString("\nNhap Handle doi tuong can tim: ");
                if (pr.Status != PromptStatus.OK) return;

                // Handle trong AutoCAD la chuoi hex, vd "1A2B"
                ulong handleValue;
                if (!ulong.TryParse(pr.StringResult,
                        System.Globalization.NumberStyles.HexNumber,
                        System.Globalization.CultureInfo.InvariantCulture, out handleValue))
                {
                    ed.WriteMessage("\nHandle khong hop le.");
                    return;
                }

                var h = MtoCompat.NewHandle(handleValue);
                ObjectId id;
                if (!doc.Database.TryGetObjectId(h, out id))
                {
                    ed.WriteMessage("\nKhong tim thay doi tuong co handle " + pr.StringResult);
                    return;
                }

                using (var tr = doc.Database.TransactionManager.StartTransaction())
                {
                    var ent = tr.GetObject(id, OpenMode.ForRead) as Entity;
                    if (ent == null)
                    {
                        ed.WriteMessage("\nKhong doc duoc doi tuong handle " + pr.StringResult);
                        tr.Commit();
                        return;
                    }

                    // GeometricExtents co the nem exception -> boc rieng
                    AcadExtents ge = default(AcadExtents);
                    bool haveExtents = false;
                    try
                    {
                        ge = ent.GeometricExtents;
                        haveExtents = true;
                    }
                    catch (System.Exception exGe)
                    {
                        ed.WriteMessage("\nDoi tuong khong co kich thuoc huu han: " + exGe.Message);
                    }

                    if (haveExtents) ZoomTo(doc, ge);
                    ed.WriteMessage("\nDa tim thay " + ent.GetType().Name + " - layer " + ent.Layer);
                    tr.Commit();
                }
            }
            catch (System.Exception ex)
            {
                WriteLine("\nLoi truy vet: " + ex.Message);
                try { ApplicationPlugin.StartupLog?.Log("[MTOZOOM] " + ex); }
                catch (System.Exception) { }
            }
        }

        private static void ZoomTo(Document doc, AcadExtents extents)
        {
            try
            {
                if (!MtoCompat.ExtentsValid(extents)) return;
                var center = MtoCompat.ExtentsCenter(extents);
                var height = Math.Max(extents.MaxPoint.Y - extents.MinPoint.Y, 1.0);
                var width = Math.Max(extents.MaxPoint.X - extents.MinPoint.X, 1.0);
                MtoCompat.SetView(doc.Editor, center.X, center.Y, height, width);
            }
            catch (System.Exception) { }
        }

        /// <summary>
        /// Ghi thong bao len dong lenh mot cach AN TOAN.
        /// (Ban cu goi thang Editor() co the null -> nem NullReferenceException
        ///  NGAY TRONG khoi catch, lam AutoCAD bao FATAL ERROR.)
        /// </summary>
        private static void WriteLine(string msg)
        {
            try
            {
                var ed = Application.DocumentManager.MdiActiveDocument?.Editor;
                ed?.WriteMessage(msg);
            }
            catch (System.Exception) { }
        }
    }
}