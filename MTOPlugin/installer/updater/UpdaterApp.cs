using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Text;

// =====================================================================
// UpdaterApp -- BOOTSTRAP UPDATER cho MTOPro
//
// VI SAO CAN: khi AutoCAD DANG MO, file MTOPlugin.dll bi KHO A nen
// AutoLISP khong the thay the. Chuong trinh nay chay NGOAI AutoCAD,
// lam phan THAO TAC NANG: tai - verify - backup - swap.
//
// Cach dung:
//   UpdaterApp.exe --status
//   UpdaterApp.exe --check    --source <url|path>
//   UpdaterApp.exe --install  --source <url|path>
//   UpdaterApp.exe --rollback [version]
//
// RANG BUOC (tu UPDATE_ARCHITECTURE.md):
//   - KHONG BAO GIO cham vao config\ (user data)
//   - SHA256 bat buoc
//   - KEEP_BACKUPS = 3
//   - Log khong credential
// =====================================================================
namespace MTOPro.Updater
{
    internal static class Program
    {
        private const string AppName = "MTOPro";
        private const int KEEP_BACKUPS = 3;
        private const string ManifestFile = "manifest.json";

        // Application files duoc phep ghi de khi kich hoat
        private static readonly string[] AppPaths = { "lisp", "docs", "tools", "dll", "version.json" };

        private static readonly string Root =
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppName);

        private static readonly string LogFile = Path.Combine(Root, "logs", "update.log");
        private static readonly string StagingDir = Path.Combine(Root, "staging");
        private static readonly string BackupDir = Path.Combine(Root, "backup");

        private static int Main(string[] args)
        {
            Console.OutputEncoding = Encoding.UTF8;

            // ===== BAT BUOC CHO HTTPS HIEN DAI =====
            // .NET Framework 4.8 MAC DINH co the dung TLS 1.0 -> GitHub/HTTPS
            // hien dai TU CHOI ("Could not create SSL/TLS secure channel").
            // Phai bat TLS 1.2/1.3 TUONG MINH truoc moi request.
            try
            {
                ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
                try { ServicePointManager.SecurityProtocol |= (SecurityProtocolType)12288; } catch { } // Tls13
            }
            catch (Exception exTls) { Log("CANH BAO: khong bat duoc TLS 1.2: " + exTls.Message); }

            try
            {
                string mode = "status";
                string source = null;
                string version = null;

                for (int i = 0; i < args.Length; i++)
                {
                    string a = args[i].ToLowerInvariant();
                    if (a == "--source" && i + 1 < args.Length) { source = args[++i]; }
                    else if (a == "--rollback") { mode = "rollback"; if (i + 1 < args.Length && !args[i + 1].StartsWith("--")) version = args[++i]; }
                    else if (a == "--install") { mode = "install"; }
                    else if (a == "--check") { mode = "check"; }
                    else if (a == "--status") { mode = "status"; }
                    else if (a == "--help" || a == "-h") { Help(); return 0; }
                }

                switch (mode)
                {
                    case "status":   return DoStatus();
                    case "check":    return DoCheck(source);
                    case "install":  return DoInstall(source, false);
                    case "rollback": return DoRollback(version);
                    default: Help(); return 2;
                }
            }
            catch (Exception ex)
            {
                Log("FATAL: " + ex.GetType().Name + " - " + ex.Message);
                Console.WriteLine("LOI: " + ex.Message);
                return 9;
            }
        }

        private static void Help()
        {
            Console.WriteLine("UpdaterApp -- cap nhat MTOPro (chay khi AutoCAD da dong)");
            Console.WriteLine();
            Console.WriteLine("  --status                       Xem phien ban + backup");
            Console.WriteLine("  --check    --source <src>      Kiem tra ban moi (khong cai)");
            Console.WriteLine("  --install  --source <src>      Tai + kich hoat ban moi");
            Console.WriteLine("  --rollback [version]           Quay ve ban backup");
            Console.WriteLine();
            Console.WriteLine("<src> = duong dan thu muc cuc bo, \\\\server\\share, hoac https://...");
        }

