using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using Microsoft.Win32;
using MTOPlugin.Core.Rules;

namespace MTOPlugin.UI
{
    /// <summary>
    /// Cua so chinh sua bo quy tac (Rule Editor). Ung voi SPEC Section 7.2.
    /// Cho phep: xem, them, sua, xoa, loc, nhap/xuat JSON, kiem tra rule.
    /// </summary>
    public partial class RuleEditorWindow : Window
    {
        private RuleSet _ruleSet;
        private string _filePath;
        private List<RuleDefinition> _filteredRules;
        private RuleDefinition _editingRule;
        private bool _isDirty;

        /// <summary>
        /// true khi XAML da load XONG (moi control da ton tai).
        ///
        /// BUG DA GAP (gay "FATAL ERROR: Unhandled Access Violation Reading 0x0000"):
        /// ComboBox cmbFilterSystem co SelectionChanged="CmbFilter_Changed".
        /// Khi WPF dang load XAML (InitializeComponent), ComboBox tu set
        /// SelectedIndex -> event FIRE NGAY -> goi RefreshGrid(), nhung luc do
        /// dgRules / txtStatus CHUA duoc tao => NullReferenceException.
        /// => Guard bang co _uiReady.
        /// </summary>
        private bool _uiReady;

        /// <summary>RuleSet hien tai (co the null chua load).</summary>
        public RuleSet CurrentRuleSet => _ruleSet;

        /// <summary>File path da luu (null neu chua luu).</summary>
        public string FilePath => _filePath;

        public RuleEditorWindow()
        {
            InitializeComponent();
            _ruleSet = new RuleSet();
            _filteredRules = new List<RuleDefinition>();
            _uiReady = true;              // XAML da load xong -> cho phep event chay
            PopulateSystemCombo();
            RefreshGrid();
        }

        public RuleEditorWindow(RuleSet existing, string filePath = null) : this()
        {
            if (existing != null)
            {
                _ruleSet = existing;
                _filePath = filePath;
            }
            PopulateSystemCombo();
            RefreshGrid();
        }

        // ---------------------------------------------------------- LOAD / SAVE

        private void BtnSave_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(_filePath))
            {
                var dlg = new SaveFileDialog
                {
                    Filter = "JSON|*.json",
                    Title = "Lưu bộ quy tắc",
                    FileName = "rules.json"
                };
                if (dlg.ShowDialog() != true) return;
                _filePath = dlg.FileName;
            }

