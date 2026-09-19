using MTOPlugin.Core.Models;
using MTOPlugin.Core.Unit;
using NUnit.Framework;

namespace MTOPlugin.Tests
{
    [TestFixture]
    public class UnitConverterTests
    {
        [Test]
        public void ToMillimeter_Millimeters_ReturnsSame()
        {
            Assert.AreEqual(100.0, UnitConverter.ToMillimeter(DwgUnit.Millimeters, 100.0));
        }

        [Test]
        public void ToMillimeter_Centimeters_MultipliesBy10()
        {
            Assert.AreEqual(100.0, UnitConverter.ToMillimeter(DwgUnit.Centimeters, 10.0));
        }

        [Test]
        public void ToMillimeter_Meters_MultipliesBy1000()
        {
            Assert.AreEqual(5000.0, UnitConverter.ToMillimeter(DwgUnit.Meters, 5.0));
        }

        [Test]
        public void ToMillimeter_Inches_MultipliesBy25_4()
        {
            Assert.AreEqual(25.4, UnitConverter.ToMillimeter(DwgUnit.Inches, 1.0));
        }

        [Test]
        public void ToMillimeter_Feet_MultipliesBy304_8()
        {
            Assert.AreEqual(304.8, UnitConverter.ToMillimeter(DwgUnit.Feet, 1.0));
        }

        [Test]
        public void ToMillimeter_Yards_MultipliesBy914_4()
        {
            Assert.AreEqual(914.4, UnitConverter.ToMillimeter(DwgUnit.Yards, 1.0));
        }

        [Test]
        public void ToMillimeter_Kilometers_MultipliesBy1M()
        {
            Assert.AreEqual(1000000.0, UnitConverter.ToMillimeter(DwgUnit.Kilometers, 1.0));
        }

        [Test]
        public void ToMillimeter_Mils_MultipliesBy0_0254()
        {
            Assert.AreEqual(0.0254, UnitConverter.ToMillimeter(DwgUnit.Mils, 1.0));
        }

        [Test]
        public void ToMillimeter_Microns_MultipliesBy0_001()
        {
            Assert.AreEqual(0.001, UnitConverter.ToMillimeter(DwgUnit.Microns, 1.0));
        }

        [Test]
        public void ToMillimeter_Unitless_TreatsAsMm()
        {
            Assert.AreEqual(50.0, UnitConverter.ToMillimeter(DwgUnit.Unitless, 50.0));
        }

        [Test]
        public void ToMillimeter_Unknown_TreatsAsMm()
        {
            Assert.AreEqual(50.0, UnitConverter.ToMillimeter(DwgUnit.Unknown, 50.0));
        }

        [Test]
        public void ToOutput_FeetToMm()
        {
            double result = UnitConverter.ToOutput(DwgUnit.Feet, 1.0, "mm");
            Assert.AreEqual(304.8, result, 0.001);
        }

        [Test]
        public void ToOutput_FeetToMeters()
        {
            double result = UnitConverter.ToOutput(DwgUnit.Feet, 1.0, "m");
            Assert.AreEqual(0.3048, result, 0.0001);
        }

        [Test]
        public void ToOutput_FeetToInches()
        {
            double result = UnitConverter.ToOutput(DwgUnit.Feet, 1.0, "in");
            Assert.AreEqual(12.0, result, 0.001);
        }

        [Test]
        public void ToOutput_MmToFeet()
        {
            double result = UnitConverter.ToOutput(DwgUnit.Millimeters, 304.8, "ft");
            Assert.AreEqual(1.0, result, 0.001);
        }

        [Test]
        public void ToOutput_MmToYards()
        {
            double result = UnitConverter.ToOutput(DwgUnit.Millimeters, 914.4, "yd");
            Assert.AreEqual(1.0, result, 0.001);
        }

        [Test]
        public void ToOutput_UnknownOutput_DefaultsToMm()
        {
            double result = UnitConverter.ToOutput(DwgUnit.Millimeters, 100.0, "xyz");
            Assert.AreEqual(100.0, result, 0.001);
        }

        [Test]
        public void Describe_Unitless_ReturnsMessage()
        {
            string desc = UnitConverter.Describe(DwgUnit.Unitless, "mm");
            Assert.That(desc, Does.Contain("Khong co don vi goc"));
        }

        [Test]
        public void Describe_FeetToMm_ReturnsDescription()
        {
            string desc = UnitConverter.Describe(DwgUnit.Feet, "mm");
            Assert.That(desc, Does.Contain("Feet"));
            Assert.That(desc, Does.Contain("mm"));
        }

        // --- UnitInfo tests ---

        [Test]
        public void UnitInfo_ToMm_UsesConversionFactor()
        {
            var unit = new UnitInfo
            {
                SourceUnit = DwgUnit.Feet,
                ConversionToMillimeter = 304.8,
                OutputUnit = "mm"
            };
            Assert.AreEqual(3048.0, unit.ToMm(10.0));
        }

        [Test]
        public void UnitInfo_ToOutput_ConvertsCorrectly()
        {
            var unit = new UnitInfo
            {
                SourceUnit = DwgUnit.Feet,
                ConversionToMillimeter = 304.8,
                OutputUnit = "m"
            };
            double result = unit.ToOutput(10.0, out double mmVal);
            Assert.AreEqual(3048.0, mmVal, 0.001);
            Assert.AreEqual(3.048, result, 0.001);
        }

        [Test]
        public void UnitInfo_ToOutput_Yards()
        {
            var unit = new UnitInfo
            {
                SourceUnit = DwgUnit.Yards,
                ConversionToMillimeter = 914.4,
                OutputUnit = "yd"
            };
            double result = unit.ToOutput(1.0, out _);
            Assert.AreEqual(1.0, result, 0.001);
        }
    }
}