        // ---------------- STATUS ----------------
        private static int DoStatus()
        {
            Console.WriteLine("=== " + AppName + " UPDATE STATUS ===");
            Console.WriteLine("Thu muc cai dat : " + Root);
            Console.WriteLine("Phien ban       : " + ReadLocalVersion());

            var backups = ListBackups();
            Console.WriteLine("Backup hien co  : " + (backups.Count == 0 ? "(khong co)" : string.Join(", ", backups.ToArray())));
            Console.WriteLine("Log             : " + LogFile);
            Log("STATUS | ver=" + ReadLocalVersion() + " | backups=" + backups.Count);
            return 0;
        }

        // ---------------- CHECK ----------------
        private static int DoCheck(string source)
        {
            if (string.IsNullOrWhiteSpace(source)) { Console.WriteLine("Thieu --source"); return 2; }

            var man = FetchManifest(source);
            if (man == null) { Console.WriteLine("Khong lay duoc manifest tu: " + SafeUrl(source)); return 3; }

            string remote = Get(man, "version");
            string local = ReadLocalVersion();
            Console.WriteLine("Local  : " + local);
            Console.WriteLine("Remote : " + remote);
            Console.WriteLine("SHA256 : " + Get(man, "sha256"));
            Console.WriteLine("Ket qua: " + (IsNewer(remote, local) ? "CO BAN MOI" : "DA LA BAN MOI NHAT"));
            Log("CHECK | local=" + local + " remote=" + remote + " src=" + SafeUrl(source));
            return 0;
        }

        // ---------------- INSTALL ----------------
        private static int DoInstall(string source, bool silent)
        {
            if (string.IsNullOrWhiteSpace(source)) { Console.WriteLine("Thieu --source"); return 2; }

            string localVer = ReadLocalVersion();
            Log("INSTALL-BEGIN | local=" + localVer + " src=" + SafeUrl(source));

            var man = FetchManifest(source);
            if (man == null) { Console.WriteLine("Khong lay duoc manifest."); Log("INSTALL-FAIL | manifest"); return 3; }

            string remoteVer = Get(man, "version");
            if (!IsNewer(remoteVer, localVer))
            {
                Console.WriteLine("Da la ban moi nhat (" + localVer + "). Khong can cap nhat.");
                Log("INSTALL-SKIP | da moi nhat");
                return 0;
            }

            // 1) Tai package
            string pkgName = Get(man, "package");
            if (string.IsNullOrWhiteSpace(pkgName)) pkgName = "package.zip";
            string pkgUrl = Combine(source, pkgName);

            CleanDir(StagingDir);
            Directory.CreateDirectory(StagingDir);
            string zipPath = Path.Combine(StagingDir, "package.zip");

            Console.WriteLine("Dang tai: " + SafeUrl(pkgUrl));
            if (!Download(pkgUrl, zipPath)) { Console.WriteLine("Tai that bai."); Log("INSTALL-FAIL | download"); return 4; }

            // 2) Verify SHA256
            string want = (Get(man, "sha256") ?? "").Trim().ToLowerInvariant();
            string got = Sha256(zipPath);
            Console.WriteLine("SHA256 mong doi: " + want);
            Console.WriteLine("SHA256 thuc te : " + got);
            if (want.Length != 64 || want != got)
            {
                Console.WriteLine("SHA256 KHONG KHOP -> TU CHOI KICH HOAT.");
                Log("INSTALL-FAIL | sha256 mismatch");
                return 5;
            }

            // 3) Giai nen + verify cau truc
            string extractDir = Path.Combine(StagingDir, "payload");
            CleanDir(extractDir);
            Directory.CreateDirectory(extractDir);
            if (!SafeExtract(zipPath, extractDir)) { Console.WriteLine("Giai nen loi / zip-slip."); Log("INSTALL-FAIL | extract"); return 6; }

            string err;
            if (!VerifyPayload(extractDir, remoteVer, out err))
            {
                Console.WriteLine("Payload khong hop le: " + err);
                Log("INSTALL-FAIL | payload: " + err);
                return 7;
            }

            // 4) Backup ban hien tai
            string bak = Path.Combine(BackupDir, localVer);
            if (!BackupCurrent(bak)) { Console.WriteLine("Backup that bai."); Log("INSTALL-FAIL | backup"); return 8; }
            Console.WriteLine("Da backup -> " + bak);

            // 5) Activate (chi app files, KHONG cham config)
            if (!Activate(extractDir))
            {
                Console.WriteLine("Kich hoat loi -> ROLLBACK...");
                Log("INSTALL-ROLLBACK | activate failed");
                RestoreFrom(bak);
                return 10;
            }

            PruneBackups();
            Console.WriteLine("HOAN TAT. Phien ban moi: " + ReadLocalVersion());
            Console.WriteLine("Hay KHOI DONG LAI AutoCAD de nap ban moi.");
            Log("INSTALL-OK | " + localVer + " -> " + ReadLocalVersion());
            return 0;
        }

