using System;
using System.IO;
using System.Diagnostics;
using System.Reflection;
using System.Windows.Forms;
using System.Drawing;
using System.Collections.Generic;
using Microsoft.Win32;
using System.ComponentModel;

// =====================================================================
// MTOPlugin.Setup - Bo cai 1-click cho plugin boc tach khoi luong M&E
// - Nhung san payload (cac bundle MTOPlugin.*.bundle + config trong zip)
//   ngay trong chinh file EXE (resource InstallerApp.Payload.zip)
// - Tu dong:
//     1) det tat ca AutoCAD 2018-2026 da cai
//     2) giai nen cac bundle vao %APPDATA%\Autodesk\ApplicationPlugins
//        (AutoCAD tu quet va tu load bundle dung nhom phien ban)
//     3) dang ky registry Applications cho moi AutoCAD tim thay
//     4) cai bo quy tac mau rules.json (lan dau)
// - Chay bang cach double-click file EXE (khong can quyen Admin vi
//   cai cho nguoi dung hien tai).
// - Che do dong lenh:
//     MTOPlugin.Setup.exe --check
//     MTOPlugin.Setup.exe --install-silent
//     MTOPlugin.Setup.exe --uninstall-silent
// =====================================================================
namespace MTOPlugin.Setup
{
    static class Program
    {
        const string PayloadResource = "InstallerApp.Payload.zip";
        const string AppName = "MTOPlugin";
        const string CompanyName = "Phong Du an";

        static readonly string AppData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        static readonly string PluginRoot = Path.Combine(AppData, "Autodesk", "ApplicationPlugins");
        static readonly string LocalData = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppName);
        static readonly string ConfigDir = Path.Combine(LocalData, "config");
        static readonly string RulesTarget = Path.Combine(ConfigDir, "rules.json");
        static readonly string CheckReport = Path.Combine(Path.GetTempPath(), "MTOPlugin.Setup.check.txt");
        static readonly string LastLog = Path.Combine(LocalData, "logs", "setup.log");

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

