using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Microsoft.Win32;
using MTOPlugin.Core.Classification;
using MTOPlugin.Core.Export;
using MTOPlugin.Core.Models;
using MTOPlugin.Core.Rules;
using MTOPlugin.Core.Session;
using MTOPlugin.Logging;

namespace MTOPlugin.UI
{
    /// <summary>
    /// Panel chinh: Bước 1 quet + phan loai (nap danh sach vao DataGrid),
    /// nguoi dung chon cac muc can xuat, Bước 2 xuat Excel cac muc da chon
    /// hoac xuat toan bo. Ket qua lan quet duoc luu vao ScanSession de lenh
    /// MTOBANG/MTOZOOM tai su dung. Panel khong goi truc tiep AutoCAD API.
    /// </summary>
    public partial class MainPanel : UserControl
    {
        /// <summary>
        /// Delegate duoc cau noi tu host AutoCAD de quet ban ve thuc te.
        /// </summary>
        public Func<ScanOptions, ScanResult> HostScanHandler { get; set; }

        /// <summary>
        /// Delegate xu ly truy vet doi tuong (FR09): tra ve true khi zoom toi doi tuong.
        /// </summary>
        public Func<string, string, bool> HostZoomHandler { get; set; }

        private readonly SessionLog _log;
        private readonly List<RowItem> _rows = new List<RowItem>();
        private ScanResult _lastScan;
        private ClassificationResult _lastResult;

        public MainPanel()
        {
            InitializeComponent();
            _log = new SessionLog(SessionLog.DefaultLogDirectory(), "mainpanel");

            // Don vi mac dinh: ban ve VN dung MILIMET.
            // (Truoc day dat nguon = 3 (ft) -> SAI voi ban ve VN, gay nham lan
            //  khi quy doi don vi xuat.)
            cmbSourceUnit.SelectedIndex = 0; // mm
            cmbOutputUnit.SelectedIndex = 0; // mm

            // Tu dong nap bo quy tac mac dinh: tranh loi "Chua chon file bo quy tac"
            // khi nguoi dung vua cai dat va khong biet file nam o dau.
            var defRules = FindDefaultRulesPath();
            if (defRules != null)
            {
                txtRulesPath.Text = defRules;
                AppendLog("Bộ quy tắc mặc định: " + defRules);
            }
            else
            {
                AppendLog("CHƯA có bộ quy tắc. Bấm nút '...' cạnh ô 'Bộ quy tắc (JSON)' để chọn file,");
                AppendLog("hoặc chạy lại bộ cài MTOPro để tạo: %LOCALAPPDATA%\\MTOPro\\config\\rules.json");
            }
        }

        /// <summary>
        /// Tim bo quy tac mac dinh theo thu tu uu tien:
        ///   1) %LOCALAPPDATA%\MTOPro\config\rules.json     (bo cai MTOPro - chuan)
        ///   2) %LOCALAPPDATA%\MTOPro\config\rules.sample.json
        ///   3) &lt;thu muc DLL&gt;\config\rules.json           (trong bundle .NET)
        ///   4) &lt;thu muc DLL&gt;\config\rules.sample.json
        ///   5) %LOCALAPPDATA%\MTOPlugin\config\rules.json  (bo cai cu)
        ///   6) config\rules.sample.json o thu muc goc repo (khi chay dev)
        /// Tra ve null neu khong tim thay file nao.
        /// </summary>
        internal static string FindDefaultRulesPath()
        {
            var candidates = new List<string>();
            string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            candidates.Add(Path.Combine(local, "MTOPro", "config", "rules.json"));
            candidates.Add(Path.Combine(local, "MTOPro", "config", "rules.sample.json"));

            try
            {
                string dllDir = Path.GetDirectoryName(typeof(MainPanel).Assembly.Location);
                if (!string.IsNullOrEmpty(dllDir))
                {
                    candidates.Add(Path.Combine(dllDir, "config", "rules.json"));
                    candidates.Add(Path.Combine(dllDir, "config", "rules.sample.json"));
                    // layout dev: <repo>\src\MTOPlugin\bin\Debug\net48 -> len 4 cap
                    string up = dllDir;
                    for (int i = 0; i < 4 && up != null; i++)
                    {
                        up = Path.GetDirectoryName(up);
                        if (up == null) break;
                        candidates.Add(Path.Combine(up, "config", "rules.sample.json"));
                    }
                }
            }
            catch { }

            candidates.Add(Path.Combine(local, "MTOPlugin", "config", "rules.json"));
            candidates.Add(Path.Combine(local, "MTOPlugin", "config", "rules.sample.json"));

            foreach (var c in candidates)
            {
                try { if (File.Exists(c)) return Path.GetFullPath(c); }
                catch { }
            }
            return null;
        }

