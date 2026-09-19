using System;
using System.IO;
using System.Diagnostics;
using System.Reflection;
using System.Windows.Forms;
using System.Drawing;
using System.Collections.Generic;
using System.Text;
using Microsoft.Win32;
using System.ComponentModel;

// =====================================================================
// MTOPro.Setup - Bo cai 1-click cho MTOPro (boc tach khoi luong M&E)
//
// Kien truc LISP-first => bo cai nay:
//   1) Giai nen payload (lisp/, config/, docs/, dll/)
//   2) Cai cac module AutoLISP vao  %LOCALAPPDATA%\MTOPro\lisp
//   3) Cai bo quy tac mau        ->  %LOCALAPPDATA%\MTOPro\config\rules.json (chi lan dau)
//   4) Cai tai lieu huong dan    ->  %LOCALAPPDATA%\MTOPro\docs
//   5) Cai bundle .NET (neu payload co DLL) -> %APPDATA%\Autodesk\ApplicationPlugins
//         (bundle chua ca lisp/ de plugin .NET tu nap LISP khi khoi dong)
//   6) Ghi "Startup Suite" cua AutoCAD cho mto-loader.lsp (tu nap moi lan mo AutoCAD)
//
// Che do dong lenh:
//    MTOPro.Setup.exe --check             kiem tra, khong cai
//    MTOPro.Setup.exe --install-silent    cai khong hien GUI
//    MTOPro.Setup.exe --uninstall-silent  go cai
// =====================================================================
namespace MTOPro.Setup
{
    static class Program
    {
        const string PayloadResource = "InstallerLisp.Payload.zip";
        const string AppName = "MTOPro";
        const string BundleName = "MTOPro.2023.bundle";
        const string LoaderLsp = "mto-loader.lsp";

        static readonly string AppData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        static readonly string LocalAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        static readonly string PluginRoot = Path.Combine(AppData, "Autodesk", "ApplicationPlugins");
        static readonly string InstallRoot = Path.Combine(LocalAppData, AppName);
        static readonly string LispDir = Path.Combine(InstallRoot, "lisp");
        static readonly string ConfigDir = Path.Combine(InstallRoot, "config");
        static readonly string DocsDir = Path.Combine(InstallRoot, "docs");
        static readonly string RulesTarget = Path.Combine(ConfigDir, "rules.json");
        static readonly string CheckReport = Path.Combine(Path.GetTempPath(), AppName + ".Setup.check.txt");
        static readonly string LastLog = Path.Combine(InstallRoot, "logs", "setup.log");

        [STAThread]
        static int Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                string arg = (args != null && args.Length > 0) ? args[0].ToLowerInvariant() : "";
                if (arg == "--check") return RunCheck();
                if (arg == "--install-silent") return RunInstall(true);
                if (arg == "--uninstall-silent") return RunUninstall(true);

