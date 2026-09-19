using System;
using System.IO;
using System.Reflection;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Runtime;

[assembly: ExtensionApplication(typeof(MTOPlugin.ApplicationPlugin))]
[assembly: CommandClass(typeof(MTOPlugin.MTOCommands))]

namespace MTOPlugin
{
    /// <summary>
    /// Khoi tao plugin khi load vao AutoCAD.
    ///
    /// Nhiem vu chinh (kien truc LISP-first):
    ///   Tu dong NAP CAC MODULE AUTOLISP (lisp/*.lsp) khi AutoCAD khoi dong, de nguoi
    ///   dung khong phai go APPLOAD thu cong.
    ///
    /// Cach lam:
    ///   1) Xac dinh thu muc LISP nam canh DLL (Contents\Windows\lisp).
    ///   2) Them thu muc do vao bien he thong TRUSTEDPATHS (vi AutoCAD mac dinh
    ///      SECURELOAD=1 se CHAN (load ...) voi file ngoai trusted locations).
    ///   3) Goi (load "mto-loader.lsp") trong ngu canh document.
    ///
    /// Moi buoc deu boc try/catch: neu that bai thi ghi log va VAN tiep tuc
    /// (nguoi dung con cach thu cong: APPLOAD / Startup Suite).
    /// </summary>
    public class ApplicationPlugin : IExtensionApplication
    {
        internal static Logging.SessionLog StartupLog;

        /// <summary>Danh dau da nap LISP cho phien nay (tranh nap lai nhieu lan).</summary>
        private static bool _lispLoaded;

        public void Initialize()
        {
            try
            {
                var asm = Assembly.GetExecutingAssembly();
                var ver = asm.GetName().Version?.ToString() ?? "0.0.0";
                StartupLog = new Logging.SessionLog(
                    Logging.SessionLog.DefaultLogDirectory(),
                    "startup");
                StartupLog.Log("Plugin MTOPlugin v" + ver + " dang khoi tao.");

                // ===== BAO HIEM CUOI: bat MOI exception khong duoc xu ly =====
                // Neu khong co, exception trong managed code lam AutoCAD bao
                // "FATAL ERROR: Unhandled e0434352h Exception" roi THOAT.
                // Handler nay ghi log day du (type/message/stack) de chan doan.
                AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
                try
                {
                    System.Windows.Forms.Application.ThreadException += OnThreadException;
                }
                catch (System.Exception) { }

                Application.DocumentManager.DocumentCreated += DocumentCreated;

                // Nap LISP ngay cho document dang mo (neu co)
                TryLoadLisp(Application.DocumentManager.MdiActiveDocument);

                StartupLog.Log("Khoi tao xong. LISP: " + (_lispLoaded ? "da nap" : "CHUA nap (dung APPLOAD thu cong)"));
            }
            catch (System.Exception ex)
            {
                try { StartupLog?.Error("Loi khoi tao plugin", ex); }
                catch (System.Exception) { }
            }
        }

        /// <summary>
        /// Bat exception khong duoc xu ly tren moi thread - ghi log day du
        /// (stack trace) de chan doan, thay vi de AutoCAD bao FATAL ERROR vo nghia.
        /// </summary>
        private static void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            try
            {
                var ex = e.ExceptionObject as System.Exception;
                StartupLog?.Log("!! EXCEPTION KHONG XU LY (IsTerminating=" + e.IsTerminating + ")");
                if (ex != null)
                {
                    StartupLog?.Log("   Type: " + ex.GetType().FullName);
                    StartupLog?.Log("   Message: " + ex.Message);
                    StartupLog?.Log("   Stack: " + ex.StackTrace);
                    if (ex.InnerException != null)
                        StartupLog?.Log("   Inner: " + ex.InnerException.Message);
                }
                else
                {
                    StartupLog?.Log("   Doi tuong: " + (e.ExceptionObject == null ? "null" : e.ExceptionObject.ToString()));
                }
            }
            catch (System.Exception) { }
        }

        /// <summary>Bat exception tren UI thread.</summary>
        private static void OnThreadException(object sender, System.Threading.ThreadExceptionEventArgs e)
        {
            try
            {
                StartupLog?.Log("!! EXCEPTION TREN UI THREAD");
                if (e.Exception != null)
                {
                    StartupLog?.Log("   Type: " + e.Exception.GetType().FullName);
                    StartupLog?.Log("   Message: " + e.Exception.Message);
                    StartupLog?.Log("   Stack: " + e.Exception.StackTrace);
                }
            }
            catch (System.Exception) { }
        }