        // ---------------- ROLLBACK ----------------
        private static int DoRollback(string version)
        {
            var backups = ListBackups();
            if (backups.Count == 0) { Console.WriteLine("Khong co ban backup nao."); return 3; }

            string target = version;
            if (string.IsNullOrWhiteSpace(target))
            {
                // chon ban moi nhat trong backup (khac ban dang chay)
                string cur = ReadLocalVersion();
                foreach (var b in backups) { if (b != cur) { target = b; break; } }
                if (target == null) target = backups[0];
            }

            string bak = Path.Combine(BackupDir, target);
            if (!Directory.Exists(bak)) { Console.WriteLine("Khong thay backup: " + target); return 3; }

            Console.WriteLine("Rollback ve: " + target);
            if (!RestoreFrom(bak)) { Console.WriteLine("Rollback that bai."); Log("ROLLBACK-FAIL | " + target); return 5; }

            Console.WriteLine("ROLLBACK XONG. Phien ban: " + ReadLocalVersion());
            Console.WriteLine("Hay KHOI DONG LAI AutoCAD.");
            Log("ROLLBACK-OK | -> " + ReadLocalVersion());
            return 0;
        }

        // ================== MANIFEST ==================
        // Doc JSON PHANG (moi field 1 dong) - cung rang buoc nhu phia LISP
        private static Dictionary<string, string> ReadFlatJson(string path)
        {
            var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            if (!File.Exists(path)) return null;
            foreach (string line in File.ReadAllLines(path))
            {
                int p1 = line.IndexOf('"');
                if (p1 < 0) continue;
                int p2 = line.IndexOf('"', p1 + 1);
                if (p2 < 0) continue;
                string key = line.Substring(p1 + 1, p2 - p1 - 1);
                int colon = line.IndexOf(':', p2);
                if (colon < 0) continue;
                string val = line.Substring(colon + 1).Trim().TrimEnd(',');
                if (val.Length >= 2 && val[0] == '"') val = val.Substring(1, val.Length - 2);
                d[key] = val;
            }
            return d.Count > 0 ? d : null;
        }

        private static Dictionary<string, string> FetchManifest(string source)
        {
            try
            {
                if (IsRemote(source))
                {
                    string tmp = Path.Combine(Path.GetTempPath(), "mtopro-manifest.json");
                    if (!Download(Combine(source, ManifestFile), tmp)) return null;
                    return ReadFlatJson(tmp);
                }
                return ReadFlatJson(Path.Combine(NormalizeLocal(source), ManifestFile));
            }
            catch (Exception ex) { Log("MANIFEST-ERROR | " + ex.Message); return null; }
        }

        // ================== NETWORK / FILE ==================
        private static bool IsRemote(string src)
        {
            string s = (src ?? "").ToLowerInvariant();
            return s.StartsWith("http://") || s.StartsWith("https://");
        }

        private static string NormalizeLocal(string src)
        {
            if (src.StartsWith("file://", StringComparison.OrdinalIgnoreCase))
                src = src.Substring(7).TrimStart('/');
            return src;
        }

        private static string Combine(string src, string leaf)
        {
            string s = src.TrimEnd('/');
            return IsRemote(s) ? s + "/" + leaf : Path.Combine(NormalizeLocal(s), leaf);
        }