            try
            {
                RuleSetLoader.Save(_ruleSet, _filePath);
                _isDirty = false;
                txtStatus.Text = "Đã lưu: " + _filePath;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi lưu file: " + ex.Message, "Rule Editor",
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnCancel_Click(object sender, RoutedEventArgs e)
        {
            if (_isDirty)
            {
                var result = MessageBox.Show("Có thay đổi chưa lưu. Thoát?", "Rule Editor",
                    MessageBoxButton.YesNo, MessageBoxImage.Question);
                if (result != MessageBoxResult.Yes) return;
            }
            DialogResult = _isDirty;
            Close();
        }

        // ---------------------------------------------------------- ADD / DELETE

        private void BtnAdd_Click(object sender, RoutedEventArgs e)
        {
            var newRule = new RuleDefinition
            {
                Code = "R-NEW-" + (_ruleSet.Rules.Count + 1).ToString("D3"),
                Version = "1.0",
                SystemCode = _ruleSet.Systems?.FirstOrDefault()?.Code ?? "HE-DIEN",
                MaterialCode = "",
                MaterialName = "",
                Unit = "cái",
                Calculation = CalculationKind.Count,
                Status = RuleStatus.Draft,
                Priority = 100,
                Conditions = new List<RuleCondition> { new RuleCondition() }
            };
            _ruleSet.Rules.Add(newRule);
            _isDirty = true;
            RefreshGrid();
            SelectRule(newRule);
            txtStatus.Text = "Đã thêm rule mới: " + newRule.Code;
        }

        // ---------------------------------------------------------- IMPORT / EXPORT

        private void BtnImport_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new OpenFileDialog
            {
                Filter = "JSON|*.json|Tất cả|*.*",
                Title = "Nhập bộ quy tắc từ JSON"
            };
            if (dlg.ShowDialog() != true) return;

            try
            {
                var loaded = RuleSetLoader.Load(dlg.FileName);
                if (loaded != null && loaded.Rules.Count > 0)
                {
                    _ruleSet = loaded;
                    _filePath = dlg.FileName;
                    _isDirty = false;
                    PopulateSystemCombo();
                    RefreshGrid();
                    txtStatus.Text = string.Format("Đã nhập {0} rules từ {1}", loaded.Rules.Count, dlg.FileName);
                }
                else
                {
                    txtStatus.Text = "File JSON rỗng hoặc không hợp lệ.";
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi đọc JSON: " + ex.Message, "Rule Editor",
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnExport_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new SaveFileDialog
            {
                Filter = "JSON|*.json",
                Title = "Xuất bộ quy tắc ra JSON",
                FileName = "rules_export.json"
            };
            if (dlg.ShowDialog() != true) return;

            try
            {
                RuleSetLoader.Save(_ruleSet, dlg.FileName);
                txtStatus.Text = "Đã xuất: " + dlg.FileName;
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi xuất JSON: " + ex.Message, "Rule Editor",
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        // ---------------------------------------------------------- VALIDATE

        private void BtnValidate_Click(object sender, RoutedEventArgs e)
        {
            var issues = new List<string>();
            int idx = 0;
            foreach (var rule in _ruleSet.Rules)
            {
                idx++;
                if (string.IsNullOrWhiteSpace(rule.Code))
                    issues.Add(string.Format("Rule #{0}: Thiếu mã (Code)", idx));
                if (string.IsNullOrWhiteSpace(rule.SystemCode))
                    issues.Add(string.Format("Rule {0}: Thiếu mã hệ thống (SystemCode)", rule.Code));
                if (string.IsNullOrWhiteSpace(rule.MaterialCode))
                    issues.Add(string.Format("Rule {0}: Thiếu mã vật tư (MaterialCode)", rule.Code));
                if (string.IsNullOrWhiteSpace(rule.MaterialName))
                    issues.Add(string.Format("Rule {0}: Thiếu tên vật tư (MaterialName)", rule.Code));
                if (string.IsNullOrWhiteSpace(rule.Unit))
                    issues.Add(string.Format("Rule {0}: Thiếu đơn vị (Unit)", rule.Code));
                if (rule.Conditions == null || rule.Conditions.Count == 0)
                    issues.Add(string.Format("Rule {0}: Không có điều kiện (Conditions)", rule.Code));
                if (rule.Calculation == CalculationKind.SumLengthTimesFactor && rule.Factor <= 0)
                    issues.Add(string.Format("Rule {0}: Factor phải > 0 cho SumLengthTimesFactor", rule.Code));
                if (rule.Calculation == CalculationKind.SumLengthCeilingStep && rule.CeilingStep <= 0)
                    issues.Add(string.Format("Rule {0}: CeilingStep phải > 0", rule.Code));
            }

            // Check duplicate codes
            var dupes = _ruleSet.Rules
                .Where(r => !string.IsNullOrWhiteSpace(r.Code))
                .GroupBy(r => r.Code)
                .Where(g => g.Count() > 1)
                .Select(g => g.Key);
            foreach (var d in dupes)
                issues.Add("Mã trùng lặp: " + d);

            if (issues.Count == 0)
            {
                txtValidation.Text = "✓ Không tìm thấy lỗi. Bộ quy tắc hợp lệ.";
                txtValidation.Foreground = System.Windows.Media.Brushes.DarkGreen;
                txtStatus.Text = "Kiểm tra: PASS";
            }
            else
            {
                txtValidation.Text = string.Format("Tìm thấy {0} vấn đề:\n{1}",
                    issues.Count, string.Join("\n", issues));
                txtValidation.Foreground = System.Windows.Media.Brushes.Red;
                txtStatus.Text = string.Format("Kiểm tra: {0} vấn đề", issues.Count);
            }
        }

        // ---------------------------------------------------------- GRID SELECTION

        private void DgRules_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (!_uiReady) return;
            var rule = dgRules?.SelectedItem as RuleDefinition;
            if (rule == null) return;
            _editingRule = rule;
            LoadRuleToForm(rule);
        }

        private void SelectRule(RuleDefinition rule)
        {
            dgRules.SelectedItem = rule;
            _editingRule = rule;
            LoadRuleToForm(rule);
        }

        // ---------------------------------------------------------- FILTER

        private void TxtSearch_Changed(object sender, TextChangedEventArgs e)
        {
            if (!_uiReady) return;   // XAML chua load xong -> bo qua
            RefreshGrid();
        }

        private void CmbFilter_Changed(object sender, SelectionChangedEventArgs e)
        {
            if (!_uiReady) return;   // XAML chua load xong -> bo qua
            RefreshGrid();
        }

        // ---------------------------------------------------------- HELPERS

        private void PopulateSystemCombo()
        {
            // Guard: cmbSystem co the chua ton tai neu XAML chua load xong
            if (cmbSystem == null) return;
            cmbSystem.Items.Clear();
            if (_ruleSet != null && _ruleSet.Systems != null)
            {
                foreach (var sys in _ruleSet.Systems)
                    cmbSystem.Items.Add(sys.Code + " - " + sys.Name);
            }
            if (cmbSystem.Items.Count > 0)
                cmbSystem.SelectedIndex = 0;
        }

        private void RefreshGrid()
        {
            if (_ruleSet == null) return;
            // Guard: dgRules/txtStatus co the CHUA ton tai khi XAML dang load
            // (event SelectionChanged cua ComboBox fire ngay trong InitializeComponent)
            if (dgRules == null) return;

            _filteredRules = _ruleSet.Rules.ToList();

            // Filter by search text
            var search = txtSearch?.Text?.Trim().ToLowerInvariant();
            if (!string.IsNullOrEmpty(search))
            {
                _filteredRules = _filteredRules.Where(r =>
                    (r.Code != null && r.Code.ToLowerInvariant().Contains(search)) ||
                    (r.MaterialName != null && r.MaterialName.ToLowerInvariant().Contains(search)) ||
                    (r.Description != null && r.Description.ToLowerInvariant().Contains(search))
                ).ToList();
            }

            // Filter by system
            var sysFilter = (cmbFilterSystem?.SelectedItem as string);
            if (!string.IsNullOrEmpty(sysFilter) && sysFilter != "Tất cả")
            {
                _filteredRules = _filteredRules.Where(r => r.SystemCode == sysFilter).ToList();
            }

            // Filter by status
            var statusIdx = cmbFilterStatus?.SelectedIndex ?? 0;
            if (statusIdx > 0)
            {
                var statusText = ((ComboBoxItem)cmbFilterStatus.SelectedItem)?.Content?.ToString();
                if (Enum.TryParse<RuleStatus>(statusText, out var status))
                    _filteredRules = _filteredRules.Where(r => r.Status == status).ToList();
            }

            dgRules.ItemsSource = null;
            dgRules.ItemsSource = _filteredRules;

            if (txtStatus != null)
                txtStatus.Text = string.Format("Hiển thị {0}/{1} rules", _filteredRules.Count, _ruleSet.Rules.Count);
        }

        private void LoadRuleToForm(RuleDefinition rule)
        {
            txtCode.Text = rule.Code ?? "";
            txtVersion.Text = rule.Version ?? "1.0";
            txtMaterialCode.Text = rule.MaterialCode ?? "";
            txtMaterialName.Text = rule.MaterialName ?? "";
            txtSpecification.Text = rule.Specification ?? "";
            txtFactor.Text = rule.Factor.ToString("0.###");
            txtCeilingStep.Text = rule.CeilingStep.ToString("0.###");

            // System combo
            for (int i = 0; i < cmbSystem.Items.Count; i++)
            {
                if ((cmbSystem.Items[i] as string)?.StartsWith(rule.SystemCode) == true)
                {
                    cmbSystem.SelectedIndex = i;
                    break;
                }
            }

            // Status
            cmbStatus.SelectedIndex = (int)rule.Status;

            // Unit
            SelectComboBoxItem(cmbUnit, rule.Unit ?? "cái");

            // Calculation
            cmbCalculation.SelectedIndex = (int)rule.Calculation;

            // Conditions (first condition)
            var cond = rule.Conditions?.FirstOrDefault();
            if (cond != null)
            {
                cmbEntityKind.SelectedIndex = cond.EntityKind == "block" ? 0 :
                    cond.EntityKind == "geometry" ? 1 : 2;
                txtLayers.Text = cond.Layers ?? "*";
                txtBlockNames.Text = cond.BlockNames ?? "*";
                txtAttributes.Text = cond.Attributes ?? "";
            }
            else
            {
                cmbEntityKind.SelectedIndex = 0;
                txtLayers.Text = "*";
                txtBlockNames.Text = "*";
                txtAttributes.Text = "";
            }
        }

        private void SaveFormToRule(RuleDefinition rule)
        {
            rule.Code = txtCode.Text.Trim();
            rule.Version = txtVersion.Text.Trim();
            rule.MaterialCode = txtMaterialCode.Text.Trim();
            rule.MaterialName = txtMaterialName.Text.Trim();
            rule.Specification = txtSpecification.Text.Trim();
            double.TryParse(txtFactor.Text, out double factor);
            rule.Factor = factor;
            double.TryParse(txtCeilingStep.Text, out double step);
            rule.CeilingStep = step;

            // System
            var sysText = cmbSystem.SelectedItem as string;
            if (sysText != null)
                rule.SystemCode = sysText.Split('-')[0].Trim();

            // Status
            rule.Status = (RuleStatus)cmbStatus.SelectedIndex;

            // Unit
            rule.Unit = ((ComboBoxItem)cmbUnit.SelectedItem)?.Content?.ToString() ?? "cái";

            // Calculation
            rule.Calculation = (CalculationKind)cmbCalculation.SelectedIndex;

            // Conditions
            if (rule.Conditions == null || rule.Conditions.Count == 0)
                rule.Conditions = new List<RuleCondition> { new RuleCondition() };

            var cond = rule.Conditions[0];
            cond.EntityKind = ((ComboBoxItem)cmbEntityKind.SelectedItem)?.Content?.ToString() ?? "block";
            cond.Layers = string.IsNullOrWhiteSpace(txtLayers.Text) ? "*" : txtLayers.Text.Trim();
            cond.BlockNames = string.IsNullOrWhiteSpace(txtBlockNames.Text) ? "*" : txtBlockNames.Text.Trim();
            cond.Attributes = string.IsNullOrWhiteSpace(txtAttributes.Text) ? null : txtAttributes.Text.Trim();
        }

        private static void SelectComboBoxItem(ComboBox combo, string content)
        {
            for (int i = 0; i < combo.Items.Count; i++)
            {
                if ((combo.Items[i] as ComboBoxItem)?.Content?.ToString() == content)
                {
                    combo.SelectedIndex = i;
                    return;
                }
            }
        }
    }
}
