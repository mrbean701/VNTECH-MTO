using System;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Windows;
using MTOPlugin.UI;

namespace MTOPlugin.UI
{
    /// <summary>
    /// Wrapper hien thi MainPanel (WPF) trong mot PaletteSet cua AutoCAD.
    /// PaletteSet tuong ung yeu cau FR07 (xem truoc) va dieu huong quy trinh.
    /// </summary>
    public sealed class PaletteWrapper : IDisposable
    {
        private readonly Document _doc;
        private readonly PaletteSet _ps;
        private readonly MainPanel _panel;
        private readonly Scanner.ScannerHostBridge _bridge;

        public PaletteWrapper(Document doc, Scanner.ScannerHostBridge bridge)
        {
            _doc = doc ?? throw new ArgumentNullException(nameof(doc));
            _bridge = bridge ?? throw new ArgumentNullException(nameof(bridge));

            _panel = new MainPanel();
            _panel.HostScanHandler = bridge.Scan;
            _panel.HostZoomHandler = bridge.ZoomToHandle;

            // Dung chung cho ca net48 (AutoCAD 2023) va net8 (2025+):
            // PaletteSet nhan Guid (constructor voi string khong ton tai o 2023).
            _ps = new PaletteSet("MTO - Boc tac khoi luong", Guid.Parse("3B6A18DE-4C92-4E1B-9A46-1C2A5E8D9F01"))
            {
                Style = PaletteSetStyles.ShowPropertiesMenu |
                        PaletteSetStyles.ShowAutoHideButton |
                        PaletteSetStyles.ShowCloseButton,
                DockEnabled = (DockSides)(-1),
                MinimumSize = new System.Drawing.Size(320, 400)
            };

            _ps.AddVisual("Boc tac", _panel);
        }

        public void Show()
        {
            if (_ps.Visible)
            {
                _ps.Visible = true;
                return;
            }
            _ps.Visible = true;
        }

        public void Dispose()
        {
            _ps.Dispose();
        }
    }
}