        private void BtnBrowseRules_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Filter = "JSON|*.json|Tất cả các file|*.*",
                Title = "Chọn file bộ quy tắc"
            };
            if (dlg.ShowDialog() == true)
                txtRulesPath.Text = dlg.FileName;
        }

        private void BtnBrowseOutput_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new SaveFileDialog
            {
                Filter = "Excel|*.xlsx",
                Title = "Chọn nơi lưu file kết quả",
                FileName = "KetQuaBocTach_" + DateTime.Now.ToString("yyyyMMdd_HHmmss")
            };
            if (dlg.ShowDialog() == true)
                txtOutputPath.Text = dlg.FileName;
        }

        // ----------------------------------------------------------------- BƯỚC 1
        private void BtnScan_Click(object sender, RoutedEventArgs e)
        {
            AppendLog("Bắt đầu quét (Bước 1)...");

            if (HostScanHandler == null)
            {
                AppendLog("LỖI: Chưa kết nối HostScanHandler (cần chạy trong AutoCAD).");
                return;
            }

            try
            {
                var options = BuildOptions();
                ValidateRules(options);

                AppendLog("Phạm vi: " + options.Scope + " | Xref: " + options.XrefMode);
                _log.Log("Phạm vi: " + options.Scope + ", Xref: " + options.XrefMode
                         + ", File quy tắc: " + options.RulesFilePath);

                var scan = HostScanHandler(options);
                txtScanned.Text = scan.TotalEntitiesScanned.ToString();

                var engine = new MTOPlugin.Core.Classification.ClassificationEngine(
                    RuleSetLoader.Load(options.RulesFilePath), scan.Unit ?? options.Unit);
                var result = engine.Classify(scan);

                txtClassified.Text = result.ClassifiedCount.ToString();
                txtUnclassified.Text = result.UnclassifiedCount.ToString();
                txtWarnings.Text = scan.Warnings.Count.ToString();

                if (!scan.Success)
                {
                    AppendLog("Lỗi quét: " + scan.ErrorMessage);
                    _log.Log("Lỗi quét: " + scan.ErrorMessage);
                    return;
                }

                // Luu vao bo nho phien de Bước 2 chon loc + lenh MTOBANG tai dung
                ScanSession.Store(options, scan, result);
                _lastScan = scan;
                _lastResult = result;

                PopulateResultGrid(result);

                AppendLog(string.Format("Scanned={0} | Classified={1} | Unclassified={2} | Warnings={3}",
                    scan.TotalEntitiesScanned, result.ClassifiedCount,
                    result.UnclassifiedCount, scan.Warnings.Count));
                AppendLog("Đã nạp danh sách (mặc định chọn tất cả). Chọn bớt rồi bấm Bước 2.");
                _log.Log(string.Format("Scanned={0}, Classified={1}, Unclassified={2}, Warnings={3}",
                    scan.TotalEntitiesScanned, result.ClassifiedCount,
                    result.UnclassifiedCount, scan.Warnings.Count));
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message, "MTO Plugin", MessageBoxButton.OK, MessageBoxImage.Error);
                AppendLog("LỖI: " + ex.Message);
                _log.Error("Lỗi tổng thể", ex);
            }
        }

        private void PopulateResultGrid(ClassificationResult result)
        {
            _rows.Clear();

            int index = 1;
            foreach (var d in result.Details)
            {
                _rows.Add(new RowItem
                {
                    Index = index++,
                    Category = "Đã phân loại",
                    SystemCode = d.SystemCode,
                    MaterialCode = d.MaterialCode,
                    MaterialName = d.MaterialName,
                    Specification = d.Specification,
                    Unit = d.Unit,
                    QuantityText = Math.Round(d.Quantity, 3).ToString(),
                    Layer = d.Layer,
                    Layout = d.SpaceKind + "/" + d.Layout,
                    Handle = d.Handle,
                    SourceFile = d.SourceFile,
                    IsSelected = true
                });
            }

            foreach (var u in result.Unclassified)
            {
                _rows.Add(new RowItem
                {
                    Index = index++,
                    Category = "Chưa phân loại",
                    SystemCode = "",
                    MaterialCode = "",
                    MaterialName = "-",
                    Specification = "-",
                    Unit = "-",
                    QuantityText = Math.Round(u.RawLength, 3).ToString(),
                    Layer = u.Layer,
                    Layout = u.SpaceKind + "/" + u.Layout,
                    Handle = u.Handle,
                    SourceFile = u.SourceFile,
                    IsSelected = true
                });
            }

            dgResult.ItemsSource = null;
            dgResult.ItemsSource = _rows;
        }

        // ----------------------------------------------------------------- CHỌN LỌC
        private void BtnSelectAll_Click(object sender, RoutedEventArgs e)
        {
            foreach (var row in _rows)
                row.IsSelected = true;
        }

        private void BtnSelectNone_Click(object sender, RoutedEventArgs e)
        {
            foreach (var row in _rows)
                row.IsSelected = false;
        }

        // ----------------------------------------------------------------- BƯỚC 2
        private void BtnExportSelected_Click(object sender, RoutedEventArgs e)
        {
            ExportSelected();
        }

        private void BtnExportAll_Click(object sender, RoutedEventArgs e)
        {
            ExportAll();
        }

        private void ExportSelected()
        {
            if (_lastScan == null || _lastResult == null)
            {
                AppendLog("Chưa có kết quả quét. Chạy Bước 1 trước.");
                return;
            }

            var keys = new List<string>();
            foreach (var row in _rows)
                if (row.IsSelected)
                    keys.Add(row.Key);

            if (keys.Count == 0)
            {
                AppendLog("Chưa chọn mục nào. Tick vào cột 'Chọn' hoặc bấm 'Chọn tất cả'.");
                return;
            }

            var path = ResolveOutputPath();
            if (path == null) return;

            try
            {
                var exporter = new ExcelExporter();
                exporter.ExportTo(_lastScan, _lastResult, path, keys);
                AppendLog(string.Format("Đã xuất {0}/{1} mục: {2}", keys.Count, _rows.Count, path));
                _log.Log(string.Format("Xuất chọn lọc {0}/{1} mục: {2}", keys.Count, _rows.Count, path));
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi xuất Excel: " + ex.Message, "MTO Plugin", MessageBoxButton.OK, MessageBoxImage.Error);
                AppendLog("LỖI xuất Excel: " + ex.Message);
                _log.Error("Lỗi xuất Excel chọn lọc", ex);
            }
        }

        private void ExportAll()
        {
            if (_lastScan == null || _lastResult == null)
            {
                AppendLog("Chưa có kết quả quét. Chạy Bước 1 trước.");
                return;
            }

            var path = ResolveOutputPath();
            if (path == null) return;

            try
            {
                var exporter = new ExcelExporter();
                exporter.Export(_lastScan, _lastResult, path);
                AppendLog("Đã xuất toàn bộ: " + path);
                _log.Log("Xuất toàn bộ: " + path);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi xuất Excel: " + ex.Message, "MTO Plugin", MessageBoxButton.OK, MessageBoxImage.Error);
                AppendLog("LỖI xuất Excel: " + ex.Message);
                _log.Error("Lỗi xuất Excel toàn bộ", ex);
            }
        }

        private string ResolveOutputPath()
        {
            if (!string.IsNullOrWhiteSpace(txtOutputPath.Text))
                return txtOutputPath.Text;

            var dlg = new SaveFileDialog
            {
                Filter = "Excel|*.xlsx",
                Title = "Chọn nơi lưu file kết quả",
                FileName = "KetQuaBocTach_" + DateTime.Now.ToString("yyyyMMdd_HHmmss")
            };
            return dlg.ShowDialog() == true ? dlg.FileName : null;
        }

        // ----------------------------------------------------------------- TRUY VẾT
        private void DgResult_MouseDoubleClick(object sender, MouseButtonEventArgs e)
        {
            var row = dgResult.SelectedItem as RowItem;
            if (row == null)
            {
                AppendLog("Nhấp vào một dòng trong danh sách trước.");
                return;
            }
            if (HostZoomHandler == null)
            {
                AppendLog("Chưa kết nối để phóng tới đối tượng.");
                return;
            }

            try
            {
                if (HostZoomHandler(row.Handle, row.SourceFile))
                    AppendLog("Đã phóng tới Handle " + row.Handle + ".");
                else
                    AppendLog("Không phóng tới được đối tượng (Handle " + row.Handle + ").");
            }
            catch (Exception ex)
            {
                AppendLog("Lỗi truy vết: " + ex.Message);
            }
        }

        // ----------------------------------------------------------------- RULE EDITOR
        private void BtnRuleEditor_Click(object sender, RoutedEventArgs e)
        {
            RuleSet existing = null;
            if (!string.IsNullOrWhiteSpace(txtRulesPath.Text) && System.IO.File.Exists(txtRulesPath.Text))
            {
                try { existing = RuleSetLoader.Load(txtRulesPath.Text); }
                catch { existing = null; }
            }

            // Mo cua so Rule Editor.
            // LUU Y: panel nam trong PaletteSet cua AutoCAD -> Window.GetWindow(this)
            // co the tra ve null hoac cua so khong hop le. Gan Owner sai co the gay
            // "Unhandled Access Violation" (native crash, KHONG bat duoc bang try/catch).
            // => chi gan Owner khi that su hop le.
            try
            {
                var dlg = new RuleEditorWindow(existing, txtRulesPath.Text);

                try
                {
                    var owner = Window.GetWindow(this);
                    if (owner != null && owner != dlg && owner.IsLoaded)
                        dlg.Owner = owner;
                    // neu owner null/khong hop le: de WindowStartupLocation=CenterScreen lo
                }
                catch (Exception exOwner)
                {
                    AppendLog("Không gán được cửa sổ cha: " + exOwner.Message);
                }

                dlg.ShowDialog();

                if (dlg.DialogResult == true && !string.IsNullOrWhiteSpace(dlg.FilePath))
                {
                    txtRulesPath.Text = dlg.FilePath;
                    AppendLog("Đã cập nhật bộ quy tắc từ Rule Editor.");
                }
            }
            catch (Exception ex)
            {
                AppendLog("LỖI mở Rule Editor: " + ex.Message);
                MessageBox.Show(
                    "Không mở được Rule Editor:\r\n" + ex.Message,
                    "MTOPro", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        // ----------------------------------------------------------------- HỖ TRỢ
        private void ValidateRules(ScanOptions options)
        {
            if (string.IsNullOrWhiteSpace(options.RulesFilePath))
            {
                string suggested = FindDefaultRulesPath()
                    ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                                    "MTOPro", "config", "rules.json");
                throw new InvalidOperationException(
                    "Chưa chọn file bộ quy tắc.\r\n"
                  + "Cách xử lý: bấm nút '...' cạnh ô 'Bộ quy tắc (JSON)' rồi chọn file:\r\n  "
                  + suggested + "\r\n"
                  + "(Nếu file chưa có, chạy lại bộ cài MTOPro để tạo bộ quy tắc mẫu.)");
            }

            if (!File.Exists(options.RulesFilePath))
                throw new InvalidOperationException(
                    "Không tìm thấy file bộ quy tắc:\r\n  " + options.RulesFilePath
                  + "\r\nHãy kiểm tra lại đường dẫn hoặc chọn file khác.");

            var ruleSet = RuleSetLoader.Load(options.RulesFilePath);
            if (ruleSet.ActiveRules.Count == 0)
                throw new InvalidOperationException(
                    "Không có quy tắc active nào trong bộ quy tắc. Kiểm tra file: " + options.RulesFilePath);
        }

        private ScanOptions BuildOptions()
        {
            var scope = ScanScope.ModelAndAllLayouts;
            if (rbSelection.IsChecked == true) scope = ScanScope.Selection;
            else if (rbModel.IsChecked == true) scope = ScanScope.ModelSpace;
            else if (rbCurrentLayout.IsChecked == true) scope = ScanScope.CurrentLayout;
            else if (rbAllLayouts.IsChecked == true) scope = ScanScope.AllLayouts;

            var xrefMode = XrefMode.UniqueBySource;
            if (cmbXrefMode.SelectedIndex == 0) xrefMode = XrefMode.Ignore;
            else if (cmbXrefMode.SelectedIndex == 2) xrefMode = XrefMode.PerInsertion;

            return new ScanOptions
            {
                Scope = scope,
                XrefMode = xrefMode,
                RulesFilePath = txtRulesPath.Text,
                OutputFilePath = txtOutputPath.Text,
                Unit = BuildUnitInfo(),
                ScanNestedBlocks = true
            };
        }

        private UnitInfo BuildUnitInfo()
        {
            string src = ((ComboBoxItem)cmbSourceUnit.SelectedItem)?.Content?.ToString() ?? "ft";
            string outp = ((ComboBoxItem)cmbOutputUnit.SelectedItem)?.Content?.ToString() ?? "mm";

            var dwgUnit = DwgUnit.Unknown;
            switch (src.ToLowerInvariant())
            {
                case "mm": dwgUnit = DwgUnit.Millimeters; break;
                case "cm": dwgUnit = DwgUnit.Centimeters; break;
                case "m": dwgUnit = DwgUnit.Meters; break;
                case "ft": dwgUnit = DwgUnit.Feet; break;
                case "in": dwgUnit = DwgUnit.Inches; break;
            }

            return new UnitInfo
            {
                SourceUnit = dwgUnit,
                SourceUnitText = src,
                OutputUnit = outp,
                ConversionToMillimeter = 1.0
            };
        }

        private void AppendLog(string text)
        {
            txtLog.Text = text + Environment.NewLine + txtLog.Text;
            if (txtLog.Text.Length > 6000) txtLog.Text = txtLog.Text.Substring(0, 6000);
        }
    }

    /// <summary>
    /// Mot dong trong DataGrid ket qua: cho phep chon loc truoc khi xuat.
    /// </summary>
    public sealed class RowItem : System.ComponentModel.INotifyPropertyChanged
    {
        private bool _isSelected = true;

        public bool IsSelected
        {
            get { return _isSelected; }
            set
            {
                if (_isSelected != value)
                {
                    _isSelected = value;
                    RaisePropertyChanged("IsSelected");
                }
            }
        }

        public int Index { get; set; }

        public string Category { get; set; }

        public string SystemCode { get; set; }

        public string MaterialCode { get; set; }

        public string MaterialName { get; set; }

        public string Specification { get; set; }

        public string Unit { get; set; }

        public string QuantityText { get; set; }

        public string Layer { get; set; }

        public string Layout { get; set; }

        public string Handle { get; set; }

        public string SourceFile { get; set; }

        public string Key
        {
            get { return (SourceFile ?? "") + "@" + (Handle ?? ""); }
        }

        public event System.ComponentModel.PropertyChangedEventHandler PropertyChanged;

        private void RaisePropertyChanged(string name)
        {
            var handler = PropertyChanged;
            if (handler != null)
                handler(this, new System.ComponentModel.PropertyChangedEventArgs(name));
        }
    }
}