        private static bool Download(string url, string dest)
        {
            try
            {
                if (IsRemote(url))
                {
                    // Chi cho HTTPS (tru localhost de test noi bo)
                    string low = url.ToLowerInvariant();
                    if (low.StartsWith("http://") && !low.Contains("localhost") && !low.Contains("127.0.0.1"))
                    { Log("DOWNLOAD-REJECT | chi cho HTTPS: " + SafeUrl(url)); return false; }

                    using (var wc = new WebClient())
                    {
                        wc.Headers.Add("User-Agent", "MTOPro-Updater/1.0");
                        wc.DownloadFile(url, dest);
                    }
                }
                else
                {
                    File.Copy(NormalizeLocal(url), dest, true);
                }
                return File.Exists(dest) && new FileInfo(dest).Length > 0;
            }
            catch (Exception ex) { Log("DOWNLOAD-ERROR | " + SafeUrl(url) + " | " + ex.Message); return false; }
        }

        // ================== SHA256 ==================
        private static string Sha256(string file)
        {
            using (var sha = SHA256.Create())
            using (var fs = File.OpenRead(file))
            {
                byte[] h = sha.ComputeHash(fs);
                var sb = new StringBuilder();
                foreach (byte b in h) sb.Append(b.ToString("x2", CultureInfo.InvariantCulture));
                return sb.ToString();
            }
        }

        // ================== ZIP ==================
        private static bool SafeExtract(string zipPath, string destDir)
        {
            try
            {
                string fullDest = Path.GetFullPath(destDir) + Path.DirectorySeparatorChar;
                using (var za = ZipFile.OpenRead(zipPath))
                {
                    foreach (var e in za.Entries)
                    {
                        if (string.IsNullOrEmpty(e.Name)) continue;   // thu muc
                        string target = Path.GetFullPath(Path.Combine(destDir, e.FullName));
                        // CHONG ZIP-SLIP: file phai nam trong destDir
                        if (!target.StartsWith(fullDest, StringComparison.OrdinalIgnoreCase))
                        { Log("ZIP-SLIP chan: " + e.FullName); return false; }
                    }
                }
                ZipFile.ExtractToDirectory(zipPath, destDir);
                return true;
            }
            catch (Exception ex) { Log("EXTRACT-ERROR | " + ex.Message); return false; }
        }

        // ================== VERIFY PAYLOAD ==================
        private static bool VerifyPayload(string dir, string expectedVer, out string err)
        {
            err = null;
            string lisp = Path.Combine(dir, "lisp");
            if (!Directory.Exists(lisp)) { err = "thieu thu muc lisp/"; return false; }
            if (Directory.GetFiles(lisp, "*.lsp").Length < 1) { err = "lisp/ khong co file .lsp"; return false; }

            var v = ReadFlatJson(Path.Combine(dir, "version.json"));
            if (v == null) { err = "thieu version.json"; return false; }
            string ver;
            if (!v.TryGetValue("version", out ver)) { err = "version.json thieu field version"; return false; }
            if (!string.IsNullOrEmpty(expectedVer) &&
                !string.Equals(ver.Trim(), expectedVer.Trim(), StringComparison.OrdinalIgnoreCase))
            { err = "version.json (" + ver + ") khong khop manifest (" + expectedVer + ")"; return false; }
            return true;
        }

        // ================== BACKUP / ACTIVATE ==================
        private static bool BackupCurrent(string dest)
        {
            try
            {
                CleanDir(dest);
                Directory.CreateDirectory(dest);
                foreach (string p in AppPaths)
                {
                    string src = Path.Combine(Root, p);
                    if (!File.Exists(src) && !Directory.Exists(src)) continue;
                    string d = Path.Combine(dest, p);
                    if (Directory.Exists(src)) CopyDir(src, d);
                    else { Directory.CreateDirectory(Path.GetDirectoryName(d)); File.Copy(src, d, true); }
                }
                return true;
            }
            catch (Exception ex) { Log("BACKUP-ERROR | " + ex.Message); return false; }
        }