                using (SetupForm f = new SetupForm())
                {
                    Application.Run(f);
                    return f.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Log("LOI nghiem trong: " + ex);
                MessageBox.Show("Cai dat that bai: " + ex.Message + "\r\n\r\nChi tiet: " + LastLog,
                    AppName, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }

        // ======================= Utilities =======================
        internal static void Log(string line)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LastLog));
                File.AppendAllText(LastLog, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " + line + "\r\n", Encoding.UTF8);
            }
            catch { }
        }

        static void WriteCheckReport(string text)
        {
            try { File.WriteAllText(CheckReport, text, new UTF8Encoding(false)); } catch { }
        }

        static byte[] ReadEmbeddedPayload()
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            foreach (string n in asm.GetManifestResourceNames())
            {
                if (n.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                {
                    using (Stream s = asm.GetManifestResourceStream(n))
                    {
                        if (s == null) continue;
                        using (MemoryStream ms = new MemoryStream()) { s.CopyTo(ms); return ms.ToArray(); }
                    }
                }
            }
            return null;
        }

        static string LocatePayload()
        {
            byte[] data = ReadEmbeddedPayload();
            if (data != null && data.Length > 0)
            {
                string dir = Path.Combine(Path.GetTempPath(), AppName + ".Setup.payload");
                Directory.CreateDirectory(dir);
                string zipPath = Path.Combine(dir, "payload.zip");
                File.WriteAllBytes(zipPath, data);
                return zipPath;
            }
            try
            {
                string side = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), AppName + ".Setup.payload.zip");
                if (File.Exists(side) && new FileInfo(side).Length > 0) return side;
            }
            catch { }
            return null;
        }

        static bool HasPayload() { return LocatePayload() != null; }

        /// <summary>Liet ke cac R-key (R24.2 ...) trong registry AutoCAD.</summary>
        static List<string> GetAcadRKeys()
        {
            var names = new Dictionary<string, string>();
            AddKeysFrom(Registry.CurrentUser, "Software\\Autodesk\\AutoCAD", names, "HKCU");
            AddKeysFrom(Registry.LocalMachine, "Software\\Autodesk\\AutoCAD", names, "HKLM");
            AddKeysFrom(Registry.LocalMachine, "Software\\WOW6432Node\\Autodesk\\AutoCAD", names, "HKLM-32");
            var list = new List<string>(names.Values);
            list.Sort();
            return list;
        }

        static void AddKeysFrom(RegistryKey root, string path, Dictionary<string, string> acc, string rootName)
        {
            try
            {
                using (RegistryKey k = root.OpenSubKey(path))
                {
                    if (k == null) return;
                    foreach (string sub in k.GetSubKeyNames())
                        if (sub.Length > 0 && (sub[0] == 'R' || Char.IsDigit(sub[0])))
                            if (!acc.ContainsKey(sub)) acc.Add(sub, rootName + "/" + sub);
                }
            }
            catch { }
        }

        static void ExtractZip(string zipPath, string destDir)
        {
            ProcessStartInfo psi = new ProcessStartInfo("tar.exe", "-xf \"" + zipPath + "\" -C \"" + destDir + "\"");
            psi.UseShellExecute = false; psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi))
            {
                p.WaitForExit(120000);
                if (p.ExitCode != 0) throw new Exception("Giai nen payload that bai (tar.exe exit " + p.ExitCode + ").");
            }
        }

        static void CopyDir(string src, string dst, ref int files)
        {
            Directory.CreateDirectory(dst);
            foreach (string f in Directory.GetFiles(src))
            {
                string t = Path.Combine(dst, Path.GetFileName(f));
                if (File.Exists(t)) { try { File.Delete(t); } catch { } }
                File.Copy(f, t, true);
                files++;
            }
            foreach (string d in Directory.GetDirectories(src))
                CopyDir(d, Path.Combine(dst, Path.GetFileName(d)), ref files);
        }

        static int CountFiles(string dir)
        {
            if (!Directory.Exists(dir)) return 0;
            return Directory.GetFiles(dir, "*", SearchOption.AllDirectories).Length;
        }

        // ======================= STARTUP SUITE =======================
        /// <summary>
        /// Ghi mto-loader.lsp vao "Startup Suite" cua moi profile AutoCAD tim thay.
        /// Day la co che CHUAN cua AutoCAD de tu nap LISP moi lan khoi dong.
        /// </summary>
        static int RegisterStartupSuite(string loaderPath)
        {
            int done = 0;
            foreach (string rk in GetAcadRKeys())
            {
                try
                {
                    bool isLM = rk.StartsWith("HKLM");
                    string rSub = rk.Substring(rk.IndexOf('/') + 1);
                    RegistryKey baseKey = isLM ? Registry.LocalMachine : Registry.CurrentUser;
                    using (RegistryKey acad = baseKey.OpenSubKey("Software\\Autodesk\\AutoCAD\\" + rSub))
                    {
                        if (acad == null) continue;
                        foreach (string acSub in acad.GetSubKeyNames())
                        {
                            if (!acSub.StartsWith("ACAD-")) continue;
                            string profRoot = "Software\\Autodesk\\AutoCAD\\" + rSub + "\\" + acSub + "\\Profiles";
                            using (RegistryKey profs = baseKey.OpenSubKey(profRoot))
                            {
                                if (profs == null) continue;
                                foreach (string prof in profs.GetSubKeyNames())
                                {
                                    string apploadPath = profRoot + "\\" + prof + "\\Dialogs\\Appload";
                                    using (RegistryKey key = baseKey.CreateSubKey(apploadPath))
                                    {
                                        if (key == null) continue;
                                        // tranh trung lap
                                        object nObj = key.GetValue("NumStartup");
                                        int n = (nObj == null) ? 0 : Convert.ToInt32(nObj);
                                        bool exists = false;
                                        for (int i = 1; i <= n; i++)
                                        {
                                            object v = key.GetValue(i + "Startup");
                                            if (v != null && string.Equals(v.ToString(), loaderPath, StringComparison.OrdinalIgnoreCase)) { exists = true; break; }
                                        }
                                        if (!exists)
                                        {
                                            n++;
                                            key.SetValue("NumStartup", n, RegistryValueKind.DWord);
                                            key.SetValue(n + "Startup", loaderPath, RegistryValueKind.String);
                                        }
                                        done++;
                                    }
                                }
                            }
                        }
                    }
                }
                catch (Exception ex) { Log("RegisterStartupSuite(" + rk + ") loi: " + ex.Message); }
            }
            return done;
        }

        static int UnregisterStartupSuite()
        {
            int done = 0;
            foreach (string rk in GetAcadRKeys())
            {
                try
                {
                    bool isLM = rk.StartsWith("HKLM");
                    string rSub = rk.Substring(rk.IndexOf('/') + 1);
                    RegistryKey baseKey = isLM ? Registry.LocalMachine : Registry.CurrentUser;
                    string profRoot = "Software\\Autodesk\\AutoCAD\\" + rSub;
                    using (RegistryKey acad = baseKey.OpenSubKey(profRoot))
                    {
                        if (acad == null) continue;
                        foreach (string acSub in acad.GetSubKeyNames())
                        {
                            if (!acSub.StartsWith("ACAD-")) continue;
                            string pRoot = profRoot + "\\" + acSub + "\\Profiles";
                            using (RegistryKey profs = baseKey.OpenSubKey(pRoot))
                            {
                                if (profs == null) continue;
                                foreach (string prof in profs.GetSubKeyNames())
                                {
                                    string ap = pRoot + "\\" + prof + "\\Dialogs\\Appload";
                                    using (RegistryKey key = baseKey.OpenSubKey(ap, true))
                                    {
                                        if (key == null) continue;
                                        object nObj = key.GetValue("NumStartup");
                                        int n = (nObj == null) ? 0 : Convert.ToInt32(nObj);
                                        var keep = new List<string>();
                                        for (int i = 1; i <= n; i++)
                                        {
                                            object v = key.GetValue(i + "Startup");
                                            if (v == null) continue;
                                            string s = v.ToString();
                                            if (s.IndexOf("mto-loader.lsp", StringComparison.OrdinalIgnoreCase) >= 0) { done++; continue; }
                                            keep.Add(s);
                                        }
                                        for (int i = 1; i <= n; i++) { try { key.DeleteValue(i + "Startup", false); } catch { } }
                                        for (int i = 0; i < keep.Count; i++) key.SetValue((i + 1) + "Startup", keep[i], RegistryValueKind.String);
                                        key.SetValue("NumStartup", keep.Count, RegistryValueKind.DWord);
                                    }
                                }
                            }
                        }
                    }
                }
                catch { }
            }
            return done;
        }

        // ======================= CHECK =======================
        static int RunCheck()
        {
            var sb = new StringBuilder();
            sb.AppendLine("=== " + AppName + ".Setup --check ===");
            sb.AppendLine("AutoCAD (registry):");
            var keys = GetAcadRKeys();
            if (keys.Count == 0) sb.AppendLine("  (khong tim thay)");
            foreach (string k in keys) sb.AppendLine("  " + k);
            sb.AppendLine();
            sb.AppendLine("HasPayload      = " + HasPayload());
            sb.AppendLine("InstallRoot     = " + InstallRoot);
            sb.AppendLine("LispDir         = " + LispDir + "  (hien co " + CountFiles(LispDir) + " file)");
            sb.AppendLine("RulesTarget     = " + RulesTarget + "  (ton tai: " + File.Exists(RulesTarget) + ")");
            sb.AppendLine("BundleTarget    = " + Path.Combine(PluginRoot, BundleName));
            WriteCheckReport(sb.ToString());
            Log("--check xong.");
            return 0;
        }

        // ======================= UNINSTALL =======================
        static int RunUninstall(bool silent)
        {
            Log("Bat dau go cai");
            int n = UnregisterStartupSuite();
            try { if (Directory.Exists(InstallRoot)) Directory.Delete(InstallRoot, true); } catch (Exception ex) { Log("Khong xoa duoc " + InstallRoot + ": " + ex.Message); }
            try
            {
                string b = Path.Combine(PluginRoot, BundleName);
                if (Directory.Exists(b)) Directory.Delete(b, true);
            }
            catch { }
            string msg = "Da go cai " + AppName + "." + Environment.NewLine
                       + "Da xoa " + n + " muc trong Startup Suite." + Environment.NewLine
                       + "Dong va mo lai AutoCAD de hoan tat.";
            Log("Go cai xong.");
            if (!silent) MessageBox.Show(msg, AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
            else WriteCheckReport(msg);
            return 0;
        }

        // ======================= INSTALL =======================
        internal static int RunInstall(bool silent)
        {
            Log("Bat dau cai dat");
            if (!HasPayload())
            {
                string m = "File EXE nay KHONG chua noi dung cai dat (payload).\r\n"
                         + "Hay dung file phat hanh chinh thuc do Phong Du an cung cap.";
                Log("PAYLOAD TRONG");
                if (!silent) MessageBox.Show(m, AppName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
                else WriteCheckReport(m);
                return 1;
            }

            string payload = LocatePayload();
            string tmp = Path.Combine(Path.GetTempPath(), AppName + ".Setup.extract");
            if (Directory.Exists(tmp)) Directory.Delete(tmp, true);
            Directory.CreateDirectory(tmp);
            ExtractZip(payload, tmp);

            int files = 0;

            // 1) LISP
            string srcLisp = Path.Combine(tmp, "lisp");
            if (!Directory.Exists(srcLisp)) throw new Exception("Payload thieu thu muc lisp.");
            int lispCount = 0;
            CopyDir(srcLisp, LispDir, ref lispCount);
            Log("Da cai " + lispCount + " file LISP -> " + LispDir);

            // 2) Bo quy tac mau (khong ghi de)
            string srcRules = Path.Combine(tmp, "config", "rules.sample.json");
            Directory.CreateDirectory(ConfigDir);
            if (File.Exists(srcRules) && !File.Exists(RulesTarget))
            {
                File.Copy(srcRules, RulesTarget, false);
                Log("Da cai bo quy tac mau -> " + RulesTarget);
            }
            else Log("rules.json da ton tai hoac payload khong co (giu nguyen).");

            // 2b) TEMPLATE DANH MUC VAT TU (khong ghi de - nguoi dung da dien)
            try
            {
                string srcTmpl = Path.Combine(tmp, "config", "DANH_MUC_VAT_TU.xlsx");
                if (File.Exists(srcTmpl))
                {
                    string dstTmpl = Path.Combine(ConfigDir, "DANH_MUC_VAT_TU.xlsx");
                    if (!File.Exists(dstTmpl))
                    {
                        File.Copy(srcTmpl, dstTmpl, false);
                        Log("Da cai template danh muc vat tu -> " + dstTmpl);
                    }
                    else Log("DANH_MUC_VAT_TU.xlsx da ton tai (giu nguyen - tranh mat du lieu nguoi dung).");
                }
            }
            catch (Exception exT) { Log("Loi cai template danh muc: " + exT.Message); }

            // 2c) CONG CU (tools/*.ps1): import danh muc vat tu
            try
            {
                string srcTools = Path.Combine(tmp, "tools");
                if (Directory.Exists(srcTools))
                {
                    string toolsDir = Path.Combine(InstallRoot, "tools");
                    int tc = 0;
                    CopyDir(srcTools, toolsDir, ref tc);
                    files += tc;
                    Log("Da cai " + tc + " cong cu -> " + toolsDir);
                }
            }
            catch (Exception exC) { Log("Loi cai cong cu: " + exC.Message); }

            // 3) Tai lieu
            string srcDocs = Path.Combine(tmp, "docs");
            if (Directory.Exists(srcDocs)) { int dc = 0; CopyDir(srcDocs, DocsDir, ref dc); files += dc; }

            // 4) Bundle .NET (neu co DLL) - kem lisp ben trong de plugin tu nap
            string srcDll = Path.Combine(tmp, "dll");
            bool bundleOk = false;
            if (Directory.Exists(srcDll) && Directory.GetFiles(srcDll, "MTOPlugin.dll").Length > 0)
            {
                string bundleDir = Path.Combine(PluginRoot, BundleName);
                string win = Path.Combine(bundleDir, "Contents", "Windows");
                string lispInBundle = Path.Combine(win, "lisp");
                Directory.CreateDirectory(win);
                Directory.CreateDirectory(Path.Combine(bundleDir, "Contents"));
                // PackageContents.xml
                string pkg = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"
                    + "<ApplicationPackage SchemaVersion=\"1.0\" Version=\"1.0\" Name=\"" + AppName + "\"\r\n"
                    + "  Description=\"Boc tach khoi luong M&amp;E (Dien - Nuoc - ELV)\"\r\n"
                    + "  Author=\"Phong Du An\" HelpFile=\"" + DocsDir + "\\HUONG_DAN_SU_DUNG.md\">\r\n"
                    + "  <CompanyDetails Name=\"Phong Du An\" Url=\"\" Email=\"\"/>\r\n"
                    + "  <RuntimeRequirements OS=\"Win64\" Platform=\"AutoCAD*\" SeriesMin=\"R24.0\" SeriesMax=\"R24.9\"/>\r\n"
                    + "  <Components Description=\"MTOPro\">\r\n"
                    + "    <RuntimeRequirements OS=\"Win64\" Platform=\"AutoCAD*\" SeriesMin=\"R24.0\" SeriesMax=\"R24.9\"/>\r\n"
                    + "    <ComponentEntry AppName=\"" + AppName + "\" Version=\"1.0.0\" ModuleName=\"./Contents/Windows/MTOPlugin.dll\" AppDescription=\"MTOPro\"/>\r\n"
                    + "  </Components>\r\n"
                    + "</ApplicationPackage>\r\n";
                File.WriteAllText(Path.Combine(bundleDir, "PackageContents.xml"), pkg, new UTF8Encoding(false));
                int bc = 0;
                CopyDir(srcDll, win, ref bc);
                CopyDir(srcLisp, lispInBundle, ref bc);
                bundleOk = true;
                Log("Da cai bundle .NET -> " + bundleDir + " (" + bc + " file)");
            }
            else Log("Payload khong co DLL .NET -> chi cai LISP.");

            // 5) Startup Suite -> tu nap LISP moi lan mo AutoCAD
            int profiles = RegisterStartupSuite(Path.Combine(LispDir, LoaderLsp));
            Log("Da ghi Startup Suite cho " + profiles + " profile.");

            // 6) Ket qua
            var sb = new StringBuilder();
            sb.AppendLine("Cai dat HOAN TAT!");
            sb.AppendLine();
            sb.AppendLine("  Module LISP      : " + lispCount + " file -> " + LispDir);
            sb.AppendLine("  Bo quy tac       : " + RulesTarget);
            sb.AppendLine("  Tai lieu         : " + DocsDir);
            sb.AppendLine("  Bundle .NET      : " + (bundleOk ? Path.Combine(PluginRoot, BundleName) : "(khong cai)"));
            sb.AppendLine("  Startup Suite    : " + profiles + " profile");
            sb.AppendLine("  AutoCAD (registry): " + GetAcadRKeys().Count);
            sb.AppendLine();
            sb.AppendLine("BUOC CUOI: dong va MO LAI AutoCAD.");
            sb.AppendLine("Kiem tra: go lenh  MTOHELP");
            WriteCheckReport(sb.ToString());
            Log(sb.ToString().Replace("\r", " ").Replace("\n", " "));
            if (!silent) MessageBox.Show(sb.ToString(), AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 0;
        }
    }

    // ======================= GUI =======================
    public class SetupForm : Form
    {
        public int ExitCode = 0;
        private Label lblStatus;
        private ProgressBar pbar;
        private Button btnClose;

        public SetupForm()
        {
            this.Text = "Cai dat MTOPro - Boc tach khoi luong M&E";
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false; this.MinimizeBox = false;
            this.ClientSize = new Size(540, 250);

            var lblTitle = new Label();
            lblTitle.Text = "CÀI ĐẶT MTOPro\r\nBóc tách khối lượng M&E trên AutoCAD";
            lblTitle.Font = new Font("Segoe UI", 12, FontStyle.Bold);
            lblTitle.SetBounds(24, 16, 490, 50);
            this.Controls.Add(lblTitle);

            lblStatus = new Label();
            lblStatus.Text = "Đang chuẩn bị...";
            lblStatus.Font = new Font("Segoe UI", 10);
            lblStatus.SetBounds(24, 76, 490, 70);
            this.Controls.Add(lblStatus);

            pbar = new ProgressBar();
            pbar.Style = ProgressBarStyle.Marquee;
            pbar.SetBounds(24, 152, 490, 22);
            this.Controls.Add(pbar);

            btnClose = new Button();
            btnClose.Text = "Kết thúc";
            btnClose.Enabled = false;
            btnClose.SetBounds(210, 192, 120, 34);
            btnClose.Click += delegate { this.ExitCode = 0; this.Close(); };
            this.Controls.Add(btnClose);

            this.Load += new EventHandler(OnLoad);
        }

        void SetStatus(string s)
        {
            if (this.InvokeRequired) { try { this.BeginInvoke(new Action<string>(SetStatus), s); } catch { } return; }
            lblStatus.Text = s;
        }

        void OnLoad(object sender, EventArgs e)
        {
            var w = new BackgroundWorker();
            w.DoWork += delegate(object s, DoWorkEventArgs a)
            {
                try { a.Result = Program.RunInstall(true); }
                catch (Exception ex) { Program.Log("GUI install loi: " + ex); a.Result = 99; }
            };
            w.RunWorkerCompleted += delegate(object s, RunWorkerCompletedEventArgs a)
            {
                pbar.Enabled = false; btnClose.Enabled = true;
                int rc = (a.Result is int) ? (int)a.Result : 99;
                this.ExitCode = rc;
                lblStatus.Text = (rc == 0)
                    ? "HOÀN TẤT.\r\n\r\nĐóng và MỞ LẠI AutoCAD, sau đó gõ lệnh  MTOHELP  để kiểm tra."
                    : "LỖI khi cài đặt.\r\nXem chi tiết: %LOCALAPPDATA%\\MTOPro\\logs\\setup.log";
            };
            w.RunWorkerAsync();
        }
    }
}