        private static void DocumentCreated(object sender, DocumentCollectionEventArgs e)
        {
            try
            {
                StartupLog?.Log("Document mo: " + e.Document.Name);
                // Moi document moi can co LISP (bien LISP la per-document)
                TryLoadLisp(e.Document);
            }
            catch (System.Exception) { }
        }

        // ==================== NAP AUTOLISP ====================

        /// <summary>
        /// Thu muc chua cac module LISP: canh DLL, trong "lisp".
        /// Ho tro ca khi chay tu bin\Debug (lisp o thu muc goc repo).
        /// </summary>
        internal static string ResolveLispDir()
        {
            try
            {
                string dllDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                if (string.IsNullOrEmpty(dllDir)) return null;

                // 1) bundle layout: <...>\Contents\Windows\lisp
                string p1 = Path.Combine(dllDir, "lisp");
                if (File.Exists(Path.Combine(p1, "mto-loader.lsp"))) return p1;

                // 2) layout dev: bin\Debug\net48 -> len 4 cap -> <repo>\lisp
                string p2 = dllDir;
                for (int i = 0; i < 4 && p2 != null; i++)
                {
                    p2 = Path.GetDirectoryName(p2);
                    if (p2 == null) break;
                    string cand = Path.Combine(p2, "lisp");
                    if (File.Exists(Path.Combine(cand, "mto-loader.lsp"))) return cand;
                }
                return null;
            }
            catch { return null; }
        }

        /// <summary>
        /// Them mot thu muc vao TRUSTEDPATHS (neu chua co).
        /// Tra ve true neu thu muc da nam trong danh sach.
        /// </summary>
        internal static bool EnsureTrustedPath(string dir)
        {
            try
            {
                object cur = Application.GetSystemVariable("TRUSTEDPATHS");
                string s = cur == null ? "" : cur.ToString();
                string needle = dir.TrimEnd('\\');
                foreach (string part in s.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries))
                {
                    if (string.Equals(part.Trim().TrimEnd('\\'), needle, StringComparison.OrdinalIgnoreCase))
                        return true;
                }
                string updated = string.IsNullOrWhiteSpace(s) ? dir : (s.TrimEnd(';') + ";" + dir);
                Application.SetSystemVariable("TRUSTEDPATHS", updated);
                return true;
            }
            catch (System.Exception ex)
            {
                try { StartupLog?.Log("Khong them duoc TRUSTEDPATHS (" + dir + "): " + ex.Message); }
                catch (System.Exception) { }
                return false;
            }
        }

        /// <summary>
        /// Nap mto-loader.lsp vao document hien tai.
        /// </summary>
        internal static void TryLoadLisp(Document doc)
        {
            if (doc == null) return;
            try
            {
                string lispDir = ResolveLispDir();
                if (lispDir == null)
                {
                    StartupLog?.Log("Khong tim thay thu muc lisp (mto-loader.lsp).");
                    return;
                }

                // SECURELOAD=1 chan (load ...) ngoai trusted locations
                EnsureTrustedPath(lispDir);

                string loader = Path.Combine(lispDir, "mto-loader.lsp").Replace("\\", "/");
                string home = lispDir.Replace("\\", "/");

                // Dat *MTO-HOME* TRUOC khi load: (findfile ...) cua AutoLISP khong
                // resolve duong dan tuyet doi, nen loader can biet thu muc goc.
                string expr = "(setq *MTO-HOME* \"" + home + "\") "
                            + "(if (findfile \"" + loader + "\") (load \"" + loader + "\")) ";

                doc.SendStringToExecute(expr, true, false, false);
                _lispLoaded = true;
                StartupLog?.Log("Da gui lenh nap LISP (HOME=" + home + "): " + loader);
            }
            catch (System.Exception ex)
            {
                try { StartupLog?.Log("Nap LISP that bai: " + ex.Message); }
                catch (System.Exception) { }
            }
        }

        public void Terminate()
        {
            try
            {
                Application.DocumentManager.DocumentCreated -= DocumentCreated;
                StartupLog?.Log("Plugin dung.");
                StartupLog?.Dispose();
            }
            catch (System.Exception) { }
        }
    }
}