        // Kich hoat: chi ghi APP FILES. ⛔ KHONG BAO GIO cham config/
        private static bool Activate(string src)
        {
            try
            {
                foreach (string p in AppPaths)
                {
                    string s = Path.Combine(src, p);
                    if (!File.Exists(s) && !Directory.Exists(s)) continue;
                    string d = Path.Combine(Root, p);

                    if (Directory.Exists(s))
                    {
                        CleanDir(d);
                        Directory.CreateDirectory(d);
                        CopyDir(s, d);
                    }
                    else
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(d));
                        File.Copy(s, d, true);
                    }
                }
                return true;
            }
            catch (Exception ex) { Log("ACTIVATE-ERROR | " + ex.Message); return false; }
        }

        private static bool RestoreFrom(string bak)
        {
            try
            {
                if (!Directory.Exists(bak)) return false;
                foreach (string p in AppPaths)
                {
                    string s = Path.Combine(bak, p);
                    if (!File.Exists(s) && !Directory.Exists(s)) continue;
                    string d = Path.Combine(Root, p);
                    if (Directory.Exists(s)) { CleanDir(d); Directory.CreateDirectory(d); CopyDir(s, d); }
                    else { Directory.CreateDirectory(Path.GetDirectoryName(d)); File.Copy(s, d, true); }
                }
                return true;
            }
            catch (Exception ex) { Log("RESTORE-ERROR | " + ex.Message); return false; }
        }

        private static List<string> ListBackups()
        {
            var outp = new List<string>();
            if (!Directory.Exists(BackupDir)) return outp;
            foreach (string d in Directory.GetDirectories(BackupDir))
            {
                string n = Path.GetFileName(d);
                if (n.Length > 0 && char.IsDigit(n[0])) outp.Add(n);
            }
            outp.Sort();
            return outp;
        }

        private static void PruneBackups()
        {
            var list = ListBackups();
            if (list.Count <= KEEP_BACKUPS) return;
            int excess = list.Count - KEEP_BACKUPS;
            for (int i = 0; i < excess; i++)
            {
                try { Directory.Delete(Path.Combine(BackupDir, list[i]), true); Log("PRUNE | xoa backup " + list[i]); }
                catch { }
            }
        }

        // ================== VERSION ==================
        private static string ReadLocalVersion()
        {
            try
            {
                var v = ReadFlatJson(Path.Combine(Root, "version.json"));
                string s;
                if (v != null && v.TryGetValue("version", out s)) return s.Trim();
            }
            catch { }
            return "0.0.0";
        }

        private static bool IsNewer(string remote, string local)
        {
            int[] r = ParseSemver(remote), l = ParseSemver(local);
            if (r == null || l == null) return false;
            for (int i = 0; i < 3; i++)
            {
                if (r[i] > l[i]) return true;
                if (r[i] < l[i]) return false;
            }
            return false;
        }

        private static int[] ParseSemver(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return null;
            string[] p = s.Trim().Split('.');
            if (p.Length != 3) return null;
            var o = new int[3];
            for (int i = 0; i < 3; i++)
            {
                int n;
                if (!int.TryParse(p[i], NumberStyles.Integer, CultureInfo.InvariantCulture, out n)) return null;
                o[i] = n;
            }
            return o;
        }

        // ================== UTILS ==================
        private static string Get(Dictionary<string, string> d, string k)
        {
            if (d == null) return null;
            string v;
            return d.TryGetValue(k, out v) ? v : null;
        }

        private static void CopyDir(string src, string dst)
        {
            Directory.CreateDirectory(dst);
            foreach (string f in Directory.GetFiles(src))
            {
                string t = Path.Combine(dst, Path.GetFileName(f));
                File.Copy(f, t, true);
            }
            foreach (string d in Directory.GetDirectories(src))
                CopyDir(d, Path.Combine(dst, Path.GetFileName(d)));
        }

        private static void CleanDir(string dir)
        {
            try { if (Directory.Exists(dir)) Directory.Delete(dir, true); } catch { }
        }

        // Bo credential khoi URL truoc khi ghi log
        private static string SafeUrl(string url)
        {
            if (string.IsNullOrEmpty(url)) return url;
            int at = url.IndexOf('@');
            int sl = url.IndexOf("://");
            if (at < 0 || sl < 0 || at < sl) return url;
            return url.Substring(0, sl + 3) + "***@" + url.Substring(at + 1);
        }

        private static void Log(string msg)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogFile));
                File.AppendAllText(LogFile,
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " | UPDATER | " + msg + "\r\n",
                    Encoding.UTF8);
            }
            catch { }
        }
    }
}
