using System;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using MTOPlugin.Core.Models;

// AutoCAD 2023 (net48) va 2025 (net8) deu dat Extents3d o DatabaseServices
using AcadExtentsAlias = Autodesk.AutoCAD.DatabaseServices.Extents3d;

namespace MTOPlugin.Scanner
{
    /// <summary>
    /// Cau noi giua UI panel (MainPanel) va AutoCadScanner: cung cap delegate
    /// de panel goi quet thuc te khi nguoi dung bam nut.
    ///
    /// QUAN TRONG - AN TOAN:
    ///   Truoc day class nay KHONG boc try/catch. Bat ky loi nao tu AutoCAD API
    ///   (vi du `ent.GeometricExtents` nem exception voi entity da xoa / block rong)
    ///   se lan ra ngoai va lam AutoCAD bao:
    ///       FATAL ERROR: Unhandled e0434352h Exception
    ///   Nay MOI phuong thuc deu boc try/catch, ghi log va tra ket qua an toan.
    /// </summary>
    public sealed class ScannerHostBridge
    {
        private readonly Document _doc;

        public ScannerHostBridge(Document doc)
        {
            _doc = doc ?? throw new ArgumentNullException(nameof(doc));
        }

        /// <summary>
        /// Quet ban ve. KHONG BAO GIO nem exception ra ngoai: neu loi thi
        /// tra ve ScanResult rong va ghi log.
        /// </summary>
        public ScanResult Scan(ScanOptions options)
        {
            try
            {
                if (options == null)
                    throw new ArgumentNullException(nameof(options));

                if (_doc == null)
                {
                    Log("Scan: document = null");
                    return new ScanResult();
                }

                return AutoCadScanner.Scan(_doc, options);
            }
            catch (System.Exception ex)
            {
                Log("Scan THAT BAI: " + ex.GetType().Name + " - " + ex.Message);
                Log("   Stack: " + ex.StackTrace);
                // Tra ve ket qua rong de panel hien thi thay vi sap AutoCAD
                return new ScanResult();
            }
        }

        /// <summary>
        /// Zoom toi doi tuong theo Handle. KHONG BAO GIO nem exception.
        /// </summary>
        public bool ZoomToHandle(string handle, string sourceFile)
        {
            Editor ed = null;
            try
            {
                if (_doc == null) return false;
                ed = _doc.Editor;

                ulong hVal;
                if (!ulong.TryParse(handle, System.Globalization.NumberStyles.HexNumber,
                        System.Globalization.CultureInfo.InvariantCulture, out hVal))
                {
                    SafeWrite(ed, "\nHandle khong hop le: " + handle);
                    return false;
                }

                var hdl = MtoCompat.NewHandle(hVal);
                ObjectId id;
                if (!_doc.Database.TryGetObjectId(hdl, out id))
                {
                    SafeWrite(ed, "\nKhong con doi tuong handle " + handle);
                    return false;
                }

                using (var tr = _doc.Database.TransactionManager.StartTransaction())
                {
                    var ent = tr.GetObject(id, OpenMode.ForRead) as Entity;
                    if (ent == null)
                    {
                        tr.Commit();
                        SafeWrite(ed, "\nKhong doc duoc doi tuong handle " + handle);
                        return false;
                    }

                    // GeometricExtents la cho DE NEM EXCEPTION NHAT:
                    // entity da xoa, block rong, TEXT khong co hinh hoc...
                    AcadExtentsAlias ge = default(AcadExtentsAlias);
                    bool haveExtents = false;
                    try
                    {
                        ge = ent.GeometricExtents;
                        haveExtents = true;
                    }
                    catch (System.Exception exGe)
                    {
                        Log("GeometricExtents loi voi handle " + handle + ": " + exGe.Message);
                        haveExtents = false;
                    }

                    if (!haveExtents || !MtoCompat.ExtentsValid(ge))
                    {
                        // Van chon doi tuong de nguoi dung thay, chi khong zoom duoc
                        try { ed.SetImpliedSelection(new ObjectId[] { id }); ed.UpdateScreen(); }
                        catch (System.Exception) { }
                        tr.Commit();
                        SafeWrite(ed, "\nDoi tuong khong co kich thuoc huu han - da chon doi tuong (Handle " + handle + ").");
                        return true;
                    }

                    var c = MtoCompat.ExtentsCenter(ge);
                    var hh = Math.Max(ge.MaxPoint.Y - ge.MinPoint.Y, 1.0) * 2;
                    var ww = Math.Max(ge.MaxPoint.X - ge.MinPoint.X, 1.0) * 2;
                    try { MtoCompat.SetView(ed, c.X, c.Y, hh, ww); }
                    catch (System.Exception exV) { Log("SetView loi: " + exV.Message); }

                    try
                    {
                        ed.SetImpliedSelection(new ObjectId[] { id });
                        ed.UpdateScreen();
                    }
                    catch (System.Exception) { }

                    tr.Commit();
                }

                SafeWrite(ed, "\nDa truy vet den doi tuong (Handle " + handle + ").");
                return true;
            }
            catch (System.Exception ex)
            {
                Log("ZoomToHandle THAT BAI (" + handle + "): " + ex.GetType().Name + " - " + ex.Message);
                SafeWrite(ed, "\nLoi truy vet Handle " + handle + ": " + ex.Message);
                return false;
            }
        }

        /// <summary>Ghi thong bao len dong lenh, khong bao gio nem loi.</summary>
        private static void SafeWrite(Editor ed, string msg)
        {
            try { ed?.WriteMessage(msg); } catch (System.Exception) { }
        }

        /// <summary>Ghi log chan doan, khong bao gio nem loi.</summary>
        private static void Log(string msg)
        {
            try
            {
                var log = ApplicationPlugin.StartupLog;
                if (log != null) log.Log("[BRIDGE] " + msg);
            }
            catch (System.Exception) { }
        }
    }
}
