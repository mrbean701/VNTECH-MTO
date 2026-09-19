using System;
using System.Collections.Generic;
using MTOPlugin.Core.Models;

namespace MTOPlugin.Core.Unit
{
    /// <summary>
    /// Chuyen doi don vi. He so mac dinh theo AutoCAD DWGUNITS.
    /// Yeu cau: luu ro gia tri goc va gia tri quy doi trong ket qua xuat.
    /// </summary>
    public static class UnitConverter
    {
        private static readonly Dictionary<DwgUnit, double> ToMmFactor = new Dictionary<DwgUnit, double>
        {
            { DwgUnit.Inches, 25.4 },
            { DwgUnit.Feet, 304.8 },
            { DwgUnit.Yards, 914.4 },
            { DwgUnit.Miles, 1609344.0 },
            { DwgUnit.Millimeters, 1.0 },
            { DwgUnit.Centimeters, 10.0 },
            { DwgUnit.Decimeters, 100.0 },
            { DwgUnit.Meters, 1000.0 },
            { DwgUnit.Dekameters, 10000.0 },
            { DwgUnit.Hectometers, 100000.0 },
            { DwgUnit.Kilometers, 1000000.0 },
            { DwgUnit.Microinches, 0.0000254 },
            { DwgUnit.Mils, 0.0254 },
            { DwgUnit.Microns, 0.001 },
            { DwgUnit.Nanometers, 0.000001 },
            { DwgUnit.Angstroms, 0.0000001 },
            { DwgUnit.Unitless, 1.0 },
            { DwgUnit.Unknown, 1.0 }
        };

        public static double ToMillimeter(DwgUnit source, double value)
        {
            double factor = ToMmFactor.TryGetValue(source, out var f) ? f : 1.0;
            return value * factor;
        }

        public static double ToOutput(DwgUnit source, double value, string outputUnit)
        {
            double mm = ToMillimeter(source, value);
            switch (outputUnit?.ToLowerInvariant())
            {
                case "mm": return mm;
                case "cm": return mm / 10.0;
                case "m": return mm / 1000.0;
                case "km": return mm / 1000000.0;
                case "in": return mm / 25.4;
                case "ft": return mm / 304.8;
                case "yd": return mm / 914.4;
                case "mil": return mm / 0.0254;
                case "um": return mm / 0.001;
                default: return mm;
            }
        }

        /// <summary>
        /// Chuyen doi danh sach goc -> he so ket qua.
        /// </summary>
        public static string Describe(DwgUnit source, string output)
        {
            if (source == DwgUnit.Unitless)
                return "Khong co don vi goc";
            return string.Format("{0} -> {1}", source, output);
        }
    }
}