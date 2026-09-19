namespace MTOPlugin.Core.Models
{
    /// <summary>
    /// Don vi do trong ban ve DWG.
    /// </summary>
    public enum DwgUnit
    {
        Unitless = 0,
        Inches = 1,
        Feet = 2,
        Miles = 3,
        Millimeters = 4,
        Centimeters = 5,
        Meters = 6,
        Kilometers = 7,
        Microinches = 8,
        Mils = 9,
        Yards = 10,
        Angstroms = 11,
        Nanometers = 12,
        Microns = 13,
        Decimeters = 14,
        Dekameters = 15,
        Hectometers = 16,
        Gigameters = 17,
        AstronomicalUnits = 18,
        LightYears = 19,
        Parsecs = 20,
        Unknown = -1
    }

    /// <summary>
    /// Thong tin don vi ban ve va he so quy doi goc/quy doi.
    /// Yeu cau: doc don vi ban ve, khai bao he so quy doi, luu ro gia tri goc va gia tri quy doi.
    /// </summary>
    public sealed class UnitInfo
    {
        public DwgUnit SourceUnit { get; set; } = DwgUnit.Unknown;

        public string SourceUnitText { get; set; } = "Unknown";

        /// <summary>He so quy doi: 1 don vi ban ve = X milimeter quy doi.</summary>
        public double ConversionToMillimeter { get; set; } = 1.0;

        /// <summary>Don vi xuat ra (mm, m, cm, ft, in...).</summary>
        public string OutputUnit { get; set; } = "mm";

        public double ToMm(double rawValue)
        {
            return rawValue * ConversionToMillimeter;
        }

        public double ToOutput(double rawValue, out double mmValue)
        {
            mmValue = ToMm(rawValue);
            return mmValue / OutputToMmFactor();
        }

        private double OutputToMmFactor()
        {
            switch (OutputUnit?.ToLowerInvariant())
            {
                case "mm": return 1.0;
                case "cm": return 10.0;
                case "m": return 1000.0;
                case "km": return 1000000.0;
                case "in": return 25.4;
                case "ft": return 304.8;
                case "yd": return 914.4;
                case "mil": return 0.0254;
                case "um": return 0.001;
                default: return 1.0;
            }
        }
    }
}