                // che do binh thuong: hien GUI
                using (SetupForm f = new SetupForm())
                {
                    Application.Run(f);
                    return f.ExitCode;
                }
            }
            catch (Exception ex)
            {
                Log("LOI nghiem trong: " + ex);
                string msg = "Cai dat that bai: " + ex.Message
                           + "\r\n\r\nChi tiet: " + LastLog;
                MessageBox.Show(msg, AppName, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }

        // ============================ Utilities ============================
        internal static void Log(string line)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LastLog));
                File.AppendAllText(LastLog, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " + line + "\r\n");
            }
            catch { }
        }

        static void WriteCheckReport(string text)
        {
            try { File.WriteAllText(CheckReport, text, new System.Text.UTF8Encoding(false)); }
            catch { }
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

        static string LocatePayloadFile()
        {
            // 1) payload nhu?ng ben trong EXE
            byte[] data = ReadEmbeddedPayload();
            if (data != null && data.Length > 0)
            {
                string dir = Path.Combine(Path.GetTempPath(), "MTOPlugin.Setup.payload");
                Directory.CreateDirectory(dir);
                string zipPath = Path.Combine(dir, "payload.zip");
                File.WriteAllBytes(zipPath, data);
                return zipPath;
            }
            // 2) file payload.dat canh EXE (ho tro phat trien, chua nen payload)
            string sidecarCandidates = null;
            try
            {
                string exeDir = Path.GetDirectoryName(Application.ExecutablePath);
                sidecarCandidates = Path.Combine(exeDir, "MTOPlugin.Setup.payload.zip");
                if (File.Exists(sidecarCandidates) && new FileInfo(sidecarCandidates).Length > 0) return sidecarCandidates;
            }
            catch { }
            return null;
        }

        static bool HasPayload() { return LocatePayloadFile() != null; }

        static List<string> GetAcadRKeys()
        {
            // uu tien HKCU truoc; cac R-key trung ten (HKLM) khong dem lai
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

        static List<string> FindBundlesIn(string dir)
        {
            var list = new List<string>();
            if (Directory.Exists(dir))
                foreach (string d in Directory.GetDirectories(dir, AppName + ".*.bundle"))
                    list.Add(d);
            return list;
        }

        // ============================ CHECK ============================
        static int RunCheck()
        {
            var sb = new System.Text.StringBuilder();
            sb.AppendLine("=== MTOPlugin.Setup --check ===");
            List<string> keys = GetAcadRKeys();
            sb.AppendLine("AutoCAD da cai (registry):");
            if (keys.Count == 0) sb.AppendLine("  (khong tim thay)");
            foreach (string k in keys) sb.AppendLine("  " + k);
            sb.AppendLine();
            sb.AppendLine("HasPayload=" + HasPayload());
            sb.AppendLine("PluginRoot=" + PluginRoot);
            sb.AppendLine("Da cai bundle tai PluginRoot: " + FindBundlesIn(PluginRoot).Count);
            WriteCheckReport(sb.ToString());
            Log("--check hoan tat. (chua cai gi)");
            return 0;
        }

        // ============================ UNINSTALL ============================
        static int RunUninstall(bool silent)
        {
            Log("Bat dau gỡ cai");
            int removed = 0;
            foreach (string b in FindBundlesIn(PluginRoot))
            {
                try { Directory.Delete(b, true); removed++; Log("Xoa bundle: " + b); }
                catch (Exception ex) { Log("Khong xoa duoc " + b + ": " + ex.Message); }
            }
            // xóa cac entry registry Applications da dang ky
            foreach (string rk in GetAcadRKeys())
            {
                try
                {
                    string root = rk.StartsWith("HKLM") ? "LM" : "CU";
                    string keyPath = rk.Substring(rk.IndexOf('/') + 1) + "\\Applications";

                    using (RegistryKey baseKey = (root == "LM") ? Registry.LocalMachine : Registry.CurrentUser)
                    using (RegistryKey key = baseKey.OpenSubKey(keyPath, true))
                    {
                        if (key == null) continue;
                        foreach (string sub in key.GetSubKeyNames())
                            if (sub.StartsWith(AppName + "."))
                            {
                                key.DeleteSubKey(sub, false);
                                Log("Xoa registry: " + rk + "/Applications/" + sub);
                                removed++;
                            }
                    }
                }
                catch { }
            }
            // chinh lai? giu bo quy tac / log, chi đưa ra thong bao
            string msg = "Da gỡ cai MTOPlugin." + Environment.NewLine
                       + "Bundle da xoa: " + removed + " muc." + Environment.NewLine
                       + "(Bat buoc dong mo lai AutoCAD de ROI plugin).";
            Log("Gỡ cai xong.");
            if (!silent) MessageBox.Show(msg, AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
            else WriteCheckReport(msg);
            return 0;
        }

        // ============================ INSTALL ============================
        internal static int RunInstall(bool silent)
        {
            Log("Bat dau cai dat (silent=" + silent + ")");

            if (!HasPayload())
            {
                string msg = "Chua thay noi dung cai dat (payload) trong file EXE.\r\n\r\n"
                           + "De tao file EXE hoan chinh, tren may phat trien chay:\r\n"
                           + "  1) scripts\\build.ps1 -AcadVersion 2024\r\n"
                           + "  2) scripts\\build-installer.ps1\r\n"
                           + "Roi gui file duy nhat output\\MTOPlugin.Setup-0.1.0.exe cho nguoi dung.";
                Log("PAYLOAD TRONG");
                if (!silent) MessageBox.Show(msg, AppName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
                else WriteCheckReport(msg);
                return 1;
            }

            string payloadPath = LocatePayloadFile();
            string steps = "Buoc 1/5: Giai nen payload...";
            if (!silent) TrySetStatus(steps);
            Log(steps);

            // 1) giai nen payload den thu muc tam
            string tempExtract = Path.Combine(Path.GetTempPath(), "MTOPlugin.Setup.extract");
            if (Directory.Exists(tempExtract)) Directory.Delete(tempExtract, true);
            Directory.CreateDirectory(tempExtract);
            ExtractZip(payloadPath, tempExtract);

            // 2) copy cac bundle vao ApplicationPlugins
            string[] bundles = Directory.GetDirectories(tempExtract, AppName + ".*.bundle", SearchOption.TopDirectoryOnly);
            if (bundles.Length == 0)
            {
                string msg = "Khong tim thay bundle MTOPlugin trong payload. Kiem tra lai build-installer.ps1.";
                Log(msg);
                if (!silent) MessageBox.Show(msg, AppName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return 1;
            }

            int i = 0;
            foreach (string b in bundles)
            {
                i++;
                string target = Path.Combine(PluginRoot, Path.GetFileName(b));
                string st = "Buoc 2/5: Sao chep bundle " + i + "/" + bundles.Length + " (" + Path.GetFileName(b) + ")...";
                if (!silent) TrySetStatus(st);
                Log(st);
                CopyDirectory(b, target);
            }

            // 3) bo quy tac mau (khong ghi đe neu da co)
            string cfgSt = "Buoc 3/5: Cai bo quy tac mau rules.json (chi lan dau)...";
            if (!silent) TrySetStatus(cfgSt);
            Log(cfgSt);
            string sampleRule = Path.Combine(tempExtract, "config", "rules.sample.json");
            if (File.Exists(sampleRule))
            {
                Directory.CreateDirectory(ConfigDir);
                if (!File.Exists(RulesTarget))
                {
                    File.Copy(sampleRule, RulesTarget, false);
                    Log("Da cai bo quy tac mau -> " + RulesTarget);
                }
                else Log("rules.json da ton tai (giu nguyen).");
            }

            // 4) dang ky registry
            string regSt = "Buoc 4/5: Dang ky cho AutoCAD da cai...";
            if (!silent) TrySetStatus(regSt);
            Log(regSt);
            int registered = 0;
            foreach (string rk in GetAcadRKeys())
            {
                if (RegisterForRKey(rk)) registered++;
            }
            Log("Da dang ky " + registered + " AutoCAD.");

            // 5) hoan tat
            string done = "Buoc 5/5: Hoan tat.";
            if (!silent) TrySetStatus(done);
            Log(done);

            string summary = "Cai dat hoan tat!\r\n\r\n"
                + "Da cai " + bundles.Length + " bundle:\r\n";
            foreach (string b in bundles)
                summary += "  - " + Path.GetFileName(b) + "\r\n";
            summary += "\r\nAutoCAD da cai: " + registered + " / " + GetAcadRKeys().Count + " (registry).\r\n\r\n"
                     + "Buoc cuoi: DONG va MO lai AutoCAD, go lenh MTO de bat dau su dung.";

            WriteCheckReport(summary);
            Log(summary.Replace("\r", " ").Replace("\n", " "));
            if (!silent) MessageBox.Show(summary, AppName, MessageBoxButtons.OK, MessageBoxIcon.Information);
            return 0;
        }

        internal static void TrySetStatus(string s) { }

        static void ExtractZip(string zipPath, string destDir)
        {
            // dung tar (bsdtar) co san trên Windows 10/11: giai nen zip bao toan utf-8
            ProcessStartInfo psi = new ProcessStartInfo("tar.exe", "-xf \"" + zipPath + "\" -C \"" + destDir + "\"");
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            using (Process p = Process.Start(psi))
            {
                p.WaitForExit(60000);
                if (p.ExitCode != 0) throw new Exception("Giai nen payload that bai (tar.exe, exit " + p.ExitCode + ").");
            }
        }

        static void CopyDirectory(string src, string dst)
        {
            Directory.CreateDirectory(dst);
            foreach (string f in Directory.GetFiles(src))
            {
                string target = Path.Combine(dst, Path.GetFileName(f));
                // khong ghi đe file dang su dung (neu bundle dang duoc AutoCAD giu)
                if (File.Exists(target)) try { File.Delete(target); } catch { }
                File.Copy(f, target, true);
            }
            foreach (string d in Directory.GetDirectories(src))
                CopyDirectory(d, Path.Combine(dst, Path.GetFileName(d)));
        }

        static bool RegisterForRKey(string rk)
        {
            try
            {
                string rootName = rk.StartsWith("HKLM") ? "LM" : "CU";
                string rSub = rk.Substring(rk.IndexOf('/') + 1);
                using (RegistryKey baseKey = (rootName == "LM") ? Registry.LocalMachine : Registry.CurrentUser)
                using (RegistryKey acadKey = baseKey.OpenSubKey("Software\\Autodesk\\AutoCAD\\" + rSub, true))
                {
                    if (acadKey == null) return false;
                    foreach (string acSub in acadKey.GetSubKeyNames())
                    {
                        if (!acSub.StartsWith("ACAD-")) continue;
                        string appsRoot = "Software\\Autodesk\\AutoCAD\\" + rSub + "\\" + acSub + "\\Applications";
                        using (RegistryKey apps = baseKey.CreateSubKey(appsRoot))
                        {
                            if (apps == null) continue;
                            // dang ky ca 2 bundle de chan cho
                            foreach (string b in FindBundlesIn(PluginRoot))
                            {
                                string bundleName = Path.GetFileName(b);
                                using (RegistryKey bundleKey = apps.CreateSubKey(bundleName))
                                {
                                    bundleKey.SetValue("LOADER", bundleName + "\\Contents\\Windows\\MTOPlugin.dll");
                                    bundleKey.SetValue("LOADCTRLS", "5");
                                    bundleKey.SetValue("ZOOMLOADER", "0");
                                }
                            }
                        }
                    }
                    return true;
                }
            }
            catch (Exception ex) { Log("RegisterForRKey(" + rk + ") that bai: " + ex.Message); return false; }
        }
    }

    // =====================================================================
    // SetupForm - GUI nho gon: trang thai su tien trinh + nut dat tiep/ket thuc
    // =====================================================================
    public class SetupForm : Form
    {
        public int ExitCode = 0;

        private System.Windows.Forms.Label lblTitle;
        private System.Windows.Forms.Label lblStatus;
        private System.Windows.Forms.ProgressBar pbar;
        private System.Windows.Forms.Button btnClose;

        public SetupForm()
        {
            BuildUi();
            this.Load += new EventHandler(OnLoad);
        }

        void BuildUi()
        {
            this.Text = "Cai dat MTOPlugin";
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.ClientSize = new Size(520, 240);

            lblTitle = new System.Windows.Forms.Label();
            lblTitle.Text = "Cài đặt Plugin bóc tách khối lượng M&E (AutoCAD)";
            lblTitle.Font = new Font("Times New Roman", 13, FontStyle.Bold);
            lblTitle.SetBounds(24, 18, 470, 40);
            this.Controls.Add(lblTitle);

            lblStatus = new System.Windows.Forms.Label();
            lblStatus.Text = "Đang chuẩn bị...";
            lblStatus.Font = new Font("Times New Roman", 11);
            lblStatus.SetBounds(24, 70, 470, 60);
            this.Controls.Add(lblStatus);

            pbar = new System.Windows.Forms.ProgressBar();
            pbar.Style = ProgressBarStyle.Marquee;
            pbar.SetBounds(24, 140, 470, 24);
            this.Controls.Add(pbar);

            btnClose = new System.Windows.Forms.Button();
            btnClose.Text = "Kết thúc";
            btnClose.Enabled = false;
            btnClose.SetBounds(200, 185, 120, 34);
            btnClose.Click += delegate { this.ExitCode = 0; this.Close(); };
            this.Controls.Add(btnClose);
        }

        void SetStatus(string s)
        {
            if (this.InvokeRequired) { try { this.BeginInvoke(new Action<string>(SetStatus), s); } catch { } return; }
            lblStatus.Text = s;
        }

        void OnLoad(object sender, EventArgs e)
        {
            var worker = new BackgroundWorker();
            worker.DoWork += delegate(object s, DoWorkEventArgs a)
            {
                try { a.Result = Program.RunInstall(true); }
                catch (Exception ex) { a.Result = 99; Program.Log("GUI install loi: " + ex); }
            };
            worker.RunWorkerCompleted += delegate(object s, RunWorkerCompletedEventArgs a)
            {
                pbar.Enabled = false;
                btnClose.Enabled = true;
                int rc = (a.Result is int) ? (int)a.Result : 99;
                this.ExitCode = rc;
                lblStatus.Text = (rc == 0)
                    ? "HOAN TAT. Dong va mo lai AutoCAD, go lenh MTO de su dung."
                    : "LOI khi cai dat. Xem chi tiet: %LOCALAPPDATA%\\MTOPlugin\\logs\\setup.log";
            };
            worker.RunWorkerAsync();
        }
    }
}