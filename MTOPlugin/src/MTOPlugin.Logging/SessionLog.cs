using System;
using System.IO;
using System.Text;

namespace MTOPlugin.Logging
{
    /// <summary>
    /// Nhat ky dam bao FR10: ghi thoi gian, file, pham vi, so doi tuong, loi,
    /// phien ban plugin va cau hinh su dung. Ghi ra file text theo session.
    /// </summary>
    public sealed class SessionLog : IDisposable
    {
        private readonly StreamWriter _writer;
        private readonly object _lock = new object();

        public string FilePath { get; }

        public bool IsEnabled { get; set; } = true;

        public SessionLog(string logDirectory, string sessionName)
        {
            if (!Directory.Exists(logDirectory))
                Directory.CreateDirectory(logDirectory);

            var stamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
            FilePath = Path.Combine(logDirectory,
                string.Format("{0}_{1}.log", stamp, Sanitize(sessionName)));
            _writer = new StreamWriter(FilePath, false, Encoding.UTF8);
            WriteLine("===== BAT DAU PHIEN =====");
            WriteLine("Thoi gian: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            WriteLine("May: " + Environment.MachineName);
            WriteLine("Nguoi chay: " + Environment.UserName);
            WriteLine("Phien ban plugin: " + typeof(SessionLog).Assembly.GetName().Version);
            WriteLine("File log: " + FilePath);
            WriteLine("==========================");
        }

        public static string DefaultLogDirectory()
        {
            var baseDir = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            return Path.Combine(baseDir, "MTOPlugin", "logs");
        }

        public void Log(string message)
        {
            WriteLine("[INFO] " + message);
        }

        public void Warn(string message)
        {
            WriteLine("[WARN] " + message);
        }

        public void Error(string message)
        {
            WriteLine("[ERROR] " + message);
        }

        public void Error(string message, Exception ex)
        {
            WriteLine("[ERROR] " + message);
            WriteLine("[ERROR] " + ex);
        }

        private void WriteLine(string line)
        {
            if (!IsEnabled) return;
            lock (_lock)
            {
                _writer.WriteLine(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " | " + line);
                _writer.Flush();
            }
        }

        private static string Sanitize(string name)
        {
            if (string.IsNullOrEmpty(name)) return "session";
            var invalid = Path.GetInvalidFileNameChars();
            var sb = new StringBuilder(name.Length);
            foreach (var c in name)
                sb.Append(Array.IndexOf(invalid, c) >= 0 ? '_' : c);
            return sb.ToString();
        }

        public void Dispose()
        {
            if (_writer != null)
            {
                WriteLine("===== KET THUC PHIEN =====");
                _writer.Dispose();
            }
        }
    }
}